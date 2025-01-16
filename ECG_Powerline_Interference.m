function ecg_filt = ECG_Powerline_Interference(ecg, fs, bpCut, notchFreq)
% Bandpass (Butterworth) + custom IIR notch (no Signal Processing Toolbox required)

ecg = double(ecg(:)) - mean(ecg);

% Bandpass using Butterworth (4th order)
[b1,a1] = butter(4, [bpCut(1) bpCut(2)]/(fs/2), 'bandpass');
ecg_bp = filtfilt(b1, a1, ecg);

% Custom notch (if iirnotch not available)
wo = notchFreq/(fs/2); % normalized
bw = wo/35;
R = 1 - bw/2;
b = [1, -2*cos(pi*wo), 1];
a = [1, -2*R*cos(pi*wo), R^2];
ecg_notch = filter(b, a, ecg_bp);

ecg_filt = ecg_notch;
end
