function ECG_App

% State variables (shared with callbacks)
ecg = [];
fs = 360;
ecg_filt = [];
r_locs = [];
r_peaks = [];
HR = NaN;
SDNN = NaN;
RMSSD = NaN;
resultsTable = [];

% Build UI
fig = uifigure('Name','ECG Analyzer','Position',[200 200 1100 700]);

% Left column: controls
panel = uipanel(fig, 'Title','Controls','Position',[10 10 280 680]);

btnLoad = uibutton(panel,'push','Text','Load ECG','Position',[20 620 240 35],...
    'ButtonPushedFcn', @onLoad);
lblFile = uilabel(panel,'Text','No file loaded','Position',[20 585 240 25]);

% Filter options
uilabel(panel,'Position',[20 540 200 20],'Text','Filter options:');
lblBP = uilabel(panel,'Text','Bandpass (Hz):','Position',[20 510 90 20]);
edtBP = uieditfield(panel,'text','Value','0.5,40','Position',[110 510 110 22]);

lblNotch = uilabel(panel,'Text','Notch (Hz):','Position',[20 480 90 20]);
edtNotch = uieditfield(panel,'numeric','Value',50,'Position',[110 480 110 22]);

chkWavelet = uicheckbox(panel,'Text','Use wavelet denoising (optional)','Position',[20 440 260 20]);

btnProcess = uibutton(panel,'push','Text','Process Signal','Position',[20 390 240 35],...
    'ButtonPushedFcn', @onProcess);

% Export and save
btnExport = uibutton(panel,'push','Text','Export Results (CSV)','Position',[20 340 240 35],...
    'ButtonPushedFcn', @onExport);

% Classification display
lblHR = uilabel(panel,'Text','HR: - bpm','Position',[20 300 240 25],'FontSize',14,'FontWeight','bold');
lblState = uilabel(panel,'Text','State: -','Position',[20 270 240 22],'FontSize',13);

% Right side: plots
ax1 = uiaxes(fig,'Position',[310 360 770 320]); title(ax1,'Raw and Filtered ECG'); xlabel(ax1,'Time (s)'); ylabel(ax1,'Amplitude');
ax2 = uiaxes(fig,'Position',[310 170 770 160]); title(ax2,'Detected R-peaks'); xlabel(ax2,'Time (s)'); ylabel(ax2,'Amplitude');
ax3 = uiaxes(fig,'Position',[310 20 770 130]); title(ax3,'RR Intervals & HRV'); xlabel(ax3,'Beat #'); ylabel(ax3,'Interval (s)');

% Help text
uilabel(panel,'Text','Notes: load .mat/.csv or use synthetic if empty.','Position',[20 230 240 30],'WordWrap','on');

%% Callback: Load ECG
    function onLoad(~,~)
        [file,path] = uigetfile({'*.mat;*.csv;*.txt','ECG files (*.mat, *.csv, *.txt)'; '*.*', 'All Files'}, 'Select ECG file');
        if isequal(file,0)
            % If user cancels, create a synthetic signal for demo
            ecg = create_synthetic_ecg(360,30); % 30 seconds
            fs = 360;
            lblFile.Text = 'Using synthetic ECG (no file)';
        else
            full = fullfile(path,file);
            lblFile.Text = file;
            % try load .mat or read csv
            [ecg, fs] = load_ecg_file(full);
        end
        % show a preview
        t = (0:length(ecg)-1)/fs;
        plot(ax1, t, ecg, 'Color',[0.6 0.6 0.6]); hold(ax1,'on'); title(ax1,'Raw and Filtered ECG'); xlabel(ax1,'Time (s)');
        legend(ax1, 'Raw'); hold(ax1,'off');
    end

%% Callback: Process
    function onProcess(~,~)
        if isempty(ecg)
            uialert(fig,'No ECG data loaded. Use Load or provide a file.','No Data');
            return;
        end
        % parse filter settings
        bpstr = strtrim(edtBP.Value);
        parts = split(bpstr,',');
        if numel(parts) ~= 2
            uialert(fig,'Bandpass must be like "0.5,40"','Input error'); return;
        end
        bpLow = str2double(parts{1}); bpHigh = str2double(parts{2});
        notchF = edtNotch.Value;
        useWave = chkWavelet.Value;
        % preprocess
        ecg_filt = ECG_Powerline_Interference(ecg, fs, [bpLow bpHigh], notchF);
        if useWave
            % try wavelet denoising if function exists; otherwise skip
            try
                ecg_filt = wden(ecg_filt,'sqtwolog','s','sln',4,'db4'); %#ok<*SEPEX>
            catch
                % wavelet toolbox not available; ignore
            end
        end
        % plot signals
        t = (0:length(ecg)-1)/fs;
        plot(ax1, t, ecg, 'Color',[0.6 0.6 0.6]); hold(ax1,'on');
        plot(ax1, t, ecg_filt, 'b'); xlabel(ax1,'Time (s)'); ylabel(ax1,'Amplitude');
        legend(ax1, 'Raw','Filtered'); hold(ax1,'off');
        % detect R peaks
        [r_locs, r_peaks] = ECG_Signals('detectR', ecg_filt, fs);
        % plot R peaks
        plot(ax2, t, ecg_filt, 'Color',[0.1 0.5 0.8]); hold(ax2,'on');
        if ~isempty(r_locs)
            plot(ax2, r_locs/fs, r_peaks, 'ro','MarkerFaceColor','r');
        end
        xlabel(ax2,'Time (s)'); ylabel(ax2,'Amplitude'); title(ax2,'Detected R-peaks');
        hold(ax2,'off');
        % compute HR & HRV
        [HR, RR_intervals, SDNN, RMSSD] = computeHR_HRV(r_locs, fs);
        % simple classification
        if isnan(HR)
            state = 'Insufficient data';
        elseif HR < 60
            state = 'Bradycardia';
        elseif HR <= 100
            state = 'Normal';
        else
            state = 'Tachycardia';
        end
        % display
        lblHR.Text = sprintf('HR: %.1f bpm', HR);
        lblState.Text = sprintf('State: %s | SDNN=%.3f s | RMSSD=%.3f s', state, SDNN, RMSSD);
        % RR plot
        if ~isempty(RR_intervals)
            stem(ax3, 1:length(RR_intervals), RR_intervals, 'filled');
            hold(ax3,'on');
            yline(ax3, mean(RR_intervals),'r--','Mean RR');
            hold(ax3,'off');
            xlabel(ax3,'Beat #'); ylabel(ax3,'Interval (s)');
            title(ax3,'RR Intervals & HRV');
        end
        % Save results table for export
        resultsTable = table((1:length(RR_intervals))', RR_intervals', 'VariableNames', {'BeatIndex','RR_seconds'});
    end

%% Callback: Export
    function onExport(~,~)
        if isempty(resultsTable)
            uialert(fig,'No results to export. Process a signal first.','No Data');
            return;
        end
        [file,path] = uiputfile('results_ecg.csv','Save results as');
        if isequal(file,0), return; end
        writetable(resultsTable, fullfile(path,file));
        uialert(fig,'Results exported successfully.','Export');
    end

%% helper: load ECG file
    function [sig, sampleRate] = load_ecg_file(fullpath)
        [~,~,ext] = fileparts(fullpath);
        switch lower(ext)
            case '.mat'
                s = load(fullpath);
                % try common names
                if isfield(s,'ecg'), sig = s.ecg;
                elseif isfield(s,'val'), sig = s.val;
                elseif isfield(s,'signal'), sig = s.signal;
                else
                    fields = fieldnames(s);
                    sig = s.(fields{1}); % fallback: first variable
                end
                % sample rate if provided
                if isfield(s,'fs'), sampleRate = s.fs; else sampleRate = 360; end
            case {'.csv', '.txt'}
                M = readmatrix(fullpath);
                if size(M,2) == 1
                    sig = M(:,1);
                else
                    sig = M(:,end); % commonly last column is signal
                end
                sampleRate = 360;
            otherwise
                error('Unsupported file type');
        end
        sig = double(sig(:));
    end

%% helper: synthetic ECG
    function s = create_synthetic_ecg(fs_local, duration)
        t_local = 0:1/fs_local:duration;
        s = zeros(size(t_local));
        % simple repeating template using gaussians
        beatLen = 0.8;
        bt = linspace(-0.4,0.4,round(beatLen*fs_local));
        template = 0.12*exp(-((bt+0.18)/0.03).^2) -0.05*exp(-((bt+0.05)/0.01).^2) +1.0*exp(-((bt)/0.01).^2) -0.2*exp(-((bt-0.03)/0.01).^2) +0.08*exp(-((bt-0.18)/0.04).^2);
        numBeats = ceil(duration/beatLen)+2;
        for k = 1:numBeats
            center = round((k-1)*beatLen*fs_local)+1;
            idx = center + (1:length(bt)) - ceil(length(bt)/2);
            valid = idx > 0 & idx <= length(s);
            s(idx(valid)) = s(idx(valid)) + template(valid);
        end
        s = s + 0.02*sin(2*pi*0.33*t_local) + 0.01*randn(size(t_local));
        s = s(:);
    end

end
