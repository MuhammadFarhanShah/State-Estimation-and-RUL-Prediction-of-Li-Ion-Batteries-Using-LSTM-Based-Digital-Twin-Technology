%% --- Initialization ---
clear; clc;

% 1. Load SoH and RUL Models
m_soh = load('FinalSOHLSTMModel.mat');
m_rul = load('FinalRULLSTMModel.mat');

% --- Battery & Figure Parameters ---
battCapacityAh = 1.8;      
currentSoC = 0.45;          
startTime = datetime('now');
lastTime = startTime;

% Buffers for AI Models (Sliding Window of 20)
soh_buffer = []; 
rul_buffer = []; 

% History for Plotting
time_hist = [];
v_hist = [];
i_hist = [];
t_hist = [];

% --- Dashboard Setup ---
fig = figure('Name', 'Li-ion Battery Digital Twin Dashboard', ...
             'Color', 'k', ... % BLACK BACKGROUND
             'NumberTitle', 'off');

tlo = tiledlayout(3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

% Subplots for Graphs
axV = nexttile(1, [1 1]); grid on; hold on; title('Voltage (V)', 'Color','w','FontName','Consolas');
axI = nexttile(3, [1 1]); grid on; hold on; title('Current (A)', 'Color','w','FontName','Consolas');
axT = nexttile(5, [1 1]); grid on; hold on; title('Temperature (°C)', 'Color','w','FontName','Consolas');

% APPLY DARK MODE + CONSOLAS TO AXES
axesList = [axV, axI, axT];
for ax = axesList
    set(ax, 'Color', 'k', ...
            'XColor', 'w', ...
            'YColor', 'w', ...
            'GridColor', 'w', ...
            'FontName', 'Consolas');
end

% Right Side Panel for Values
axText = nexttile(2, [3 1]);
axis(axText, 'off');

statusText = text(0.1, 0.5, 'Initialising...', ...
    'FontSize', 14, ...
    'FontWeight', 'bold', ...
    'Color', 'w', ...          % WHITE TEXT
    'FontName', 'Consolas', ...% CONSOLAS FONT
    'Parent', axText);

% --- Serial Config ---
serialPort = "COM3"; 
if ~isempty(serialportlist("available"))
    s = serialport(serialPort, 115200);
    flush(s);
else
    error("Check Arduino Connection.");
end

fprintf('--- Dashboard Started ---\n');

while ishandle(fig)
    try
        line = readline(s);
        raw = str2num(line);
        
        if length(raw) == 2
            v_live = raw(1);
            i_live = raw(2);
            t_live = 25.0;
            
            % --- 1. Coulomb Counting (SoC) ---
            nowTime = datetime('now');
            dt = seconds(nowTime - lastTime);
            lastTime = nowTime;
            deltaSoC = (i_live * dt) / (battCapacityAh * 3600);
            currentSoC = max(0, min(1, currentSoC - deltaSoC));
            
            % --- 2. Update Plot History ---
            elapsed = seconds(nowTime - startTime);
            time_hist = [time_hist, elapsed];
            v_hist = [v_hist, v_live];
            i_hist = [i_hist, i_live];
            t_hist = [t_hist, t_live];
            
            if length(time_hist) > 100
                time_hist(1) = []; v_hist(1) = []; i_hist(1) = []; t_hist(1) = [];
            end
            
            % --- 3. AI Prediction Logic ---
            new_soh_point = [v_live; i_live; t_live; currentSoC];
            soh_buffer = [soh_buffer, new_soh_point];
            
            soh_display = "Calculating...";
            rul_display = "Calculating...";
            
            if size(soh_buffer, 2) == 20
                X_soh_norm = (soh_buffer - m_soh.mu) ./ m_soh.sigma;
                current_soh_pred = predict(m_soh.net, X_soh_norm);
                soh_display = sprintf('%.2f %%', current_soh_pred);
                
                new_rul_point = [v_live; i_live; t_live; currentSoC; current_soh_pred];
                rul_buffer = [rul_buffer, new_rul_point];
                
                if size(rul_buffer, 2) == 20
                    X_rul_norm = (rul_buffer - m_rul.mu) ./ m_rul.sigma;
                    rul_pred = predict(m_rul.net, X_rul_norm);
                    rul_display = sprintf('%.0f Cycles', rul_pred);
                    rul_buffer(:, 1) = [];
                end
                soh_buffer(:, 1) = [];
            end
            
            % --- 4. Update Graphs ---
            plot(axV, time_hist, v_hist, 'b', 'LineWidth', 1.5);
            plot(axI, time_hist, i_hist, 'r', 'LineWidth', 1.5);
            plot(axT, time_hist, t_hist, 'g', 'LineWidth', 1.5);
            
            % --- 5. Update Dashboard Values ---
            str = {
                'DIGITAL TWIN STATUS', ...
                '------------------------', ...
                sprintf('Time: %.1fs', elapsed), ...
                '', ...
                'PHYSICAL STATES:', ...
                sprintf('Voltage: %.2f V', v_live), ...
                sprintf('Current: %.2f A', i_live), ...
                sprintf('Temp:    %.1f °C', t_live), ...
                '', ...
                'ESTIMATED METRICS:', ...
                sprintf('SoC:     %.1f %%', currentSoC * 100), ...
                sprintf('SoH:     %s', soh_display), ...
                sprintf('RUL:     %s', rul_display), ...
                '------------------------', ...
                'System Status: ONLINE'
            };
            set(statusText, 'String', str);
            
            drawnow limitrate;
            
        end
    catch ME
        fprintf('Disconnected: %s\n', ME.message);
        break;
    end
end