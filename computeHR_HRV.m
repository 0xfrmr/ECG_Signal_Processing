function [HR_mean, RR_intervals, SDNN, RMSSD] = computeHR_HRV(r_locs, fs)
% r_locs: indices of R peaks
% returns mean HR (bpm), RR intervals (s), SDNN (s), RMSSD (s)

if isempty(r_locs) || numel(r_locs) < 2
    HR_mean = NaN; RR_intervals = []; SDNN = NaN; RMSSD = NaN; return;
end

RR_samples = diff(r_locs);
RR_intervals = RR_samples / fs;
HR_inst = 60 ./ RR_intervals;
HR_mean = mean(HR_inst);
SDNN = std(RR_intervals);
diffRR = diff(RR_intervals);
RMSSD = sqrt(mean(diffRR.^2));
end
