clc; clear; close all;

%% --- Load dataset ---
df = readtable('battery_health_dataset.csv');

df.battery_id = string(df.battery_id);

features = {'Voltage_measured','Current_measured','Temperature_measured','SoC'};

grouped = findgroups(df.battery_id, df.cycle_number);

X = {};
Y = {};

%% --- Build sequences (same logic as Python) ---
num_groups = max(grouped);

for g = 1:num_groups

    idx = (grouped == g);
    data_g = df(idx,:);

    % ensure 20-bin structure
    if height(data_g) ~= 20
        continue;
    end

    % sort just in case
    data_g = sortrows(data_g);

    % INPUT: V I T SoC
    X{end+1} = data_g{:,features}';  % [features × time]

    % OUTPUT: SoH (single per cycle)
    Y{end+1} = data_g.SoH(1);
end

X = X';
Y = cell2mat(Y');

%% --- Train/Test Split (battery-safe not needed here but ok) ---
rng(42);
N = length(X);
idx = randperm(N);

train_ratio = 0.8;
n_train = floor(train_ratio*N);

train_idx = idx(1:n_train);
test_idx  = idx(n_train+1:end);

XTrain = X(train_idx);
YTrain = Y(train_idx);

XTest = X(test_idx);
YTest = Y(test_idx);

%% --- Normalize (IMPORTANT) ---
all_train = cat(2, XTrain{:});
mu = mean(all_train,2);
sigma = std(all_train,0,2) + 1e-6;

for i = 1:length(XTrain)
    XTrain{i} = (XTrain{i} - mu) ./ sigma;
end

for i = 1:length(XTest)
    XTest{i} = (XTest{i} - mu) ./ sigma;
end

%% --- LSTM MODEL (same logic as Keras) ---
inputSize = 4;

layers = [
    sequenceInputLayer(inputSize)

    lstmLayer(64,'OutputMode','sequence')
    dropoutLayer(0.2)

    lstmLayer(32,'OutputMode','last')

    fullyConnectedLayer(64)
    reluLayer

    fullyConnectedLayer(1)

    regressionLayer
];

%% --- Training Options ---
options = trainingOptions('adam', ...
    'MaxEpochs',120, ...
    'MiniBatchSize',32, ...
    'Shuffle','every-epoch', ...
    'ValidationData',{XTest,YTest}, ...
    'ValidationFrequency',10, ...
    'Plots','training-progress', ...
    'Verbose',true);

%% --- Train ---
net = trainNetwork(XTrain,YTrain,layers,options);

%% --- Predict ---
YPred = predict(net,XTest);

%% --- Metrics ---
mae = mean(abs(YTest - YPred));
rmse = sqrt(mean((YTest - YPred).^2));
r2 = 1 - sum((YTest - YPred).^2) / sum((YTest - mean(YTest)).^2);

fprintf('MAE  : %.4f\n',mae);
fprintf('RMSE : %.4f\n',rmse);
fprintf('R2   : %.4f\n',r2);

%% --- Plot ---
figure;
scatter(YTest, YPred);
xlabel('True SoH'); ylabel('Predicted SoH');
title('SoH Prediction');
grid on;
save('lstm_soh_model.mat','net','mu','sigma');