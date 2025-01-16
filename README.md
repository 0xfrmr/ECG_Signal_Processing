# ECG Signal Processing (MATLAB)

Files:
- ECG_Signal_Processing.m : main pipeline
- ECG_Powerline_Interference.m : preprocessing filters (HP, LP, notch)
- Ecg_signal.m : load or create synthetic ECG
- ECG_Signals.m : R-peak + PQRST detection
- dwt_denoise.m : optional wavelet denoising

How to run:
1. Open this folder in VS Code (or MATLAB).
2. Run `ECG_Signal_Processing.m`.
3. If you have ECG .mat files, put them in `data/` and set `use_file = true` in the main script.

Required toolboxes (recommended):
- Signal Processing Toolbox
- Wavelet Toolbox (optional, for DWT denoising)
