// Estación climática ESP32 -> Supabase (REST). Basado en la Práctica 2.3.
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include "secrets.h"  // WIFI_SSID, WIFI_PASS, SUPABASE_URL, SUPABASE_KEY

// ---------- Hardware ----------
#define DHTPIN        4
#define DHTTYPE       DHT11
#define MQ2_PIN       34
#define BUZZER_PIN    18
#define LED_ALARM_PIN 19

// ---------- Umbral crítico local ----------
const float TEMP_THRESHOLD = 30.0;

DHT dht(DHTPIN, DHTTYPE);

// Espera acotada: sin Wi-Fi la alarma local debe seguir funcionando.
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Conectando a Wi-Fi");
  for (int i = 0; i < 20 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) Serial.println("
[OK] Conectado a la Red Wi-Fi");
  else Serial.println("
[WARN] Sin Wi-Fi, sigo con alarma local");
}

unsigned long lastReconnect = 0;

void setup() {
  Serial.begin(115200);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_ALARM_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_ALARM_PIN, LOW);
  dht.begin();
  analogReadResolution(12);
  connectWiFi();
}

void triggerLocalAlarm(bool enable) {
  if (enable) {
    digitalWrite(LED_ALARM_PIN, HIGH);
    tone(BUZZER_PIN, 1000, 200);   // Tono de alerta intermitente
  } else {
    digitalWrite(LED_ALARM_PIN, LOW);
    noTone(BUZZER_PIN);
  }
}

void loop() {
  float temp = dht.readTemperature();
  float hum  = dht.readHumidity();
  int mq_val = analogRead(MQ2_PIN);

  if (isnan(temp) || isnan(hum)) {
    Serial.println("[ERROR] Lectura de DHT11 fallida");
    delay(3000);
    return;
  }

  // Respuesta local inmediata (no depende de la nube)
  bool isAlarm = (temp > TEMP_THRESHOLD);
  triggerLocalAlarm(isAlarm);

  // Reconexión no bloqueante (máx. 1 intento cada 10 s)
  if (WiFi.status() != WL_CONNECTED && millis() - lastReconnect > 10000) {
    Serial.println("[WARN] Wi-Fi perdido, reintentando...");
    WiFi.reconnect();
    lastReconnect = millis();
  }

  // Envío de telemetría a Supabase
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClientSecure client;
    client.setInsecure();  // shortcut: no valida el certificado, usar setCACert si se publica

    HTTPClient http;
    String url = String(SUPABASE_URL) + "/rest/v1/telemetria";
    http.begin(client, url);
    http.addHeader("apikey", SUPABASE_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Prefer", "return=minimal");

    JsonDocument doc;
    doc["temperature"]        = serialized(String(temp, 2));
    doc["humidity"]           = serialized(String(hum, 2));
    doc["air_quality"]        = mq_val;
    doc["local_alarm_status"] = isAlarm;
    doc["rssi"]               = WiFi.RSSI();
    String jsonPayload;
    serializeJson(doc, jsonPayload);

    int httpCode = http.POST(jsonPayload);
    // Éxito = 201 (Created)
    Serial.printf("[HTTP] POST Status Code: %d%s | Payload: %s\n",
                  httpCode, httpCode == 201 ? " (OK)" : "", jsonPayload.c_str());
    http.end();
  }

  delay(4000);
}
