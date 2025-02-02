import serial
import time
import requests

# Configuration
WRITE_API_KEY = 'OEH1GUAT6UXH5P6N'
THINGSPEAK_URL = 'https://api.thingspeak.com/update'
SERIAL_PORT = '/dev/ttyUSB0'
BAUD_RATE = 9600
THINGSPEAK_INTERVAL = 15  # Upload interval in seconds

# Connect to Arduino
try:
    arduino = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
    time.sleep(2)
except Exception as e:
    print(f"Error connecting to Arduino: {e}")
    arduino = None

def get_sensor_data():
    """Read and parse sensor data from Arduino"""
    if not arduino:
        return None

    try:
        if arduino.in_waiting:
            data = arduino.readline().decode().strip().split(',')
            if len(data) == 3:
                return {
                    'temperature': float(data[0]),
                    'humidity': float(data[1]),
                    'people_count': int(data[2])
                }
    except Exception as e:
        print(f"Error reading data: {e}")
    return None

def upload_to_thingspeak(sensor_data):
    """Upload data to ThingSpeak"""
    if not sensor_data:
        return
    
    payload = {
        'api_key': WRITE_API_KEY,
        'field1': sensor_data['people_count'],
        'field2': sensor_data['temperature'],
        'field3': sensor_data['humidity']
    }
    try:
        requests.post(THINGSPEAK_URL, data=payload, timeout=10)
    except requests.exceptions.RequestException as e:
        print(f"ThingSpeak upload error: {e}")

def main():
    """Main loop"""
    last_update = 0

    while True:
        sensor_data = get_sensor_data()
        if sensor_data and time.time() - last_update >= THINGSPEAK_INTERVAL:
            upload_to_thingspeak(sensor_data)
            last_update = time.time()
        
        time.sleep(1)

if __name__ == "__main__":
    main()
