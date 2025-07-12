const unsigned long MICROS_PER_PERIOD = 20000;
const int SPEED_ADJ_POT_PIN = A0;
const int RC_PWM_OUT_PIN = 3;

void setup() {
  pinMode(RC_PWM_OUT_PIN, OUTPUT);
}

void loop() {
  unsigned long t0 = micros();

  // high phase
  uint16_t adc = analogRead(SPEED_ADJ_POT_PIN);
  uint16_t pulse_high = 1000UL + ((adc * 1000UL) + 512UL) / 1023UL;
  digitalWrite(RC_PWM_OUT_PIN, HIGH);
  delayMicroseconds(pulse_high); 
 
  // low phase
  digitalWrite(RC_PWM_OUT_PIN, LOW);
  unsigned long target = t0 + MICROS_PER_PERIOD;
  while ((long)(micros() - target) < 0);
}
