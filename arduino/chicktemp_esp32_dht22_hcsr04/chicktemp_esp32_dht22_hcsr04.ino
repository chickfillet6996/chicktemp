#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <WebServer.h>
#include <DHT.h>
#include <time.h>

#if defined(__has_include)
#if __has_include(<esp_arduino_version.h>)
#include <esp_arduino_version.h>
#endif
#endif

// Install "DHT sensor library" by Adafruit in Arduino IDE Library Manager.
// Board: ESP32 Dev Module. Default wiring: DHT22 data pin -> GPIO 14.
#define DHTPIN 14
#define DHTTYPE DHT22

// Water HC-SR04: TRIG -> GPIO 5, ECHO -> GPIO 18 through a voltage divider.
#define WATER_ULTRASONIC_TRIG_PIN 5
#define WATER_ULTRASONIC_ECHO_PIN 18
const float WATER_TANK_EMPTY_DISTANCE_CM = 22.0;
const float WATER_TANK_FULL_DISTANCE_CM = 11.6;

// Feeder HC-SR04: TRIG -> GPIO 22, ECHO -> GPIO 23 through a voltage divider.
#define FEEDER_ULTRASONIC_TRIG_PIN 22
#define FEEDER_ULTRASONIC_ECHO_PIN 23
const float FEEDER_EMPTY_DISTANCE_CM = 20.6;
const float FEEDER_FULL_DISTANCE_CM = 6.0;

// Relay K1 / IN1 controls the 12V water pump through a separate 12V supply.
// Most 5V relay modules are active LOW. Change to false if yours works backward.
#define WATER_PUMP_RELAY_PIN 26
#define WATER_PUMP_RELAY_ACTIVE_LOW true

// Relay K2 / IN2 controls the light bulb.
#define LIGHT_BULB_RELAY_PIN 27
#define LIGHT_BULB_RELAY_ACTIVE_LOW true

// Relay K3 / IN3 controls the 5V ventilation fan.
#define VENTILATION_FAN_RELAY_PIN 25
#define VENTILATION_FAN_RELAY_ACTIVE_LOW true

const float DEFAULT_MIN_TEMPERATURE_C = 28.0;
const float DEFAULT_MAX_TEMPERATURE_C = 35.0;

// SG90 feeder servo gate signal.
#define FEEDER_SERVO_PIN 33
// Calibrated for a safer SG90 range. If the flap moves backward, swap these two values.
const int FEEDER_SERVO_CLOSED_PULSE_US = 1000;
const int FEEDER_SERVO_OPEN_PULSE_US = 1800;
const int FEEDER_SERVO_PWM_CHANNEL = 4;
const int FEEDER_SERVO_PWM_FREQUENCY = 50;
const int FEEDER_SERVO_PWM_RESOLUTION = 16;
const unsigned long FEEDER_SERVO_PWM_PERIOD_US = 20000;
const unsigned long FEEDER_SERVO_SETTLE_MS = 700;

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
const unsigned long TIME_SYNC_RETRY_MS = 60000;

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
unsigned long lastTimeSyncRetryMs = 0;
bool hasUploadedEnvironmentalLog = false;
bool timeSyncRequested = false;
bool waterPumpEnabled = false;
bool lightBulbEnabled = false;
bool ventilationFanEnabled = false;
bool temperatureAutomationEnabled = true;
float temperatureAutomationMinC = DEFAULT_MIN_TEMPERATURE_C;
float temperatureAutomationMaxC = DEFAULT_MAX_TEMPERATURE_C;
bool feederServoEnabled = false;
bool feederServoGateOpen = false;
unsigned long waterPumpStopAtMs = 0;
unsigned long feederServoStopAtMs = 0;
unsigned long feederServoSignalOffAtMs = 0;
unsigned long lightBulbOverrideUntilMs = 0;
unsigned long ventilationFanOverrideUntilMs = 0;
long lastWaterPumpCommandId = -1;
long lastFeederServoCommandId = -1;
long lastLightBulbCommandId = -1;
long lastVentilationFanCommandId = -1;
String lastWaterScheduleRunKey = "";
String lastFeederScheduleRunKey = "";
double temperatureLogSum = 0;
double humidityLogSum = 0;
unsigned long environmentalLogSampleCount = 0;

bool relayOverrideActive(unsigned long& overrideUntilMs);
bool jsonBoolValue(String payload, const char* key, bool fallbackValue);
long jsonLongValue(String payload, const char* key, long fallbackValue);
void configureNetworkTime();

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
  payload += "\"light_bulb_override_active\":";
  payload += relayOverrideActive(lightBulbOverrideUntilMs) ? "true" : "false";
  payload += ",";
  payload += "\"ventilation_fan_enabled\":";
  payload += ventilationFanEnabled ? "true" : "false";
  payload += ",";
  payload += "\"ventilation_fan_override_active\":";
  payload += relayOverrideActive(ventilationFanOverrideUntilMs) ? "true" : "false";
  payload += ",";
  payload += "\"feeder_servo_enabled\":";
  payload += feederServoEnabled ? "true" : "false";
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

String firebaseVentilationFanControlUrl() {
  String baseUrl = FIREBASE_DATABASE_URL;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + "/controls/" + FIREBASE_BATCH_ID + "/ventilation_fan.json";
}

String firebaseTemperatureAutomationControlUrl() {
  String baseUrl = FIREBASE_DATABASE_URL;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + "/controls/" + FIREBASE_BATCH_ID + "/temperature_automation.json";
}

String firebaseFeederServoControlUrl() {
  String baseUrl = FIREBASE_DATABASE_URL;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + "/controls/" + FIREBASE_BATCH_ID + "/feeder_servo.json";
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

void setVentilationFanRelay(bool enabled) {
  ventilationFanEnabled = enabled;
  const int activeLevel = VENTILATION_FAN_RELAY_ACTIVE_LOW ? LOW : HIGH;
  const int inactiveLevel = VENTILATION_FAN_RELAY_ACTIVE_LOW ? HIGH : LOW;
  digitalWrite(VENTILATION_FAN_RELAY_PIN, enabled ? activeLevel : inactiveLevel);
}

uint32_t feederServoDutyForPulse(int pulseUs) {
  const uint32_t maxDuty = (1UL << FEEDER_SERVO_PWM_RESOLUTION) - 1;
  return (uint32_t)((pulseUs * maxDuty) / FEEDER_SERVO_PWM_PERIOD_US);
}

void writeFeederServoPulse(int pulseUs) {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(FEEDER_SERVO_PIN, feederServoDutyForPulse(pulseUs));
#else
  ledcWrite(FEEDER_SERVO_PWM_CHANNEL, feederServoDutyForPulse(pulseUs));
#endif
}

void stopFeederServoSignal() {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(FEEDER_SERVO_PIN, 0);
#else
  ledcWrite(FEEDER_SERVO_PWM_CHANNEL, 0);
#endif
}

void setupFeederServoPwm() {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(
    FEEDER_SERVO_PIN,
    FEEDER_SERVO_PWM_FREQUENCY,
    FEEDER_SERVO_PWM_RESOLUTION
  );
#else
  ledcSetup(
    FEEDER_SERVO_PWM_CHANNEL,
    FEEDER_SERVO_PWM_FREQUENCY,
    FEEDER_SERVO_PWM_RESOLUTION
  );
  ledcAttachPin(FEEDER_SERVO_PIN, FEEDER_SERVO_PWM_CHANNEL);
#endif
}

void setFeederServoGate(bool open) {
  feederServoEnabled = open;
  feederServoGateOpen = open;
  feederServoSignalOffAtMs = open ? 0 : millis() + FEEDER_SERVO_SETTLE_MS;
  writeFeederServoPulse(
    open ? FEEDER_SERVO_OPEN_PULSE_US : FEEDER_SERVO_CLOSED_PULSE_US
  );
}

void startWaterPumpRun(unsigned long durationMs) {
  if (durationMs == 0) {
    return;
  }
  setWaterPumpRelay(true);
  waterPumpStopAtMs = millis() + durationMs;
  Serial.print("Timed water pump run: ");
  Serial.print(durationMs / 1000);
  Serial.println(" seconds");
}

void startFeederServoRun(unsigned long durationMs) {
  if (durationMs == 0) {
    return;
  }
  setFeederServoGate(true);
  feederServoStopAtMs = millis() + durationMs;
  Serial.print("Timed feeder servo run: ");
  Serial.print(durationMs / 1000);
  Serial.println(" seconds");
}

void updateTimedActuators() {
  if (waterPumpStopAtMs != 0 && (long)(millis() - waterPumpStopAtMs) >= 0) {
    waterPumpStopAtMs = 0;
    setWaterPumpRelay(false);
    Serial.println("Timed water pump run finished.");
  }

  if (feederServoStopAtMs != 0 && (long)(millis() - feederServoStopAtMs) >= 0) {
    feederServoStopAtMs = 0;
    setFeederServoGate(false);
    Serial.println("Timed feeder servo run finished.");
  }

  if (feederServoSignalOffAtMs != 0 &&
      (long)(millis() - feederServoSignalOffAtMs) >= 0) {
    feederServoSignalOffAtMs = 0;
    stopFeederServoSignal();
  }
}

bool timedActuatorRunActive() {
  return waterPumpStopAtMs != 0 || feederServoStopAtMs != 0;
}

bool relayOverrideActive(unsigned long& overrideUntilMs) {
  if (overrideUntilMs == 0) {
    return false;
  }
  if ((long)(millis() - overrideUntilMs) >= 0) {
    overrideUntilMs = 0;
    return false;
  }
  return true;
}

void applyManualOverrideCommand(
  String payload,
  const char* label,
  long& lastCommandId,
  unsigned long& overrideUntilMs,
  void (*setRelay)(bool)
) {
  long commandId = jsonLongValue(payload, "command_id", -1);
  if (commandId < 0 || commandId == lastCommandId) {
    return;
  }

  lastCommandId = commandId;
  if (jsonBoolValue(payload, "manual_override_cancel", false)) {
    overrideUntilMs = 0;
    Serial.print(label);
    Serial.println(" manual override cleared; automation resumed.");
    return;
  }

  long durationMs = jsonLongValue(payload, "manual_override_duration_ms", 0);
  if (durationMs <= 0) {
    return;
  }

  bool overrideEnabled = jsonBoolValue(payload, "enabled", false);
  overrideUntilMs = millis() + (unsigned long)durationMs;
  setRelay(overrideEnabled);
  Serial.print(label);
  Serial.print(" manual override: ");
  Serial.println(overrideEnabled ? "ON" : "OFF");
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

String readFirebasePayload(String url, const char* label) {
  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.begin(client, url);
  int responseCode = http.GET();
  if (responseCode == 200) {
    String payload = http.getString();
    http.end();
    return payload == "null" ? "" : payload;
  }

  Serial.print(label);
  Serial.print(" control read failed: ");
  Serial.println(responseCode);
  http.end();
  return "";
}

bool jsonBoolValue(String payload, const char* key, bool fallbackValue) {
  String token = "\"";
  token += key;
  token += "\":true";
  if (payload.indexOf(token) >= 0) {
    return true;
  }

  token = "\"";
  token += key;
  token += "\":false";
  if (payload.indexOf(token) >= 0) {
    return false;
  }

  return fallbackValue;
}

long jsonLongValue(String payload, const char* key, long fallbackValue) {
  String token = "\"";
  token += key;
  token += "\":";
  int start = payload.indexOf(token);
  if (start < 0) {
    return fallbackValue;
  }

  start += token.length();
  while (start < payload.length() && payload[start] == ' ') {
    start++;
  }

  int end = start;
  while (end < payload.length() &&
         (payload[end] == '-' || (payload[end] >= '0' && payload[end] <= '9'))) {
    end++;
  }

  if (end <= start) {
    return fallbackValue;
  }

  return payload.substring(start, end).toInt();
}

float jsonFloatValue(String payload, const char* key, float fallbackValue) {
  String token = "\"";
  token += key;
  token += "\":";
  int start = payload.indexOf(token);
  if (start < 0) {
    return fallbackValue;
  }

  start += token.length();
  while (start < payload.length() && payload[start] == ' ') {
    start++;
  }

  int end = start;
  while (end < payload.length() &&
         (payload[end] == '-' ||
          payload[end] == '.' ||
          (payload[end] >= '0' && payload[end] <= '9'))) {
    end++;
  }

  if (end <= start) {
    return fallbackValue;
  }

  return payload.substring(start, end).toFloat();
}

bool readTimedControlCommand(
  String url,
  bool fallbackEnabled,
  const char* label,
  bool& enabled,
  unsigned long& durationMs,
  long& commandId,
  String& payload
) {
  enabled = fallbackEnabled;
  durationMs = 0;
  commandId = -1;
  payload = "";

  payload = readFirebasePayload(url, label);
  if (payload.length() == 0) {
    return false;
  }

  enabled = jsonBoolValue(payload, "enabled", false);
  long parsedDurationMs = jsonLongValue(payload, "duration_ms", 0);
  durationMs = parsedDurationMs > 0 ? (unsigned long)parsedDurationMs : 0;
  commandId = jsonLongValue(payload, "command_id", -1);
  return true;
}

void readTemperatureAutomationConfig() {
  String payload = readFirebasePayload(
    firebaseTemperatureAutomationControlUrl(),
    "Temperature automation"
  );
  if (payload.length() == 0) {
    return;
  }

  bool nextEnabled = jsonBoolValue(payload, "enabled", true);
  float nextMin = jsonFloatValue(
    payload,
    "min_temperature",
    temperatureAutomationMinC
  );
  float nextMax = jsonFloatValue(
    payload,
    "max_temperature",
    temperatureAutomationMaxC
  );

  if (nextMin >= nextMax) {
    Serial.println("Temperature automation range ignored: min >= max");
    return;
  }

  temperatureAutomationEnabled = nextEnabled;
  temperatureAutomationMinC = nextMin;
  temperatureAutomationMaxC = nextMax;
}

void applyTemperatureAutomation() {
  if (!temperatureAutomationEnabled || !isDhtReadingLive || isnan(lastTemperature)) {
    return;
  }

  bool shouldRunFan = lastTemperature > temperatureAutomationMaxC;
  bool shouldRunLight = lastTemperature < temperatureAutomationMinC;
  bool fanOverrideActive = relayOverrideActive(ventilationFanOverrideUntilMs);
  bool lightOverrideActive = relayOverrideActive(lightBulbOverrideUntilMs);

  if (!fanOverrideActive && shouldRunFan != ventilationFanEnabled) {
    setVentilationFanRelay(shouldRunFan);
    Serial.print("Temperature automation fan: ");
    Serial.println(ventilationFanEnabled ? "ON" : "OFF");
  }

  if (!lightOverrideActive && shouldRunLight != lightBulbEnabled) {
    setLightBulbRelay(shouldRunLight);
    Serial.print("Temperature automation light: ");
    Serial.println(lightBulbEnabled ? "ON" : "OFF");
  }
}

bool currentLocalTimeCode(
  char* buffer,
  size_t bufferSize,
  int* yearDay,
  int* weekDay
) {
  struct tm timeInfo;
  if (!getLocalTime(&timeInfo, 250)) {
    if (WiFi.status() == WL_CONNECTED &&
        millis() - lastTimeSyncRetryMs >= TIME_SYNC_RETRY_MS) {
      lastTimeSyncRetryMs = millis();
      configureNetworkTime();
      Serial.println("Schedule clock not ready; retrying time sync.");
    }
    return false;
  }

  snprintf(buffer, bufferSize, "%02d:%02d", timeInfo.tm_hour, timeInfo.tm_min);
  *yearDay = timeInfo.tm_yday;
  *weekDay = timeInfo.tm_wday;
  return true;
}

void runDueScheduleCodes(
  String payload,
  const char* label,
  String& lastRunKey,
  void (*startRun)(unsigned long)
) {
  int scheduleIndex = payload.indexOf("\"schedule_codes\"");
  if (scheduleIndex < 0) {
    return;
  }

  char currentTime[6];
  int yearDay = 0;
  int weekDay = 0;
  if (!currentLocalTimeCode(
        currentTime,
        sizeof(currentTime),
        &yearDay,
        &weekDay
      )) {
    return;
  }

  int cursor = payload.indexOf("[", scheduleIndex);
  int endArray = payload.indexOf("]", cursor);
  if (cursor < 0 || endArray < 0) {
    return;
  }

  while (cursor < endArray) {
    int quoteStart = payload.indexOf("\"", cursor);
    if (quoteStart < 0 || quoteStart >= endArray) {
      break;
    }
    int quoteEnd = payload.indexOf("\"", quoteStart + 1);
    if (quoteEnd < 0 || quoteEnd > endArray) {
      break;
    }

    String code = payload.substring(quoteStart + 1, quoteEnd);
    int firstPipe = code.indexOf("|");
    int secondPipe = code.indexOf("|", firstPipe + 1);
    int thirdPipe = code.indexOf("|", secondPipe + 1);
    int fourthPipe = code.indexOf("|", thirdPipe + 1);
    if (firstPipe > 0 && secondPipe > firstPipe && thirdPipe > secondPipe) {
      String timeCode = code.substring(0, firstPipe);
      unsigned long durationMs = code.substring(firstPipe + 1, secondPipe).toInt();
      bool active = (fourthPipe > thirdPipe
        ? code.substring(thirdPipe + 1, fourthPipe)
        : code.substring(thirdPipe + 1)
      ).toInt() == 1;
      int daysMask = fourthPipe > thirdPipe
        ? code.substring(fourthPipe + 1).toInt()
        : 0x7F;
      if (daysMask <= 0) {
        daysMask = 0x7F;
      }
      bool dayMatches = (daysMask & (1 << weekDay)) != 0;
      String runKey = String(label) + "|" + timeCode + "|" + String(yearDay);
      if (active &&
          dayMatches &&
          durationMs > 0 &&
          timeCode == currentTime &&
          runKey != lastRunKey) {
        lastRunKey = runKey;
        Serial.print(label);
        Serial.print(" scheduled run at ");
        Serial.println(timeCode);
        startRun(durationMs);
      }
    }

    cursor = quoteEnd + 1;
  }
}

void pollControlCommandsIfNeeded() {
  if (WiFi.status() != WL_CONNECTED || !firebaseConfigured()) {
    return;
  }

  updateTimedActuators();
  if (timedActuatorRunActive()) {
    return;
  }

  if (millis() - lastFirebaseControlPollMs < FIREBASE_CONTROL_POLL_INTERVAL_MS) {
    return;
  }

  lastFirebaseControlPollMs = millis();

  bool waterCommandEnabled = waterPumpEnabled;
  unsigned long waterCommandDurationMs = 0;
  long waterCommandId = -1;
  String waterCommandPayload = "";
  bool waterCommandAvailable = readTimedControlCommand(
    firebaseWaterPumpControlUrl(),
    waterPumpEnabled,
    "Water pump",
    waterCommandEnabled,
    waterCommandDurationMs,
    waterCommandId,
    waterCommandPayload
  );
  if (waterCommandAvailable) {
    bool waterSchedulesEnabled = jsonBoolValue(
      waterCommandPayload,
      "schedules_enabled",
      waterCommandEnabled
    );
    if (!waterSchedulesEnabled) {
      if (waterCommandDurationMs > 0 && waterCommandId != lastWaterPumpCommandId) {
        lastWaterPumpCommandId = waterCommandId;
        Serial.println("Water pump timed command ignored: power is off.");
      }
      waterPumpStopAtMs = 0;
      if (waterPumpEnabled) {
        setWaterPumpRelay(false);
        Serial.println("Water pump relay: OFF (power disabled)");
      }
    } else if (waterCommandDurationMs > 0 &&
               waterCommandId != lastWaterPumpCommandId) {
      lastWaterPumpCommandId = waterCommandId;
      startWaterPumpRun(waterCommandDurationMs);
    } else if (waterPumpStopAtMs == 0 &&
               waterCommandEnabled != waterPumpEnabled) {
      setWaterPumpRelay(waterCommandEnabled);
      Serial.print("Water pump relay: ");
      Serial.println(waterPumpEnabled ? "ON" : "OFF");
    }
    if (waterSchedulesEnabled && !waterCommandEnabled) {
      runDueScheduleCodes(
        waterCommandPayload,
        "Water pump",
        lastWaterScheduleRunKey,
        startWaterPumpRun
      );
    }
  }

  String lightBulbPayload = readFirebasePayload(
    firebaseLightBulbControlUrl(),
    "Light bulb"
  );
  bool nextLightBulbEnabled = lightBulbPayload.length() == 0
      ? lightBulbEnabled
      : jsonBoolValue(lightBulbPayload, "enabled", lightBulbEnabled);
  if (lightBulbPayload.length() > 0) {
    applyManualOverrideCommand(
      lightBulbPayload,
      "Light bulb",
      lastLightBulbCommandId,
      lightBulbOverrideUntilMs,
      setLightBulbRelay
    );
  }

  String ventilationFanPayload = readFirebasePayload(
    firebaseVentilationFanControlUrl(),
    "Ventilation fan"
  );
  bool nextVentilationFanEnabled = ventilationFanPayload.length() == 0
      ? ventilationFanEnabled
      : jsonBoolValue(ventilationFanPayload, "enabled", ventilationFanEnabled);
  if (ventilationFanPayload.length() > 0) {
    applyManualOverrideCommand(
      ventilationFanPayload,
      "Ventilation fan",
      lastVentilationFanCommandId,
      ventilationFanOverrideUntilMs,
      setVentilationFanRelay
    );
  }

  readTemperatureAutomationConfig();
  if (temperatureAutomationEnabled && isDhtReadingLive && !isnan(lastTemperature)) {
    applyTemperatureAutomation();
  } else {
    if (!relayOverrideActive(lightBulbOverrideUntilMs) &&
        nextLightBulbEnabled != lightBulbEnabled) {
      setLightBulbRelay(nextLightBulbEnabled);
      Serial.print("Light bulb relay: ");
      Serial.println(lightBulbEnabled ? "ON" : "OFF");
    }
    if (!relayOverrideActive(ventilationFanOverrideUntilMs) &&
        nextVentilationFanEnabled != ventilationFanEnabled) {
      setVentilationFanRelay(nextVentilationFanEnabled);
      Serial.print("Ventilation fan relay: ");
      Serial.println(ventilationFanEnabled ? "ON" : "OFF");
    }
  }

  bool feederCommandEnabled = feederServoEnabled;
  unsigned long feederCommandDurationMs = 0;
  long feederCommandId = -1;
  String feederCommandPayload = "";
  bool feederCommandAvailable = readTimedControlCommand(
    firebaseFeederServoControlUrl(),
    feederServoEnabled,
    "Feeder servo",
    feederCommandEnabled,
    feederCommandDurationMs,
    feederCommandId,
    feederCommandPayload
  );
  if (feederCommandAvailable) {
    bool feederSchedulesEnabled = jsonBoolValue(
      feederCommandPayload,
      "schedules_enabled",
      feederCommandEnabled
    );
    if (!feederSchedulesEnabled) {
      if (feederCommandDurationMs > 0 &&
          feederCommandId != lastFeederServoCommandId) {
        lastFeederServoCommandId = feederCommandId;
        Serial.println("Feeder servo timed command ignored: power is off.");
      }
      feederServoStopAtMs = 0;
      if (feederServoEnabled) {
        setFeederServoGate(false);
        Serial.println("Feeder servo gate: CLOSED (power disabled)");
      }
    } else if (feederCommandDurationMs > 0 &&
               feederCommandId != lastFeederServoCommandId) {
      lastFeederServoCommandId = feederCommandId;
      startFeederServoRun(feederCommandDurationMs);
    } else if (feederServoStopAtMs == 0 &&
               feederCommandEnabled != feederServoEnabled) {
      setFeederServoGate(feederCommandEnabled);
      Serial.print("Feeder servo gate: ");
      Serial.println(feederServoEnabled ? "OPEN" : "CLOSED");
    }
    if (feederSchedulesEnabled && !feederCommandEnabled) {
      runDueScheduleCodes(
        feederCommandPayload,
        "Feeder servo",
        lastFeederScheduleRunKey,
        startFeederServoRun
      );
    }
  }
}

void uploadToFirebaseIfNeeded() {
  if (WiFi.status() != WL_CONNECTED || !firebaseConfigured()) {
    return;
  }

  updateTimedActuators();
  if (timedActuatorRunActive()) {
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
  payload += "\"light_bulb_override_active\":";
  payload += relayOverrideActive(lightBulbOverrideUntilMs) ? "true" : "false";
  payload += ",";
  payload += "\"ventilation_fan_enabled\":";
  payload += ventilationFanEnabled ? "true" : "false";
  payload += ",";
  payload += "\"ventilation_fan_override_active\":";
  payload += relayOverrideActive(ventilationFanOverrideUntilMs) ? "true" : "false";
  payload += ",";
  payload += "\"feeder_servo_enabled\":";
  payload += feederServoEnabled ? "true" : "false";
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

  updateTimedActuators();
  if (timedActuatorRunActive()) {
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

void configureNetworkTime() {
  configTime(8 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  timeSyncRequested = true;
  Serial.println("Network time sync requested.");
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
      configureNetworkTime();
      Serial.print("Connected. Sensor URL: http://");
      Serial.print(WiFi.localIP());
      Serial.println("/sensor");
      return;
    }
  }

  Serial.println("Farm WiFi unavailable. Firebase will resume after reconnection.");
}

void maintainWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!timeSyncRequested) {
      configureNetworkTime();
    }
    return;
  }

  timeSyncRequested = false;

  if (strlen(WIFI_SSID) == 0) {
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
  pinMode(VENTILATION_FAN_RELAY_PIN, OUTPUT);
  setVentilationFanRelay(false);
  setupFeederServoPwm();
  setFeederServoGate(false);
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
  updateTimedActuators();
  pollControlCommandsIfNeeded();
  readSensorIfNeeded();
  updateTimedActuators();
  uploadToFirebaseIfNeeded();
  saveEnvironmentalLogIfNeeded();
  server.handleClient();
}
