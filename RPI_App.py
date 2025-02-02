import serial
import time
import cv2
import paho.mqtt.client as mqtt
import base64
from datetime import datetime
import requests
import threading
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('smart_system.log'),
        logging.StreamHandler()
    ]
)

# Configuration
class Config:
    # ThingSpeak Configuration
    WRITE_API_KEY = 'OEH1GUAT6UXH5P6N'
    CHANNEL_ID = '2794357'
    THINGSPEAK_URL = 'https://api.thingspeak.com/update'
    
    # Serial Configuration
    SERIAL_PORT = '/dev/ttyUSB0'
    BAUD_RATE = 9600
    THINGSPEAK_INTERVAL = 15  # Upload interval in seconds
    
    # MQTT Configuration
    MQTT_BROKER = "broker.hivemq.com"
    MQTT_PORT = 1883
    MQTT_TOPIC = "raspberrypi/video_stream"
    
    # Video Configuration
    FRAME_WIDTH = 640
    FRAME_HEIGHT = 480
    FRAME_RATE = 10

class SmartSystem:
    def __init__(self):
        self.arduino = None
        self.connect_arduino()
        self.last_thingspeak_update = 0
        self.mqtt_client = self.setup_mqtt()
        self.cap = self.setup_camera()
        self.running = True
        self.last_sensor_data = None

    def setup_camera(self):
        """Initialize and configure the camera"""
        cap = cv2.VideoCapture(0)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, Config.FRAME_WIDTH)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, Config.FRAME_HEIGHT)
        cap.set(cv2.CAP_PROP_FPS, Config.FRAME_RATE)
        
        if not cap.isOpened():
            logging.error("Failed to open camera")
            return None
        
        logging.info("Camera initialized successfully")
        return cap

    def connect_arduino(self):
        """Attempt to connect to Arduino with retry mechanism"""
        retry_count = 0
        max_retries = 3
        
        while retry_count < max_retries:
            try:
                self.arduino = serial.Serial(Config.SERIAL_PORT, Config.BAUD_RATE, timeout=1)
                time.sleep(2)  # Allow Arduino to reset
                logging.info("Successfully connected to Arduino")
                return
            except Exception as e:
                retry_count += 1
                logging.error(f"Attempt {retry_count} failed to connect to Arduino: {e}")
                time.sleep(2)
        
        logging.error("Failed to connect to Arduino after maximum retries")
        self.arduino = None

    def setup_mqtt(self):
        """Set up MQTT client with connection handling"""
        def on_connect(client, userdata, flags, rc):
            if rc == 0:
                logging.info("Connected to MQTT Broker")
            else:
                logging.error(f"Failed to connect to MQTT Broker with code {rc}")

        client = mqtt.Client()
        client.on_connect = on_connect
        
        try:
            client.connect(Config.MQTT_BROKER, Config.MQTT_PORT, 60)
            client.loop_start()
            return client
        except Exception as e:
            logging.error(f"MQTT connection error: {e}")
            return None

    def get_sensor_data(self):
        """Read and parse data from Arduino with validation"""
        if not self.arduino:
            self.connect_arduino()
            return None

        try:
            if self.arduino.in_waiting:
                data = self.arduino.readline().decode().strip().split(',')
                if len(data) == 8:  # Expecting 8 fields
                    try:
                        sensor_data = {
                            'temperature': float(data[0]),
                            'humidity': float(data[1]),
                            'people_count': int(data[2]),
                            'light': int(data[3]),
                            'smoke': int(data[4]),
                            'sound': int(data[5]),
                            'door': bool(int(data[6])),
                            'fan_status': bool(int(data[7]))
                        }
                        
                        # Basic validation
                        if (0 <= sensor_data['temperature'] <= 100 and
                            0 <= sensor_data['humidity'] <= 100 and
                            0 <= sensor_data['people_count'] <= 1000):
                            
                            self.last_sensor_data = sensor_data
                            return sensor_data
                        else:
                            logging.warning("Sensor data out of expected range")
                            return self.last_sensor_data
                            
                    except (ValueError, IndexError) as e:
                        logging.error(f"Error parsing sensor data: {e}")
                        return self.last_sensor_data
                else:
                    logging.warning(f"Unexpected number of data fields: {len(data)}")
                    return self.last_sensor_data
                    
        except Exception as e:
            logging.error(f"Error reading Arduino data: {e}")
            return self.last_sensor_data

    def upload_to_thingspeak(self, sensor_data):
        """Upload sensor data to ThingSpeak with error handling"""
        if not sensor_data:
            return

        payload = {
            'api_key': Config.WRITE_API_KEY,
            'field1': sensor_data['people_count'],
            'field2': sensor_data['temperature'],
            'field3': sensor_data['humidity'],
            'field4': sensor_data['light'],
            'field5': sensor_data['smoke'],
            'field6': sensor_data['sound'],
            'field7': int(sensor_data['door']),
            'field8': int(sensor_data['fan_status'])
        }

        try:
            response = requests.post(Config.THINGSPEAK_URL, data=payload, timeout=10)
            if response.status_code == 200:
                logging.info("Data uploaded successfully")
                self._log_sensor_values(sensor_data)
            else:
                logging.error(f"ThingSpeak upload failed with status code: {response.status_code}")
        except requests.exceptions.RequestException as e:
            logging.error(f"ThingSpeak upload error: {e}")

    def _log_sensor_values(self, sensor_data):
        """Log current sensor values"""
        logging.info(
            f"Temperature: {sensor_data['temperature']}°C, "
            f"Humidity: {sensor_data['humidity']}%, "
            f"People: {sensor_data['people_count']}, "
            f"Light: {sensor_data['light']}, "
            f"Smoke: {sensor_data['smoke']}, "
            f"Sound: {sensor_data['sound']}, "
            f"Door: {'Open' if sensor_data['door'] else 'Closed'}, "
            f"Fan: {'ON' if sensor_data['fan_status'] else 'OFF'}"
        )

    def stream_video(self):
        """Capture and stream video frames via MQTT"""
        while self.running and self.cap is not None:
            try:
                ret, frame = self.cap.read()
                if not ret:
                    logging.error("Failed to capture video frame")
                    continue

                # Resize frame to reduce bandwidth
                frame = cv2.resize(frame, (Config.FRAME_WIDTH, Config.FRAME_HEIGHT))
                
                # Compress image
                encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 50]
                _, buffer = cv2.imencode('.jpg', frame, encode_param)
                jpg_as_text = base64.b64encode(buffer).decode("utf-8")

                if self.mqtt_client:
                    self.mqtt_client.publish(Config.MQTT_TOPIC, jpg_as_text)
                
                time.sleep(1/Config.FRAME_RATE)  # Control frame rate
                
            except Exception as e:
                logging.error(f"Video streaming error: {e}")
                time.sleep(1)

    def cleanup(self):
        """Clean up resources"""
        self.running = False
        if self.arduino:
            self.arduino.close()
        if self.cap:
            self.cap.release()
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
        cv2.destroyAllWindows()
        logging.info("System shutdown complete")

    def run(self):
        """Main system loop"""
        try:
            logging.info("Smart System starting...")
            
            # Start video streaming in a separate thread
            video_thread = threading.Thread(target=self.stream_video, daemon=True)
            video_thread.start()

            while self.running:
                sensor_data = self.get_sensor_data()
                
                current_time = time.time()
                if sensor_data and current_time - self.last_thingspeak_update >= Config.THINGSPEAK_INTERVAL:
                    self.upload_to_thingspeak(sensor_data)
                    self.last_thingspeak_update = current_time
                
                time.sleep(0.1)
                
        except KeyboardInterrupt:
            logging.info("System shutdown initiated by user")
        except Exception as e:
            logging.error(f"System error: {e}")
        finally:
            self.cleanup()

def main():
    """Main entry point with error handling"""
    try:
        system = SmartSystem()
        system.run()
    except Exception as e:
        logging.critical(f"Failed to start system: {e}")
        raise

if __name__ == "__main__":
    main()
