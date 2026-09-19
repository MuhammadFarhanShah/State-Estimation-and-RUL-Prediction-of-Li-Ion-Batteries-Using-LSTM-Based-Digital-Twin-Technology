// --- Pins ---
const int voltagePin = A0;
const int currentPin = A1;

// --- Constants ---
const float V_DIV_RATIO = (33.0 + 10.0) / 10.0; 
const float ACS_SENSITIVITY = 0.300; // Correct for 5A module
float acsOffset = 2.5;               // Default center

void setup() {
  Serial.begin(115200);
  
  // Auto-Calibration: Average 100 readings to find true zero-current voltage
  float tempOffset = 0;
  for(int i = 0; i < 100; i++) {
    tempOffset += (analogRead(currentPin) * 5.0 / 1023.0);
    delay(10);
  }
  acsOffset = tempOffset / 100.0; 
}

void loop() {
  // 1. Read Voltage
  float voltage = (analogRead(voltagePin) * 5.0 / 1023.0) * V_DIV_RATIO;

  // 2. Read Current with Smoothing (Moving Average)
  float currentSum = 0;
  for(int i = 0; i < 50; i++) {
    float vOut = (analogRead(currentPin) * 5.0 / 1023.0);
    currentSum += (vOut - acsOffset) / ACS_SENSITIVITY;
  }
  float current = currentSum / 50.0;

  // 3. Small "Deadzone" filter
  if (abs(current) < 0.05) current = 0.0; 

  // Send to MATLAB
  Serial.print(voltage/4, 3);
  Serial.print(",");
  Serial.println(current, 3);

  delay(500); 
}