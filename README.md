# ChickTemp

Flutter poultry environment monitoring app with ESP32, DHT22, and HC-SR04 support.

## ESP32 + DHT22 and HC-SR04 setup

1. Open `arduino/chicktemp_esp32_dht22_hcsr04/chicktemp_esp32_dht22_hcsr04.ino` in Arduino IDE.
2. Install the Adafruit `DHT sensor library` from Library Manager.
3. Select an ESP32 board, for example `ESP32 Dev Module`.
4. Wire the DHT22:
   - VCC -> ESP32 3.3V
   - GND -> ESP32 GND
   - DATA -> ESP32 GPIO 14
5. Wire the water HC-SR04:
   - VCC -> ESP32 5V
   - GND -> ESP32 GND
   - TRIG -> ESP32 GPIO 5
   - ECHO -> ESP32 GPIO 18 through a voltage divider (for example, 1 kOhm from ECHO to GPIO 18 and 2 kOhm from GPIO 18 to GND)
6. Wire the feeder HC-SR04:
   - VCC -> ESP32 5V rail
   - GND -> ESP32 GND rail
   - TRIG -> ESP32 GPIO 22
   - ECHO -> ESP32 GPIO 23 through its own voltage divider (for example, 1 kOhm from ECHO to GPIO 23 and 2 kOhm from GPIO 23 to GND)
7. Measure the sensor-to-water distance when the tank is empty and full, then update `WATER_TANK_EMPTY_DISTANCE_CM` and `WATER_TANK_FULL_DISTANCE_CM` in the sketch.
   - Mount the sensor level and pointing straight down.
   - Keep the full-water surface at least 2-3 cm from the sensor.
   - Use the Serial Monitor distance reading for both calibration measurements.
   - Avoid mounting directly above strong water flow, foam, or tank-wall obstructions.
8. Measure the sensor-to-feed distance when the feeder is empty and full, then update `FEEDER_EMPTY_DISTANCE_CM` and `FEEDER_FULL_DISTANCE_CM`.
9. Upload the sketch.
10. If `WIFI_SSID` is left empty, connect your phone to the ESP32 WiFi network:
   - SSID: `ChickTemp-ESP32`
   - Password: `chicktemp123`
   - Sensor URL: `http://192.168.4.1/sensor`

## Standalone operation

The laptop is only needed once to upload the Arduino sketch. The program is stored in the ESP32 flash memory and starts automatically whenever power is supplied.

For permanent operation:

1. Power the ESP32 through its USB port using a stable 5V, 1A or higher phone charger.
2. Power the HC-SR04 from the ESP32 `5V` or `VIN` pin.
3. Power the DHT22 from the ESP32 `3.3V` pin.
4. Connect all sensor grounds to ESP32 `GND`.
5. Keep the HC-SR04 ECHO voltage divider in place before GPIO 18.
6. Upload the sketch once, disconnect the laptop, and connect the USB power adapter.

The ESP32 automatically reads both sensors, serves `/sensor`, reconnects to the configured farm WiFi after outages, and uploads readings to Firebase. Its `ChickTemp-ESP32` local access point remains available even when farm WiFi is unavailable.

Temperature and humidity are sampled continuously. Every 15 minutes, the ESP32 saves the average of all valid DHT22 readings collected during that interval to `environmental_logs`. Analytics also groups older records into 15-minute intervals before calculating its cards and charts.

The Flutter app polls `http://192.168.4.1/sensor` by default. If you set WiFi credentials in the sketch and the ESP32 joins your router, run Flutter with the ESP32 IP printed in Arduino Serial Monitor:

```powershell
flutter run --dart-define=CHICKTEMP_SENSOR_URL=http://YOUR_ESP32_IP/sensor
```

Android builds include local HTTP access for the ESP32 endpoint. If no sensor value is available, the app shows zero values with a no-sensor status.

## Firebase Realtime Database setup

Use this when you want the app to work anywhere, even when the phone is not near the ESP32.

1. Create a Firebase project.
2. Create a Realtime Database.
3. Start in test mode while developing.
4. Copy the Realtime Database URL, for example:

```text
https://chicktemp-default-rtdb.asia-southeast1.firebasedatabase.app
```

5. Paste that URL into:
   - `lib/models/sensor_config.dart`
   - `arduino/chicktemp_esp32_dht22_hcsr04/chicktemp_esp32_dht22_hcsr04.ino`

6. In the Arduino sketch, also fill in the farm WiFi:

```cpp
const char* WIFI_SSID = "YourWiFiName";
const char* WIFI_PASSWORD = "YourWiFiPassword";
const char* FIREBASE_DATABASE_URL = "https://your-database-url.firebasedatabase.app";
```

7. Upload the Arduino sketch again.

The data path becomes:

```text
DHT22 + HC-SR04 -> ESP32 -> Firebase /sensor/latest -> ChickTemp app
```

The ESP32 writes this live Firebase structure:

```json
{
  "status": "ok",
  "temperature": 30.4,
  "humidity": 68,
  "water_status": "ok",
  "water_level_percent": 74,
  "water_distance_cm": 10.0,
  "device": "esp32-dht22-hcsr04",
  "local_ip": "192.168.43.120",
  "access_point_ip": "192.168.4.1"
}
```

`local_ip` is the address assigned by the farm WiFi or phone hotspot. `access_point_ip` is only reachable from a device connected directly to the `ChickTemp-ESP32` WiFi network.

Existing DHT11 records do not need to be deleted. The app continues to read their temperature and humidity fields, while new records add the water-level fields.

For testing, these Realtime Database rules allow reads and writes:

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

Do not use open rules for production. Add authentication or a backend before using this with real customer data.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
