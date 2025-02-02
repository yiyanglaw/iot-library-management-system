import serial
import time
import cv2
import paho.mqtt.client as mqtt
import base64
import requests
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Configuration
WRITE_API_KEY = 'OEH1GUAT6UXH5P6N'
THINGSPEAK_URL = 'https://api.thingspeak.com/update'
SERIAL_PORT = '/dev/ttyUSB0'
BAUD_RATE = 9600
THINGSPEAK_INTERVAL = 15
MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883
MQTT_TOPIC = "raspberrypi/video_stream"

# Setup Arduino connection
try:
    arduino = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
    time.sleep(2)
except Exception as e:
    logging.error(f"Arduino connection failed: {e}")
    arduino = None

# Setup MQTT
mqtt_client = mqtt.Client()
try:
    mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
    mqtt_client.loop_start()
except Exception as e:
    logging.error(f"MQTT connection failed: {e}")
    mqtt_client = None

# Setup Camera
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    logging.error("Failed to initialize camera")
    cap = None

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
        logging.error(f"Error reading data: {e}")
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
        logging.info("Data uploaded to ThingSpeak")
    except requests.exceptions.RequestException as e:
        logging.error(f"ThingSpeak upload error: {e}")

def stream_video():
    """Capture and stream video via MQTT"""
    while True:
        if not cap:
            return
        
        ret, frame = cap.read()
        if not ret:
            logging.error("Failed to capture video frame")
            continue

        _, buffer = cv2.imencode('.jpg', frame)
        jpg_as_text = base64.b64encode(buffer).decode("utf-8")

        if mqtt_client:
            mqtt_client.publish(MQTT_TOPIC, jpg_as_text)

        time.sleep(1)

def main():
    """Main loop"""
    last_update = 0

    try:
        while True:
            sensor_data = get_sensor_data()
            if sensor_data and time.time() - last_update >= THINGSPEAK_INTERVAL:
                upload_to_thingspeak(sensor_data)
                last_update = time.time()
            
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Shutting down system")
    finally:
        if arduino:
            arduino.close()
        if cap:
            cap.release()
        if mqtt_client:
            mqtt_client.loop_stop()
            mqtt_client.disconnect()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
