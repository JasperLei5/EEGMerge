% restoredefaultpath;
% rehash toolboxcache;
% Add EEGLAB to the path
eeglabDir = 'specify_eeglab_directory';
addpath(eeglabDir);
% rehash;
% clear;

% folder_paths = {'file_1_path', 'file2_path'};
% file_names = {'file_1', 'file_2'};
% output_file_name = 'output_file_name';  % Specify the output filename
% output_dir = 'output_directory';  % Specify the correct path to your output directory
% start_index = {1, 1};  % Default start indices for trials
% end_index = {[167], [211]};  % Default end indices for trials, empty means use the maximum

% Load EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab; close;
%Load and process each file
for i = 1:length(file_names)
    full_file_path = fullfile(folder_paths{i}, file_names{i});
    disp(['Loading file: ' full_file_path]);
    EEG = pop_loadcurry(full_file_path, 'CurryLocations', 'False', 'CurryReference', 'False', 'CurryAOCodes', 'False'); %OR EEG = pop_loadcurry(full_file_path);
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET+1);
    disp(['Number of events in EEG' num2str(i) ': ' num2str(length(EEG.event))]); %num2str() converts number to string
    % Get start and end events
    num_start_events = sum([EEG.event.type] == 13); %get count of start events
    num_end_events = sum([EEG.event.type] == 14);
    disp(['Number of start events in EEG' num2str(i) ': ' num2str(num_start_events)]);
    disp(['Number of end events in EEG' num2str(i) ': ' num2str(num_end_events)]);
    
    % Set end index to max number of trials if not specified
    if isempty(end_index{i}) %check if end_index is empty
        end_index{i} = min(num_start_events, num_end_events); %ensures end index does not exceed the number of available trials
    end
    % disp the end index for both
    disp(['End index for EEG' num2str(i) ': ' num2str(end_index{i})]);
    % Validate trial range
    if start_index{i} > end_index{i} || start_index{i} < 1 || end_index{i} > min(num_start_events, num_end_events)
        error('Invalid trial range specified for file %d', i);
    end

    % Remove broken trials
    trial_intervals_to_remove = []; %store broken trials
    for j = 1:length(EEG.event) %loop through all events
        if EEG.event(j).type == 13 %check for start marker 
            trial_start_index = j;
            trial_end_index = find([EEG.event(j:end).type] == 14, 1) + j - 1; %find corresponding end marker for trial
            %check if trial is broken
            % no_14 found or    end index < start index, or end index > length of EEG.event, these are indications of broken trials, if found, add to trial_intervals_to_remove
            if isempty(trial_end_index) || trial_end_index > length(EEG.event) || trial_end_index < trial_start_index 
                if trial_start_index > 1
                    trial_intervals_to_remove = [trial_intervals_to_remove; EEG.event(trial_start_index-1).latency, EEG.event(trial_start_index).latency]; %inconsistent indices
                else
                    trial_intervals_to_remove = [trial_intervals_to_remove; 0, EEG.event(trial_start_index).latency]; %missing end case
                end
            end
        end
    end
    
    % disp trial_intervals_to_remove
    disp(['Number of broken trials in EEG' num2str(i) ': ' num2str(size(trial_intervals_to_remove, 1))]);
    if ~isempty(trial_intervals_to_remove) %check it is not empty
        EEG = eeg_eegrej(EEG, trial_intervals_to_remove); %remove the broken trials
    end

    crop_latency_start = 0;
    crop_latency_end = 0;
    ccc=int32(0); 
    for j =1:length(EEG.event)  
        event_type = EEG.event(j).type;
        if isstring(event_type) || ischar(event_type)
            % disp(['event_type is string ' event_type]);
            % return;
            event_type = str2double(event_type);
        end

        if event_type == 13 % end trial event 
            ccc = ccc + 1;
            disp(['start trial count   ' string(ccc)]);
            % disp(['trial_count   ' string(trial_count)]);
            if ccc == start_index{i}
                disp(['start trial Found   ' string(ccc)]);
                crop_latency_start = EEG.event(j).latency;
                break
            end
        end
    end    
    ccc=int32(0); 
    for j =1:length(EEG.event)
        event_type = EEG.event(j).type;
        if isstring(event_type) || ischar(event_type)
            % disp(['event_type is string ' event_type]);
            % return;
            event_type = str2double(event_type);
        end

        % detect  if type is str or double
        if event_type == 14 % end trial event 
            ccc = ccc + 1;
            disp(['end trial count   ' string(ccc)]);
            % disp(['trial_count   ' string(trial_count)]);
            if ccc == end_index{i}
                disp(['end trial Found   ' string(ccc)]);
                crop_latency_end = EEG.event(j).latency;
                break
            end
        end
    end
    
    sample_rate = 1000;
    crop_latency_start = crop_latency_start/sample_rate;
    crop_latency_end = crop_latency_end/sample_rate;
    disp(['crop_latency_start   ' string(crop_latency_start) '   crop_latency_end   ' string(crop_latency_end)]);
    EEG = pop_select( EEG, 'time',[crop_latency_start-1 crop_latency_end+0.1]);


    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET); %store clean dataset
    % disp('BREAKING POINT')
    % return;
end

% Merge the datasets
disp('Merging datasets...');
EEG = pop_mergeset(ALLEEG, 1:length(file_names), 0);
disp('Datasets merged successfully.');
disp(['Number of events in merged EEG: ' num2str(length(EEG.event))]);

% Count the number of start and end events in the merged dataset
num_start_events_merged = sum([EEG.event.type] == 13);
num_end_events_merged = sum([EEG.event.type] == 14);
disp(['Number of start events in merged EEG: ' num2str(num_start_events_merged)]);
disp(['Number of end events in merged EEG: ' num2str(num_end_events_merged)]);

% Ensure the output directory exists
if ~exist(output_dir, 'dir')
   mkdir(output_dir);
end

% Save the merged dataset
EEG = pop_saveset(EEG, 'filename', output_file_name, 'filepath', output_dir);  % Save the final merged dataset
disp(['Merged dataset saved to ' fullfile(output_dir, output_file_name)]);