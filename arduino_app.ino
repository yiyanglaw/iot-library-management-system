#include <DHT.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define DHTPIN 7
#define IR_SENSOR 12
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1

DHT dht(DHTPIN, DHT11);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

int peopleCount = 0;
bool irObjectPresent = false;

void setup() {
    Serial.begin(9600);
    dht.begin();

    pinMode(IR_SENSOR, INPUT);

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

    int irState = digitalRead(IR_SENSOR);
    if (irState == HIGH && !irObjectPresent) {
        irObjectPresent = true;
        peopleCount++;
    } else if (irState == LOW && irObjectPresent) {
        irObjectPresent = false;
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
    display.print("People: ");
    display.println(peopleCount);
    display.display();

    delay(500);
}
