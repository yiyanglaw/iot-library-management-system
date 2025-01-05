#include <DHT.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define DHTPIN 7
#define IR_SENSOR 12
#define SMOKE_PIN A2
#define SOUND_PIN A1
#define MOTOR_ENA 6
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1

DHT dht(DHTPIN, DHT11);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

int peopleCount = 0;
bool irObjectPresent = false;
unsigned long lastDisplayToggle = 0;
byte displayPage = 0;

void setup() {
    Serial.begin(9600);
    dht.begin();
    pinMode(IR_SENSOR, INPUT);
    pinMode(MOTOR_ENA, OUTPUT);

    if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
        Serial.println(F("SSD1306 allocation failed"));
        for (;;);
    }
    display.clearDisplay();
}

void loop() {
    // Sensor readings
    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    int smokeLevel = analogRead(SMOKE_PIN);
    int soundLevel = analogRead(SOUND_PIN);

    // People counting logic
    int irState = digitalRead(IR_SENSOR);
    if (irState == HIGH && !irObjectPresent) {
        irObjectPresent = true;
        peopleCount++;
    } else if (irState == LOW && irObjectPresent) {
        irObjectPresent = false;
    }

    // Motor control
    if (temperature > 30) {
        analogWrite(MOTOR_ENA, 255);
    } else {
        analogWrite(MOTOR_ENA, 100);
    }

    // Display toggling
    if (millis() - lastDisplayToggle > 3000) {
        displayPage = (displayPage + 1) % 2;
        lastDisplayToggle = millis();
    }

    // Update OLED
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    if (displayPage == 0) {
        display.setCursor(0, 0);
        display.print("Temp: ");
        display.print(temperature);
        display.println(" C");
        display.print("Hum: ");
        display.print(humidity);
        display.println(" %");
        display.print("People: ");
        display.println(peopleCount);
    } else {
        display.setCursor(0, 0);
        display.print("Smoke: ");
        display.println(smokeLevel);
        display.print("Sound: ");
        display.println(soundLevel);
    }
    display.display();

    delay(500);
}
