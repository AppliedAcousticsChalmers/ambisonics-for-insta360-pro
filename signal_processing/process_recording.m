% (c) 2023 by Jens Ahrens

clear;

addpath(genpath('eMagLS/')); % This includes https://github.com/AppliedAcousticsChalmers/ambisonic-encoding as a submodule

eq_type = 'manual'; % This one is used in the video
%eq_type = 'freefield+MagLS'; % use this if you want to render in Reaper
%eq_type = 'none'; 

% ----------------------------- Input data --------------------------------
head_orientation_rad = 0;

% load the variables array_signals, fs, N, R, alpha_ema
load('resources/insta360_demo.mat');

% azi_mic_rad: azimuth of microphone positions in rad

% ----------------------------- Preparations ------------------------------

sphharm_type = 'real';
hankel_type = 2; 

radial_filter_length = 2048;

f = linspace(0, fs/2, radial_filter_length/2 + 1).'; 
c = 343;
k = 2*pi*f/c;

if strcmp(eq_type, 'manual')  
    eq_filter_file = 'resources/shelving_eq_insta360.mat';
elseif strcmp(eq_type, 'freefield+MagLS')
    eq_filter_file = 'resources/diffuse_eq_insta360.mat';
elseif strcmp(eq_type, 'none') 
    % don't use any Eq
else
    error('Unknown Eq type.');
end

% -------------------- Precompute the radial filters ----------------------

gain_limit_radial_filters_dB = 40; % This is equivalent to 22 dB for the SMA.
reg_type_radial_filters = 'tikhonov'; % 'soft', 'hard', 'tikhonov'

[~, ema_inv_rf_t] = get_ema_radial_filters(k, R, N, gain_limit_radial_filters_dB, reg_type_radial_filters, hankel_type);

% ------------------------ Get the ambisonic signals ----------------------

ambi_signals = get_sound_field_sh_coeffs_from_ema_t(array_signals, ema_inv_rf_t, N, azi_mic_rad);

% ------------------------------ apply EQ ---------------------------------

if exist('eq_filter_file', 'var')
    
    fprintf('Applying Eq %s ... ', eq_filter_file);
    eq = load(eq_filter_file);
    
    % do this in a loop to be compatible with Octave syntax
    for l = 1 : size(ambi_signals, 2)
        ambi_signals(:, l) = fftfilt(eq.ir, ambi_signals(:, l)); 
    end
    
    fprintf('done.\n');
    
else
    
    fprintf('No Eq is applied.\n');
    
end




% --------------------------- Render binaurally ---------------------------

if strcmp(eq_type, 'manual') || strcmp(eq_type, 'none') 

    out_binaural = render_ambi_signals_binaurally_t(ambi_signals, head_orientation_rad, N, 'transform_integral');

elseif strcmp(eq_type, 'freefield+MagLS')

    taps = 512;

    % ------- load HRIR set (see https://zenodo.org/record/3928297) -------
    % download HRIRs (skipped automatically if the HRIR dataset already exists)
    hrir_path = 'resources/HRIR_L2702.sofa';

    if ~isfile(hrir_path)
        fprintf('Downloading HRTFs from https://zenodo.org/record/3928297 ... ');
        websave(hrir_path, 'https://zenodo.org/record/3928297/files/HRIR_L2702.sofa?download=1');
        fprintf('done.\n');
    end

    SOFAstart;

    hrirs_sofa = SOFAload(hrir_path);

    hrirs_left  = squeeze(hrirs_sofa.Data.IR(:, 1, :)).';
    hrirs_right = squeeze(hrirs_sofa.Data.IR(:, 2, :)).';
    
    hrir_grid_azi_rad = hrirs_sofa.SourcePosition(:, 1)/180 * pi;
    hrir_grid_col_rad = pi/2 - hrirs_sofa.SourcePosition(:, 2)/180 * pi;

    assert(hrirs_sofa.Data.SamplingRate == fs);

    [magls_filters_left, magls_filters_right] = getMagLsFilters(hrirs_left, hrirs_right, hrir_grid_azi_rad, hrir_grid_col_rad, N, fs, taps, false);

    fprintf('done.\n');
    
    out_binaural = binauralDecode(ambi_signals, fs, magls_filters_left, magls_filters_right, fs);

else
    error('Unknown Eq type.');
    
end

% normalize
out_binaural = out_binaural / max(abs(out_binaural(:))) * 0.99;

% store
audiowrite('insta360_demo_binaural.wav', out_binaural, fs);
    
% ---------------------- Store the ambisonic signals ----------------------
 
% % convert from N3D to SN3D if you want that
% for n = 0 : N
%     for m = -n : n
%         ambi_signals(:, n^2+n+m+1) = ambi_signals(:, n^2+n+m+1) ./ sqrt(2*n+1);
%     end
% end

% normalize
max_value    = max(abs(ambi_signals(:)));
weight       = 0.99 / max_value(1);
ambi_signals = ambi_signals .* weight;

audiowrite('insta360_demo_ambisonics.wav', ambi_signals, fs, 'BitsPerSample', 24);

