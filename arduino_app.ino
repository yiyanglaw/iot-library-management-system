#include <DHT.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Servo.h>

// Pin definitions
#define DHTPIN 7
#define SERVO_PIN 8

#define IR_SENSOR 12
#define LED_PIN 13
#define LDR_PIN A0
#define SOUND_PIN A1
#define SMOKE_PIN A2
#define ECHO_PIN A3
#define TRIG_PIN A4
#define RELAY_PIN 6
#define BUTTON_PIN 5  

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
Servo doorServo;
DHT dht(DHTPIN, DHT11);

struct SensorData {
  float temperature;
  float humidity;
  int peopleCount;
  int lightLevel;
  int smokeLevel;
  int soundLevel;
  bool doorState;
  bool fanStatus;
} sensorData;

// New variables for people counting
bool irObjectPresent = false;
float lastDistance = 0;
bool isFirstDistanceReading = true;
unsigned long lastDisplayToggle = 0;
unsigned long lastSensorRead = 0;
byte displayPage = 0;
bool buttonState = false;
unsigned long ledOnTime = 0;
bool ledState = false;

void setup() {
  pinMode(IR_SENSOR, INPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  Serial.begin(9600);
  dht.begin();
  doorServo.attach(SERVO_PIN);
  
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed"));
    for (;;);
  }
  display.clearDisplay();

  sensorData = {0.0, 0.0, 0, 0, 0, 0, false, false};
}

void loop() {
  readAllSensors();
  checkPeopleCounter();
  checkButtonState();
  updateDisplay();
  sendDataToRPi();
  delay(100);
}

void readAllSensors() {
  if (millis() - lastSensorRead >= 2000) {
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    
    if (!isnan(h) && !isnan(t)) {
      sensorData.humidity = h;
      sensorData.temperature = t;
    }
    
    sensorData.lightLevel = analogRead(LDR_PIN);
    sensorData.soundLevel = analogRead(SOUND_PIN);
    sensorData.smokeLevel = analogRead(SMOKE_PIN);
    
    // Control fan using relay
    if (sensorData.temperature > 34.0) {
      digitalWrite(RELAY_PIN, LOW);
      sensorData.fanStatus = true;
    } else {
      digitalWrite(RELAY_PIN, HIGH);
      sensorData.fanStatus = false;
    }
    
    lastSensorRead = millis();
  }
}

float getDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  long duration = pulseIn(ECHO_PIN, HIGH);
  return duration * 0.034 / 2;
}

void checkPeopleCounter() {
  int irState = digitalRead(IR_SENSOR);
  if (irState == HIGH && !irObjectPresent) {
    irObjectPresent = true;
    digitalWrite(LED_PIN, HIGH);
  }
  else if (irState == LOW && irObjectPresent) {
    irObjectPresent = false;
    sensorData.peopleCount++;
    
    doorServo.write(120);
    delay(1000);
    doorServo.write(60);
  }

  float currentDistance = getDistance();
  if (!isFirstDistanceReading) {
    if (abs(currentDistance - lastDistance) > 3) {
      if (sensorData.peopleCount > 0) {
        sensorData.peopleCount--;
      }
    }
  } else {
    isFirstDistanceReading = false;
  }
  lastDistance = currentDistance;
}

void checkButtonState() {
  buttonState = digitalRead(BUTTON_PIN) == LOW;
  sensorData.doorState = buttonState;
}

void updateDisplay() {
  if (millis() - lastDisplayToggle >= 3000) {
    displayPage = (displayPage + 1) % 2;
    lastDisplayToggle = millis();
  }
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  if (displayPage == 0) {
    display.setCursor(0, 0);
    display.print("Temp: ");
    display.print(sensorData.temperature, 1);
    display.println("C");
    display.print("Hum: ");
    display.print(sensorData.humidity, 1);
    display.println("%");
    display.print("People: ");
    display.println(sensorData.peopleCount);
  } else {
    display.setCursor(0, 0);
    display.print("Light: ");
    display.println(sensorData.lightLevel);
    display.print("Sound: ");
    display.println(sensorData.soundLevel);
    display.print("Smoke: ");
    display.println(sensorData.smokeLevel);
  }

  display.setCursor(0, 24);
  display.print("Fan: ");
  display.println(sensorData.fanStatus ? "ON" : "OFF");
  
  display.display();
}

void sendDataToRPi() {
  Serial.print(sensorData.temperature);
  Serial.print(",");
  Serial.print(sensorData.humidity);
  Serial.print(",");
  Serial.print(sensorData.peopleCount);
  Serial.print(",");
  Serial.print(sensorData.lightLevel);
  Serial.print(",");
  Serial.print(sensorData.smokeLevel);
  Serial.print(",");
  Serial.print(sensorData.soundLevel);
  Serial.print(",");
  Serial.print(sensorData.doorState);
  Serial.print(",");
  Serial.println(sensorData.fanStatus); 
}
