#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <WebServer.h>
#include <DHT.h>

// Install "DHT sensor library" by Adafruit in Arduino IDE Library Manager.
// Board: ESP32 Dev Module. Default wiring: DHT22 data pin -> GPIO 14.
#define DHTPIN 14
#define DHTTYPE DHT22

// Water HC-SR04: TRIG -> GPIO 5, ECHO -> GPIO 18 through a voltage divider.
#define WATER_ULTRASONIC_TRIG_PIN 5
#define WATER_ULTRASONIC_ECHO_PIN 18
const float WATER_TANK_EMPTY_DISTANCE_CM = 30.0;
const float WATER_TANK_FULL_DISTANCE_CM = 3.0;

// Feeder HC-SR04: TRIG -> GPIO 22, ECHO -> GPIO 23 through a voltage divider.
#define FEEDER_ULTRASONIC_TRIG_PIN 22
#define FEEDER_ULTRASONIC_ECHO_PIN 23
const float FEEDER_EMPTY_DISTANCE_CM = 30.0;
const float FEEDER_FULL_DISTANCE_CM = 3.0;

// Relay K1 / IN1 controls the 12V water pump through a separate 12V supply.
// Most 5V relay modules are active LOW. Change to false if yours works backward.
#define WATER_PUMP_RELAY_PIN 26
#define WATER_PUMP_RELAY_ACTIVE_LOW true

// Relay K2 / IN2 controls the light bulb.
#define LIGHT_BULB_RELAY_PIN 27
#define LIGHT_BULB_RELAY_ACTIVE_LOW true

const char* WIFI_SSID = "ZTE_2.4G_uDF6tp";
const char* WIFI_PASSWORD = "Kurtyu082541";

const char* FIREBASE_DATABASE_URL = "https://chicktemp-a6c7e-default-rtdb.asia-southeast1.firebasedatabase.app";
const char* FIREBASE_SENSOR_PATH = "/sensor/latest.json";
const char* FIREBASE_ENVIRONMENTAL_LOGS_PATH = "/environmental_logs.json";
const char* FIREBASE_BATCH_ID = "broiler_batch_1";
const unsigned long FIREBASE_UPLOAD_INTERVAL_MS = 5000;
const unsigned long FIREBASE_ENVIRONMENTAL_LOG_INTERVAL_MS = 15UL * 60UL * 1000UL;
const unsigned long FIREBASE_ENVIRONMENTAL_LOG_RETRY_MS = 10000;
const unsigned long FIREBASE_CONTROL_POLL_INTERVAL_MS = 2000;
const unsigned long WIFI_RECONNECT_INTERVAL_MS = 30000;

const char* AP_SSID = "ChickTemp-ESP32";
const char* AP_PASSWORD = "chicktemp123";

DHT dht(DHTPIN, DHTTYPE);
WebServer server(80);

float lastTemperature = NAN;
float lastHumidity = NAN;
float lastWaterDistanceCm = NAN;
float lastWaterLevelPercent = NAN;
float lastFeederDistanceCm = NAN;
float lastFeederLevelPercent = NAN;
bool isDhtReadingLive = false;
bool isWaterReadingLive = false;
bool isFeederReadingLive = false;
unsigned long lastSensorReadMs = 0;
unsigned long lastFirebaseUploadMs = 0;
unsigned long lastFirebaseLogMs = 0;
unsigned long lastFirebaseLogAttemptMs = 0;
unsigned long lastFirebaseControlPollMs = 0;
unsigned long lastWiFiReconnectAttemptMs = 0;
bool hasUploadedEnvironmentalLog = false;
bool waterPumpEnabled = false;
bool lightBulbEnabled = false;
double temperatureLogSum = 0;
double humidityLogSum = 0;
unsigned long environmentalLogSampleCount = 0;

float readUltrasonicDistanceCm(
  int triggerPin,
  int echoPin,
  float airTemperatureC
) {
  const int sampleCount = 5;
  float samples[sampleCount];
  int validSamples = 0;

  // Median filtering removes occasional echoes from ripples and tank walls.
  for (int sample = 0; sample < sampleCount; sample++) {
    digitalWrite(triggerPin, LOW);
    delayMicroseconds(2);
    digitalWrite(triggerPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(triggerPin, LOW);

    unsigned long echoDuration = pulseIn(echoPin, HIGH, 30000);
    if (echoDuration > 0) {
      float speedCmPerMicrosecond = 0.0343;
      if (!isnan(airTemperatureC)) {
        speedCmPerMicrosecond = (331.3 + (0.606 * airTemperatureC)) / 10000.0;
      }

      float distanceCm = echoDuration * speedCmPerMicrosecond / 2.0;
      if (distanceCm >= 2.0 && distanceCm <= 400.0) {
        samples[validSamples++] = distanceCm;
      }
    }

    delay(60);
  }

  if (validSamples == 0) {
    return NAN;
  }

  for (int i = 0; i < validSamples - 1; i++) {
    for (int j = i + 1; j < validSamples; j++) {
      if (samples[j] < samples[i]) {
        float temporary = samples[i];
        samples[i] = samples[j];
        samples[j] = temporary;
      }
    }
  }

  return samples[validSamples / 2];
}

float levelPercentFromDistance(
  float distanceCm,
  float emptyDistanceCm,
  float fullDistanceCm
) {
  float usableDepth = emptyDistanceCm - fullDistanceCm;
  if (isnan(distanceCm) || usableDepth <= 0) {
    return NAN;
  }

  return constrain(
    (emptyDistanceCm - distanceCm) / usableDepth * 100.0,
    0.0,
    100.0
  );
}

void readSensorIfNeeded() {
  if (millis() - lastSensorReadMs < 2000) {
    return;
  }

  lastSensorReadMs = millis();
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  if (!isnan(humidity) && !isnan(temperature)) {
    isDhtReadingLive = true;
    lastHumidity = humidity;
    lastTemperature = temperature;
    temperatureLogSum += temperature;
    humidityLogSum += humidity;
    environmentalLogSampleCount++;
    Serial.print("Temperature: ");
    Serial.print(lastTemperature, 1);
    Serial.print(" C, Humidity: ");
    Serial.print(lastHumidity, 0);
    Serial.println("%");
  } else {
    isDhtReadingLive = false;
    Serial.println("DHT22 reading failed. Keeping the last valid reading.");
  }

  float measuredWaterDistanceCm = readUltrasonicDistanceCm(
    WATER_ULTRASONIC_TRIG_PIN,
    WATER_ULTRASONIC_ECHO_PIN,
    temperature
  );
  float measuredWaterLevelPercent = levelPercentFromDistance(
    measuredWaterDistanceCm,
    WATER_TANK_EMPTY_DISTANCE_CM,
    WATER_TANK_FULL_DISTANCE_CM
  );
  if (!isnan(measuredWaterLevelPercent)) {
    isWaterReadingLive = true;
    lastWaterDistanceCm = measuredWaterDistanceCm;
    lastWaterLevelPercent = measuredWaterLevelPercent;
    Serial.print("Water distance: ");
    Serial.print(lastWaterDistanceCm, 1);
    Serial.print(" cm, Level: ");
    Serial.print(lastWaterLevelPercent, 0);
    Serial.println("%");
  } else if (WATER_TANK_EMPTY_DISTANCE_CM <= WATER_TANK_FULL_DISTANCE_CM) {
    isWaterReadingLive = false;
    Serial.println("Invalid tank calibration: empty distance must be greater than full distance.");
  } else {
    isWaterReadingLive = false;
    Serial.println("Water HC-SR04 reading failed. Keeping the last valid reading.");
  }

  // Prevent the water sensor's echo from being detected by the feeder sensor.
  delay(75);

  float measuredFeederDistanceCm = readUltrasonicDistanceCm(
    FEEDER_ULTRASONIC_TRIG_PIN,
    FEEDER_ULTRASONIC_ECHO_PIN,
    temperature
  );
  float measuredFeederLevelPercent = levelPercentFromDistance(
    measuredFeederDistanceCm,
    FEEDER_EMPTY_DISTANCE_CM,
    FEEDER_FULL_DISTANCE_CM
  );
  if (!isnan(measuredFeederLevelPercent)) {
    isFeederReadingLive = true;
    lastFeederDistanceCm = measuredFeederDistanceCm;
    lastFeederLevelPercent = measuredFeederLevelPercent;
    Serial.print("Feeder distance: ");
    Serial.print(lastFeederDistanceCm, 1);
    Serial.print(" cm, Level: ");
    Serial.print(lastFeederLevelPercent, 0);
    Serial.println("%");
  } else if (FEEDER_EMPTY_DISTANCE_CM <= FEEDER_FULL_DISTANCE_CM) {
    isFeederReadingLive = false;
    Serial.println("Invalid feeder calibration: empty distance must be greater than full distance.");
  } else {
    isFeederReadingLive = false;
    Serial.println("Feeder HC-SR04 reading failed. Keeping the last valid reading.");
  }
}

void addCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET,OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void handleSensor() {
  readSensorIfNeeded();
  addCorsHeaders();

  String payload = "{";
  payload += "\"status\":\"";
  payload += isDhtReadingLive ? "ok" : "no_read";
  payload += "\",";
  payload += "\"temperature\":";
  payload += String(isnan(lastTemperature) ? 0 : lastTemperature, 1);
  payload += ",";
  payload += "\"humidity\":";
  payload += String(isnan(lastHumidity) ? 0 : lastHumidity, 0);
  payload += ",";
  payload += "\"water_status\":\"";
  payload += isWaterReadingLive ? "ok" : "no_read";
  payload += "\",";
  payload += "\"water_level_percent\":";
  payload += String(isnan(lastWaterLevelPercent) ? 0 : lastWaterLevelPercent, 0);
  payload += ",";
  payload += "\"water_distance_cm\":";
  payload += String(isnan(lastWaterDistanceCm) ? 0 : lastWaterDistanceCm, 1);
  payload += ",";
  payload += "\"feeder_status\":\"";
  payload += isFeederReadingLive ? "ok" : "no_read";
  payload += "\",";
  payload += "\"feeder_level_percent\":";
  payload += String(isnan(lastFeederLevelPercent) ? 0 : lastFeederLevelPercent, 0);
  payload += ",";
  payload += "\"feeder_distance_cm\":";
  payload += String(isnan(lastFeederDistanceCm) ? 0 : lastFeederDistanceCm, 1);
  payload += ",";
  payload += "\"water_pump_enabled\":";
  payload += waterPumpEnabled ? "true" : "false";
  payload += ",";
  payload += "\"light_bulb_enabled\":";
  payload += lightBulbEnabled ? "true" : "false";
  payload += ",";
  payload += "\"device\":\"esp32-dht22-hcsr04\"";
  payload += ",";
  payload += "\"local_ip\":\"";
  payload += WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : "";
  payload += "\",";
  payload += "\"access_point_ip\":\"";
  payload += WiFi.softAPIP().toString();
  payload += "\"";
  payload += "}";

  server.send(200, "application/json", payload);
}

void handleRoot() {
  addCorsHeaders();
  server.send(
    200,
    "text/plain",
    "ChickTemp ESP32 is running. Open /sensor for JSON readings."
  );
}

void handleOptions() {
  addCorsHeaders();
  server.send(204);
}

bool firebaseConfigured() {
  return strlen(FIREBASE_DATABASE_URL) > 0 && strstr(FIREBASE_DATABASE_URL, "YOUR_DATABASE_NAME") == NULL;
}

String firebaseSensorUrl() {
  String baseUrl = FIREBASE_DATABASE_URL;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + FIREBASE_SENSOR_PATH;
}

String firebaseEnvironmentalLogsUrl() {
  String baseUrl = FIREBASE_DATABASE_URL;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + FIREBASE_ENVIRONMENTAL_LOGS_PATH;
}

String firebaseWaterPumpControlUrl() {
  String baseUrl = FIREBASE_DATABASE_URL;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + "/controls/" + FIREBASE_BATCH_ID + "/water_pump.json";
}

String firebaseLightBulbControlUrl() {
  String baseUrl = FIREBASE_DATABASE_URL;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + "/controls/" + FIREBASE_BATCH_ID + "/light_bulb.json";
}

void setWaterPumpRelay(bool enabled) {
  waterPumpEnabled = enabled;
  const int activeLevel = WATER_PUMP_RELAY_ACTIVE_LOW ? LOW : HIGH;
  const int inactiveLevel = WATER_PUMP_RELAY_ACTIVE_LOW ? HIGH : LOW;
  digitalWrite(WATER_PUMP_RELAY_PIN, enabled ? activeLevel : inactiveLevel);
}

void setLightBulbRelay(bool enabled) {
  lightBulbEnabled = enabled;
  const int activeLevel = LIGHT_BULB_RELAY_ACTIVE_LOW ? LOW : HIGH;
  const int inactiveLevel = LIGHT_BULB_RELAY_ACTIVE_LOW ? HIGH : LOW;
  digitalWrite(LIGHT_BULB_RELAY_PIN, enabled ? activeLevel : inactiveLevel);
}

bool readFirebaseEnabledCommand(String url, bool fallbackValue, const char* label) {
  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.begin(client, url);

  int responseCode = http.GET();
  if (responseCode == 200) {
    String payload = http.getString();
    http.end();
    if (payload == "null") {
      return false;
    }
    return payload.indexOf("\"enabled\":true") >= 0;
  }

  Serial.print(label);
  Serial.print(" control read failed: ");
  Serial.println(responseCode);
  http.end();
  return fallbackValue;
}

void pollControlCommandsIfNeeded() {
  if (WiFi.status() != WL_CONNECTED || !firebaseConfigured()) {
    return;
  }

  if (millis() - lastFirebaseControlPollMs < FIREBASE_CONTROL_POLL_INTERVAL_MS) {
    return;
  }

  lastFirebaseControlPollMs = millis();

  bool nextWaterPumpEnabled = readFirebaseEnabledCommand(
    firebaseWaterPumpControlUrl(),
    waterPumpEnabled,
    "Water pump"
  );
  if (nextWaterPumpEnabled != waterPumpEnabled) {
    setWaterPumpRelay(nextWaterPumpEnabled);
    Serial.print("Water pump relay: ");
    Serial.println(waterPumpEnabled ? "ON" : "OFF");
  }

  bool nextLightBulbEnabled = readFirebaseEnabledCommand(
    firebaseLightBulbControlUrl(),
    lightBulbEnabled,
    "Light bulb"
  );
  if (nextLightBulbEnabled != lightBulbEnabled) {
    setLightBulbRelay(nextLightBulbEnabled);
    Serial.print("Light bulb relay: ");
    Serial.println(lightBulbEnabled ? "ON" : "OFF");
  }
}

void uploadToFirebaseIfNeeded() {
  if (WiFi.status() != WL_CONNECTED || !firebaseConfigured()) {
    return;
  }

  if (millis() - lastFirebaseUploadMs < FIREBASE_UPLOAD_INTERVAL_MS) {
    return;
  }

  lastFirebaseUploadMs = millis();

  float temperature = isnan(lastTemperature) ? 0 : lastTemperature;
  float humidity = isnan(lastHumidity) ? 0 : lastHumidity;
  float waterLevel = isnan(lastWaterLevelPercent) ? 0 : lastWaterLevelPercent;
  float waterDistance = isnan(lastWaterDistanceCm) ? 0 : lastWaterDistanceCm;
  float feederLevel = isnan(lastFeederLevelPercent) ? 0 : lastFeederLevelPercent;
  float feederDistance = isnan(lastFeederDistanceCm) ? 0 : lastFeederDistanceCm;
  const char* status = isDhtReadingLive ? "ok" : "no_read";
  const char* waterStatus = isWaterReadingLive ? "ok" : "no_read";
  const char* feederStatus = isFeederReadingLive ? "ok" : "no_read";

  String payload = "{";
  payload += "\"status\":\"";
  payload += status;
  payload += "\",";
  payload += "\"temperature\":";
  payload += String(temperature, 1);
  payload += ",";
  payload += "\"humidity\":";
  payload += String(humidity, 0);
  payload += ",";
  payload += "\"water_status\":\"";
  payload += waterStatus;
  payload += "\",";
  payload += "\"water_level_percent\":";
  payload += String(waterLevel, 0);
  payload += ",";
  payload += "\"water_distance_cm\":";
  payload += String(waterDistance, 1);
  payload += ",";
  payload += "\"feeder_status\":\"";
  payload += feederStatus;
  payload += "\",";
  payload += "\"feeder_level_percent\":";
  payload += String(feederLevel, 0);
  payload += ",";
  payload += "\"feeder_distance_cm\":";
  payload += String(feederDistance, 1);
  payload += ",";
  payload += "\"water_pump_enabled\":";
  payload += waterPumpEnabled ? "true" : "false";
  payload += ",";
  payload += "\"light_bulb_enabled\":";
  payload += lightBulbEnabled ? "true" : "false";
  payload += ",";
  payload += "\"device\":\"esp32-dht22-hcsr04\",";
  payload += "\"local_ip\":\"";
  payload += WiFi.localIP().toString();
  payload += "\",";
  payload += "\"access_point_ip\":\"";
  payload += WiFi.softAPIP().toString();
  payload += "\",";
  payload += "\"updated_at\":{\".sv\":\"timestamp\"}";
  payload += "}";

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.begin(client, firebaseSensorUrl());
  http.addHeader("Content-Type", "application/json");

  int responseCode = http.PUT(payload);
  Serial.print("Firebase upload: ");
  Serial.println(responseCode);
  http.end();
}

void saveEnvironmentalLogIfNeeded() {
  if (WiFi.status() != WL_CONNECTED || !firebaseConfigured()) {
    return;
  }

  if (environmentalLogSampleCount == 0) {
    return;
  }

  if (hasUploadedEnvironmentalLog &&
      millis() - lastFirebaseLogMs < FIREBASE_ENVIRONMENTAL_LOG_INTERVAL_MS) {
    return;
  }

  if (lastFirebaseLogAttemptMs != 0 &&
      millis() - lastFirebaseLogAttemptMs < FIREBASE_ENVIRONMENTAL_LOG_RETRY_MS) {
    return;
  }

  lastFirebaseLogAttemptMs = millis();

  float temperature = temperatureLogSum / environmentalLogSampleCount;
  float humidity = humidityLogSum / environmentalLogSampleCount;
  float waterLevel = isnan(lastWaterLevelPercent) ? 0 : lastWaterLevelPercent;
  float waterDistance = isnan(lastWaterDistanceCm) ? 0 : lastWaterDistanceCm;
  float feederLevel = isnan(lastFeederLevelPercent) ? 0 : lastFeederLevelPercent;
  float feederDistance = isnan(lastFeederDistanceCm) ? 0 : lastFeederDistanceCm;

  String payload = "{";
  payload += "\"batch_id\":\"";
  payload += FIREBASE_BATCH_ID;
  payload += "\",";
  payload += "\"device_id\":\"esp32-dht22-hcsr04\",";
  payload += "\"temperature\":";
  payload += String(temperature, 1);
  payload += ",";
  payload += "\"humidity\":";
  payload += String(humidity, 0);
  payload += ",";
  payload += "\"sample_count\":";
  payload += String(environmentalLogSampleCount);
  payload += ",";
  payload += "\"aggregation_minutes\":15,";
  payload += "\"water_level_percent\":";
  payload += String(waterLevel, 0);
  payload += ",";
  payload += "\"water_distance_cm\":";
  payload += String(waterDistance, 1);
  payload += ",";
  payload += "\"water_status\":\"";
  payload += isWaterReadingLive ? "ok" : "no_read";
  payload += "\",";
  payload += "\"feeder_level_percent\":";
  payload += String(feederLevel, 0);
  payload += ",";
  payload += "\"feeder_distance_cm\":";
  payload += String(feederDistance, 1);
  payload += ",";
  payload += "\"feeder_status\":\"";
  payload += isFeederReadingLive ? "ok" : "no_read";
  payload += "\",";
  payload += "\"recorded_at\":{\".sv\":\"timestamp\"}";
  payload += "}";

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.begin(client, firebaseEnvironmentalLogsUrl());
  http.addHeader("Content-Type", "application/json");

  int responseCode = http.POST(payload);
  Serial.print("Environmental log upload: ");
  Serial.println(responseCode);
  if (responseCode == 200) {
    lastFirebaseLogMs = millis();
    hasUploadedEnvironmentalLog = true;
    temperatureLogSum = 0;
    humidityLogSum = 0;
    environmentalLogSampleCount = 0;
  } else {
    Serial.println("Environmental log failed. Check Firebase rules and database URL.");
  }
  http.end();
}

void startWiFi() {
  // AP + station mode keeps local access available while Firebase uses farm WiFi.
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  Serial.print("Local access point: ");
  Serial.print(AP_SSID);
  Serial.print(" at http://");
  Serial.print(WiFi.softAPIP());
  Serial.println("/sensor");

  if (strlen(WIFI_SSID) > 0) {
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    Serial.print("Connecting to WiFi");
    unsigned long startedAt = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startedAt < 15000) {
      delay(500);
      Serial.print(".");
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.print("Connected. Sensor URL: http://");
      Serial.print(WiFi.localIP());
      Serial.println("/sensor");
      return;
    }
  }

  Serial.println("Farm WiFi unavailable. Firebase will resume after reconnection.");
}

void maintainWiFi() {
  if (WiFi.status() == WL_CONNECTED || strlen(WIFI_SSID) == 0) {
    return;
  }

  if (millis() - lastWiFiReconnectAttemptMs < WIFI_RECONNECT_INTERVAL_MS) {
    return;
  }

  lastWiFiReconnectAttemptMs = millis();
  Serial.println("Reconnecting to farm WiFi...");
  WiFi.disconnect(false, false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void setup() {
  Serial.begin(115200);
  delay(300);
  dht.begin();
  pinMode(WATER_ULTRASONIC_TRIG_PIN, OUTPUT);
  pinMode(WATER_ULTRASONIC_ECHO_PIN, INPUT);
  digitalWrite(WATER_ULTRASONIC_TRIG_PIN, LOW);
  pinMode(FEEDER_ULTRASONIC_TRIG_PIN, OUTPUT);
  pinMode(FEEDER_ULTRASONIC_ECHO_PIN, INPUT);
  digitalWrite(FEEDER_ULTRASONIC_TRIG_PIN, LOW);
  pinMode(WATER_PUMP_RELAY_PIN, OUTPUT);
  setWaterPumpRelay(false);
  pinMode(LIGHT_BULB_RELAY_PIN, OUTPUT);
  setLightBulbRelay(false);
  startWiFi();

  server.on("/", HTTP_GET, handleRoot);
  server.on("/sensor", HTTP_GET, handleSensor);
  server.on("/sensor", HTTP_OPTIONS, handleOptions);
  server.begin();
  Serial.println("HTTP server started");
  Serial.println("Environmental logs will upload to Firebase every 15 minutes.");
}

void loop() {
  maintainWiFi();
  pollControlCommandsIfNeeded();
  readSensorIfNeeded();
  uploadToFirebaseIfNeeded();
  saveEnvironmentalLogIfNeeded();
  server.handleClient();
}
