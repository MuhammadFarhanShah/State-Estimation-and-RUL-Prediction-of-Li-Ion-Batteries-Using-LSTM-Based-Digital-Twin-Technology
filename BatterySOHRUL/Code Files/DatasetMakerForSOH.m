clc; clear;

% Load metadata
metadata = readtable('metadata.csv');

% Ensure correct types
metadata.battery_id = string(metadata.battery_id);
metadata.filename = string(metadata.filename);
metadata.type = string(metadata.type);

% Exclude problematic batteries
excluded = ["B0049","B0050","B0051","B0052"];

% Filter only discharge cycles
mask = (metadata.type == "discharge") & ~ismember(metadata.battery_id, excluded);
discharge_metadata = metadata(mask, :);

% Assign cycle numbers per battery
discharge_metadata.cycle_number = zeros(height(discharge_metadata),1);

battery_ids = unique(discharge_metadata.battery_id);

for i = 1:length(battery_ids)
    idx = find(discharge_metadata.battery_id == battery_ids(i));
    discharge_metadata.cycle_number(idx) = (1:length(idx))';
end

processed_data = table();

% Loop over each discharge cycle
for i = 1:height(discharge_metadata)

    % --- FIXED filename handling ---
    filename = discharge_metadata.filename(i);
    file_path = fullfile('data', filename);

    % Convert to char for safety
    df = readtable(char(file_path));

    % Skip empty files
    if isempty(df) || height(df) < 5
        continue;
    end

    % --- Truncate at voltage < 2.7V ---
    cutoff_idx = find(df.Voltage_measured < 2.7, 1);

    if isempty(cutoff_idx)
        truncated_df = df;
    else
        if cutoff_idx == 1
            continue; % bad data
        end
        truncated_df = df(1:cutoff_idx-1, :);
    end

    % --- Coulomb counting ---
    time_diff_hr = [0; diff(truncated_df.Time)] / 3600;
    delta_Q = truncated_df.Current_measured .* time_diff_hr;
    capacity = abs(sum(delta_Q));

    % Filter bad cycles
    if capacity <= 1.4
        continue;
    end

    % --- Add metadata ---
    truncated_df.battery_id = repmat(discharge_metadata.battery_id(i), height(truncated_df), 1);
    truncated_df.cycle_number = repmat(discharge_metadata.cycle_number(i), height(truncated_df), 1);

    % --- SoC ---
    cumulative_Q = cumsum(delta_Q);
    SoC = 100 * (1 + cumulative_Q / capacity);

    % --- SoH ---
    SoH = (capacity / 2.0) * 100;

    % --- Downsample to 20 bins ---
    num_bins = 20;
    N = height(truncated_df);

    % Ensure enough data points
    if N < num_bins
        continue;
    end

    indices = round(linspace(1, N+1, num_bins+1));

    rows = table();

    for b = 1:num_bins
        idx_start = indices(b);
        idx_end = indices(b+1) - 1;

        if idx_start > N || idx_end < idx_start
            continue;
        end

        segment = truncated_df(idx_start:idx_end, :);

        avg_voltage = mean(segment.Voltage_measured);
        avg_current = mean(segment.Current_measured);
        avg_temp = mean(segment.Temperature_measured);
        avg_soc = mean(SoC(idx_start:idx_end));

        new_row = table( ...
            avg_voltage, ...
            avg_current, ...
            avg_temp, ...
            avg_soc, ...
            segment.cycle_number(1), ...
            segment.battery_id(1), ...
            SoH, ...
            'VariableNames', ...
            {'Voltage_measured','Current_measured','Temperature_measured','SoC','cycle_number','battery_id','SoH'} ...
        );

        rows = [rows; new_row];
    end

    % Only accept cycles with exactly 20 bins
    if height(rows) ~= num_bins
        continue;
    end

    processed_data = [processed_data; rows];

end

% --- Save dataset ---
if ~isempty(processed_data)
    disp("Final dataset size:");
    disp(size(processed_data));
    writetable(processed_data, 'battery_health_dataset.csv');
else
    disp("No valid data generated.");
end