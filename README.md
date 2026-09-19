This project presents a Digital Twin (DT) framework for lithium-ion battery management using Long Short-Term Memory (LSTM) neural networks to perform real-time State of Health (SoH) estimation and Remaining Useful Life (RUL) prediction.

Project Overview
The framework addresses the accuracy degradation of traditional static electrochemical models by training two stacked LSTM neural networks on the NASA battery degradation dataset. It builds a continuously synchronized virtual model of a physical battery using real-time sensor streams.

System Architecture
The system is built on a three-layer architecture:

1. Physical Sensing Layer: An Arduino microcontroller samples terminal voltage and discharge current from a lithium-ion cell and streams telemetry to MATLAB via a 115200 baud serial connection. Temperature is set to 25°C for the prototype.


2. Digital Twin Inference Layer: A sliding window circular buffer maintains 20 consecutive measurement vectors. Once filled, the buffer normalizes the vector values and passes them to the pre-trained LSTM inference engine to continuously update SoH and RUL estimates.


3. Supervisory Control Layer: A closed-loop supervisory controller ingests predicted states to enforce six protection and optimization strategies.



Dataset and Preprocessing Pipeline

* Source: Uses discharge cycle files from NASA's battery aging dataset (cells B0005 through B0048).


* Capacity Tracking: Employs Coulomb counting to calculate delivered capacity per cycle.


* Data Cleaning: Truncates data at a 2.7V cutoff and removes severely degraded cycles yielding 1.4 Ah or less.


* Downsampling: Variable discharge traces are downsampled into fixed 20-bin sequences per cycle where values inside each bin are averaged.


* Normalization: Features are standardized using Z-score normalization based on training set statistics.



LSTM Network Architectures

* SoH Estimation Model: Accepts 4 features per time step (voltage, current, temperature, State of Charge) to output a scalar health percentage.


* RUL Prediction Model: Accepts 5 features per time step, adding predicted SoH alongside voltage, current, temperature, and State of Charge to estimate remaining discharge cycles until end-of-life.


* Network Structure: Both models consist of a 4 or 5 feature input layer, a 64-unit sequence LSTM layer, a 20% dropout layer, a 32-unit last-step LSTM layer, a 64-unit fully connected layer with ReLU activation, and a single regression output.


* Training Configuration: Trained with the Adam optimizer over 120 epochs using a mini-batch size of 32 and an 80/20 train/test split.



Supervisory Control Strategies

* Adaptive C-Rate Derating: Throttles maximum current based on SoH.


* Thermal Throttling: Reduces PWM duty cycle based on temperature and State of Charge.


* End-of-Life Prediction: Triggers safe mode or service alerts based on predicted RUL.


* Resistance Compensation: Adjusts the cutoff voltage threshold based on voltage and current.


* Dynamic Energy Reserve: Adjusts the 0% State of Charge floor based on State of Charge and SoH.


* Stress Factor Mitigation: Limits high-power bursts using voltage, current, and temperature data.



How to Run the Project

1. Load raw NASA battery dataset files into MATLAB.


2. Run the preprocessing script to execute Coulomb counting, 20-bin downsampling, and Z-score normalization.


3. Train the SoH and RUL LSTM models using MATLAB Deep Learning Toolbox.


4. Connect the Arduino microcontroller to the target cell and host computer via serial.


5. Launch the sliding-window MATLAB inference engine to receive serial telemetry and compute live predictions.
