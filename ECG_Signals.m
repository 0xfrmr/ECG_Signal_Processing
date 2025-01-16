function varargout = ECG_Signals(mode, ecg, fs, r_locs_in)
% Small utility: detect R peaks and P-Q-R-S-T if requested.
switch lower(mode)
    case 'detectr'
        sig = ecg(:);
        % simple adaptive threshold
        win = round(0.150*fs); % smoothing window 150 ms
        env = movmean(abs(sig), win);
        threshold = mean(env) + 0.35*std(env);
        minDist = floor(0.3*fs); % min distance ~ 300 ms (200 bpm safe)
        if exist('findpeaks','file')
            [pks, locs] = findpeaks(sig, 'MinPeakHeight', threshold, 'MinPeakDistance', minDist);
        else
            % fallback naive peak search
            [pks, locs] = naive_peaks(sig, threshold, minDist);
        end
        varargout{1} = locs;
        varargout{2} = pks;
    otherwise
        error('Unsupported mode');
end

end

function [pks, locs] = naive_peaks(sig, thr, minDist)
locs = [];
pks = [];
N = length(sig);
i = 2;
while i <= N-1
    if sig(i) > thr && sig(i) > sig(i-1) && sig(i) > sig(i+1)
        locs(end+1) = i; %#ok<AGROW>
        pks(end+1) = sig(i); %#ok<AGROW>
        i = i + minDist; % skip forward
    else
        i = i + 1;
    end
end
end
