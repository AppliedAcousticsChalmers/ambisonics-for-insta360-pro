# Signal Processing

(Make sure to invoke `git submodule update --init --recursive` to get all submodules of this repository.)

The signal processing assumes that the camera housing is a sphere. The camera housing does indeed have a perfectly circular equator, but it has these cutouts at the top and at the bottom, and it is a little squashed. We demonstrated in the following paper that the acoustic effect of these deviations is negligible:

    J. Ahrens and K. Jaruszewska, "Case Study of Equipping a High-Fidelity 360 Camera with a 4th-Order Equatorial Ambisonic Microphone Array," 154th Convention of the AES, Espoo, Finland (2023). [[pdf]](https://research.chalmers.se/publication/535721/file/535721_Fulltext.pdf)

The signal processing that we apply to the raw microphone signals is therefore in principle identical to what is described in

    J. Ahrens, "Ambisonic Encoding of Signals From Equatorial Microphone Arrays," Technical note v. 1, Chalmers University of Technology, Aug. 2022 [[pdf]](https://arxiv.org/pdf/2211.00584.pdf).


and implemented it in https://github.com/AppliedAcousticsChalmers/ambisonic-encoding. The difference in the present case is that we additionally perform an equalization of the processing pipeline with respect to the spectral balance of the binaural output signals. Actually, we provide you with two alternative equalizations here.

## Diffuse-Field Equalisation of the Array Plus MagLS Rendering

The motivation behind this is the following: MagLS rendering as presented in 

    C. Schörkhuber, M. Zaunschirm, R. Höldrich, “Binaural rendering of Ambisonic signals via magnitude least squares,” in Proc. DAGA, vol. 44, 2018, pp. 339–342
    
consists essentially in replacing the raw order-limited HRTFs that are used for the binaural rendering with a variant of these HRTFs that have a compensation of the effects of the order-limitation built-in so that the attenuation at high frequencies (say, above 3 kHz in the present case) that is inherent to order-limited HRTFs is compensated for as best as possible. This means that we can assume that the rendering part of the pipeline does not affect the spectral balance of the binaural output signals.

How about the array itself? A perfect equatorial microphone array (EMA) will produce spherical harmonic (SH) coefficients that exhibit a perfectly flat magnitude spectrum if the incidence sound field is a horizontally propagating plane wave in free-field conditions. The SH coefficients that a real-world EMA produces are corrupted by spatial aliasing, which usually causes excess energy above the spatial aliasing frequency (which is approx. 3 kHz for the present array). A real-world array will also produce too low energy at low frequencies for orders higher than 0 because of the gain limitation of the radial filters. But we can disregard that because it does not affect the spectral balance of the binaural output signals. 

We therefore need to take into account only the spatial aliasing. To do that, we simulated horizontal plane wave incidence for 60 different azimuths onto our EMA and computed the average deviation of the magnitude spectrum of the resulting SH coefficients from flat at frequencies above the aliasing frequency. Based on that, we created a minimum-phase filter that compensates for the average deviation and simply apply that filter to all signal channels (you can do it before or after the SH decomposition). Here is what the filter's transfer function looks like: 

![diffuse_eq](pics/diffuse_eq.png "diffuse_eq")

The filter is stored in the file `data/diffuse_eq_Insta360.mat`.

Done! This way, we equalised the array, and the rendering is equalized via MagLS. Check the script `render_recording.m` for the complete pipeline. You'll need to download the employed HRIRs from [here](https://zenodo.org/record/3928297/files/HRIR_L2702.sofa?download=1) and store them in the subfolder `eMagLS/resources` (The MATLAB script is going to do that automatically for you.) as well as the SOFA MATLAB API from [here](https://sourceforge.net/projects/sofacoustics/) for being able to compute the binaural output yourself. The ambisonic encoding works either way.

Note that this script also stores the free-field equalised ambisonic signals from the array in N3D format, which you can render yourself in [Reaper](https://www.reaper.fm/), for example, with the IEM Binaural Renderer (which performs MagLS rendering, too, by the way). The repository comprises the Reaper project `binaural_rendering.rpp` that reads the ambisonic signals and renders them binaurally in realtime. This allows for using head tracking if you happen to have a tracker available. The Reaper project requires the [IEM Plugin Suite](https://plugins.iem.at/) to be installed.

## Manual Global Equalization

MagLS provides most significant improvement at low orders around, say, 2. The present array is 4th order where the benefits tend to become less pronounced. We therefore tested also a simple equalization procedure (this is actually what we used in the video): 

We do the plain SH decomposition and binaural rendering as described in the paper (Ahrens, 2022) referenced above and compare the spectral balance of the binaural output to the ground truth. When rendering a plane wave, the ground truth is simply the HRTF for the incidence direction of that plane wave. It turned out that the deviation of the magnitude spectrum of the binaural output is only very mildly dependent on the incidence direction of the sound so that we chose to use a single minimum-phase filter to compensate for it globally. It is a simple shelving filter that boosts the signal by approx. 3 dB above 3 kHz:

![shelving_eq](pics/shelving_eq.png "shelving_eq")

See the script `render_recording.m` allows you to set flags such that this equalization is performed instead of diffuseEQ+MagLS.