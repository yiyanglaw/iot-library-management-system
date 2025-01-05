#include <DHT.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define DHTPIN 7
#define SOUND_PIN A1
#define SMOKE_PIN A2
#define MOTOR_ENA 6
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1

DHT dht(DHTPIN, DHT11);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setup() {
    Serial.begin(9600);
    dht.begin();
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

    // Motor control
    if (temperature > 30) {
        analogWrite(MOTOR_ENA, 255);
    } else {
        analogWrite(MOTOR_ENA, 100);
    }

    // Update OLED display
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.print("Temp: ");
    display.print(temperature);
    display.println(" C");
    display.print("Hum: ");
    display.print(humidity);
    display.println(" %");
    display.print("Smoke: ");
    display.println(smokeLevel);
    display.print("Sound: ");
    display.println(soundLevel);
    display.display();

    delay(500);
}
