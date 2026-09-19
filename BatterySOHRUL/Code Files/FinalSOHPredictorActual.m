%% --- Initialization ---
clear; clc;
load('WorkingPrototype2.mat'); % Must contain 'net', 'mu', 'sigma'

% Battery Parameters
battCapacityAh = 1.8;      % 1800mAh
currentSoC = 0.4;          % Starting SoC (1.0 = 100%)
lastTime = datetime('now');

% Serial Config
serialPort = "COM3"; 
if ~isempty(serialportlist("available"))
    s = serialport(serialPort, 115200);
    flush(s);
else
    error("Check Arduino Connection.");
end

dataBuffer = []; 
fprintf('Live Monitoring Started...\n');
fprintf('V(V) \t I(A) \t SoC(%%) \t | SoH Prediction\n');

while true
    try
        line = readline(s);
        raw = str2num(line);
        
        if length(raw) == 2
            v_live = raw(1);
            i_live = raw(2);
            t_live = 25.0; % Constant temp
            
            % --- Coulomb Counting ---
            nowTime = datetime('now');
            dt = seconds(nowTime - lastTime);
            lastTime = nowTime;
            
            % If discharging, i_live is usually positive from sensor 
            % but SoC should go down. Adjust sign if needed.
            deltaSoC = (i_live * dt) / (battCapacityAh * 3600);
            currentSoC = currentSoC - deltaSoC; 
            currentSoC = max(0, min(1, currentSoC));
            
            % --- Sequence Building ---
            % Format: [Voltage; Current; Temp; SoC]
            newDataPoint = [v_live; i_live; t_live; currentSoC];
            dataBuffer = [dataBuffer, newDataPoint]; % Add as column
            
            % --- Prediction ---
            if size(dataBuffer, 2) == 20
                % Normalize
                XNormalized = (dataBuffer - mu) ./ sigma;
                
                % AI Prediction
                soh_pred = predict(net, XNormalized);
                
                % Print
                fprintf('%.2fV \t %.3fA \t %.1f%% \t | SoH: %.2f%%\n', ...
                    v_live, i_live, currentSoC*100, soh_pred*1);
                
                % Slide Window
                dataBuffer(:, 1) = [];
            end
        end
    catch
        break;
    end
end