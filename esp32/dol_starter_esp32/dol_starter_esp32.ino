/*
 * ============================================================================
 *  DOL Starter - ESP32 MQTT Firmware
 * ============================================================================
 *  Broker   : EMQX Cloud (MQTT over TLS/SSL, port 8883)
 *  Subscribe: dol/starter/command   <- JSON {"command":"..."}
 *  Publish  : dol/starter/status    -> JSON status (retained)
 *
 *  Peta tombol aplikasi Flutter -> relay -> GPIO:
 *    START_FORWARD -> Relay 1 -> GPIO13
 *    START_REVERSE -> Relay 2 -> GPIO14
 *    STOP          -> Relay 3 -> GPIO25
 *    MODE_MANUAL   -> Relay 4 -> GPIO26
 *    MODE_AUTO     -> Relay 5 -> GPIO27
 *    SPACE         -> Relay 6 -> GPIO32
 *
 *  Board   : ESP32 (Arduino core 2.0.x / 3.x)
 *  Library : PubSubClient (Nick O'Leary) >= 2.8.0
 * ============================================================================
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>

// ======================= KONFIGURASI (WAJIB DIISI) ==========================
const char* WIFI_SSID   = "GANTI_SSID_WIFI";
const char* WIFI_PASS   = "GANTI_PASSWORD_WIFI";

const char* MQTT_HOST   = "GANTI_HOST_EMQX";
const int   MQTT_PORT   = 8883;                 // MQTT over TLS/SSL
const char* MQTT_USER   = "GANTI_USERNAME_MQTT";
const char* MQTT_PASS   = "GANTI_PASSWORD_MQTT";
const char* CLIENT_ID   = "esp32-dol-starter";  // harus unik per device

const char* TOPIC_CMD    = "dol/starter/command";
const char* TOPIC_STATUS = "dol/starter/status";
// ============================================================================

// ======================= KONFIGURASI PERILAKU RELAY ========================
// 1 = START/STOP bersifat MOMENTARY (pulse singkat, meniru tekan tombol fisik).
//     Cocok bila relay disambung paralel dengan push-button panel DOL.
// 0 = START bersifat LATCHING (relay bertahan ON) + interlock antar arah.
//     Cocok bila relay memicu koil kontaktor secara langsung.
#define PULSE_START_STOP   1

// Modul relay umumnya ACTIVE-LOW. Set false bila modul Anda active-HIGH.
#define RELAY_ACTIVE_LOW   1

const uint16_t PULSE_MS     = 500;   // durasi pulse tombol START/STOP
const uint16_t INTERLOCK_MS = 300;   // jeda mati antar arah (anti hubung-singkat)
const uint32_t HEARTBEAT_MS = 30000; // interval publish status saat idle
// ============================================================================

// ============================== PIN RELAY ==================================
const int PIN_FORWARD = 13;
const int PIN_REVERSE = 14;
const int PIN_STOP    = 25;
const int PIN_MANUAL  = 26;
const int PIN_AUTO    = 27;
const int PIN_SPACE   = 32;

const int RELAY_ON  = RELAY_ACTIVE_LOW ? LOW  : HIGH;
const int RELAY_OFF = RELAY_ACTIVE_LOW ? HIGH : LOW;
// ============================================================================

// Root CA EMQX (isi bila memakai mode aman; lihat USE_INSECURE_TLS di setup()).
static const char* EMQX_CA = R"EOF(
-----BEGIN CERTIFICATE-----
ISI_ROOT_CA_EMQX_DI_SINI
-----END CERTIFICATE-----
)EOF";

WiFiClientSecure tls;
PubSubClient mqtt(tls);

// State logis (dipakai untuk status feedback ke aplikasi)
bool forwardOn = false;
bool reverseOn = false;
bool manualOn  = false;
bool autoOn    = false;
bool spaceOn   = false;

// ---------------------------------------------------------------------------
// Utilitas
// ---------------------------------------------------------------------------
inline void driveRelay(int pin, bool on) {
  digitalWrite(pin, on ? RELAY_ON : RELAY_OFF);
}

void allRelaysOff() {
  driveRelay(PIN_FORWARD, false);
  driveRelay(PIN_REVERSE, false);
  driveRelay(PIN_STOP,    false);
  driveRelay(PIN_MANUAL,  false);
  driveRelay(PIN_AUTO,    false);
  driveRelay(PIN_SPACE,   false);
}

void pulseRelay(int pin) {
  driveRelay(pin, true);
  delay(PULSE_MS);
  driveRelay(pin, false);
}

// ---------------------------------------------------------------------------
// Kontrol motor (dengan interlock anti forward+reverse bersamaan)
// ---------------------------------------------------------------------------
void runForward() {
  driveRelay(PIN_REVERSE, false);
  reverseOn = false;
  delay(INTERLOCK_MS);
#if PULSE_START_STOP
  pulseRelay(PIN_FORWARD);
#else
  driveRelay(PIN_FORWARD, true);
#endif
  forwardOn = true;
}

void runReverse() {
  driveRelay(PIN_FORWARD, false);
  forwardOn = false;
  delay(INTERLOCK_MS);
#if PULSE_START_STOP
  pulseRelay(PIN_REVERSE);
#else
  driveRelay(PIN_REVERSE, true);
#endif
  reverseOn = true;
}

void stopMotor() {
  if (forwardOn)  driveRelay(PIN_FORWARD, false);
  if (reverseOn)  driveRelay(PIN_REVERSE, false);
#if PULSE_START_STOP
  pulseRelay(PIN_STOP);
#else
  driveRelay(PIN_STOP, true);
  delay(PULSE_MS);
  driveRelay(PIN_STOP, false);
#endif
  forwardOn = false;
  reverseOn = false;
}

void setMode(bool manual) {
  if (manual) {
    driveRelay(PIN_AUTO, false);
    driveRelay(PIN_MANUAL, true);
  } else {
    driveRelay(PIN_MANUAL, false);
    driveRelay(PIN_AUTO, true);
  }
  manualOn = manual;
  autoOn   = !manual;
}

// ---------------------------------------------------------------------------
// Parser JSON sederhana: ambil nilai "command" tanpa library eksternal
// ---------------------------------------------------------------------------
String extractCommand(const String& json) {
  int k = json.indexOf("\"command\"");
  if (k < 0) return "";
  int colon = json.indexOf(':', k);
  if (colon < 0) return "";
  int first = json.indexOf('"', colon + 1);
  if (first < 0) return "";
  int last = json.indexOf('"', first + 1);
  if (last < 0) return "";
  return json.substring(first + 1, last);
}

// ---------------------------------------------------------------------------
// Eksekusi perintah
// ---------------------------------------------------------------------------
void handleCommand(const String& cmd) {
  if (cmd == "START_FORWARD") {
    runForward();
  } else if (cmd == "START_REVERSE") {
    runReverse();
  } else if (cmd == "STOP") {
    stopMotor();
  } else if (cmd == "MODE_MANUAL") {
    setMode(true);
  } else if (cmd == "MODE_AUTO") {
    setMode(false);
  } else if (cmd == "SPACE") {
    spaceOn = !spaceOn;
    driveRelay(PIN_SPACE, spaceOn);
  } else {
    Serial.printf("[CMD] Tidak dikenal: %s\n", cmd.c_str());
    return;
  }
  Serial.printf("[CMD] %s -> ok\n", cmd.c_str());
  publishStatus();
}

// ---------------------------------------------------------------------------
// Status feedback (retained)
// ---------------------------------------------------------------------------
void publishStatus() {
  String s = "{\"forward\":" + String(forwardOn ? "true" : "false") +
             ",\"reverse\":" + String(reverseOn ? "true" : "false") +
             ",\"manual\":"  + String(manualOn  ? "true" : "false") +
             ",\"auto\":"    + String(autoOn    ? "true" : "false") +
             ",\"space\":"   + String(spaceOn   ? "true" : "false") +
             ",\"rssi\":"    + String(WiFi.RSSI()) + "}";
  mqtt.publish(TOPIC_STATUS, s.c_str(), true);
}

// ---------------------------------------------------------------------------
// Callback MQTT
// ---------------------------------------------------------------------------
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  msg.reserve(length);
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.printf("[MQTT] %s -> %s\n", topic, msg.c_str());

  String cmd = extractCommand(msg);
  if (cmd.length() == 0) {           // fallback bila payload berupa string polos
    cmd = msg;
    cmd.trim();
  }
  if (cmd.length() > 0) handleCommand(cmd);
}

// ---------------------------------------------------------------------------
// Koneksi WiFi & MQTT
// ---------------------------------------------------------------------------
void connectWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("[WiFi] Menghubungkan");
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(300);
    Serial.print('.');
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED)
    Serial.printf("[WiFi] Terhubung, IP=%s\n", WiFi.localIP().toString().c_str());
  else
    Serial.println("[WiFi] Gagal, akan dicoba lagi");
}

bool connectMqtt() {
  String cid = String(CLIENT_ID) + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  // Last Will & Testament: broker menandai device offline bila koneksi terputus
  bool ok = mqtt.connect(cid.c_str(), MQTT_USER, MQTT_PASS,
                         TOPIC_STATUS, 1, true, "{\"online\":false}");
  if (ok) {
    mqtt.subscribe(TOPIC_CMD, 1);
    mqtt.publish(TOPIC_STATUS, "{\"online\":true}", true);
    Serial.println("[MQTT] Terhubung ke EMQX (TLS)");
  } else {
    Serial.printf("[MQTT] Gagal connect, state=%d\n", mqtt.state());
  }
  return ok;
}

// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== DOL Starter ESP32 booting ===");

  pinMode(PIN_FORWARD, OUTPUT);
  pinMode(PIN_REVERSE, OUTPUT);
  pinMode(PIN_STOP,    OUTPUT);
  pinMode(PIN_MANUAL,  OUTPUT);
  pinMode(PIN_AUTO,    OUTPUT);
  pinMode(PIN_SPACE,   OUTPUT);
  allRelaysOff();

  // TLS: setInsecure() cepat untuk uji; untuk produksi pakai CA cert.
  // Ganti baris di bawah dengan:  tls.setCACert(EMQX_CA);
  tls.setInsecure();

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setKeepAlive(30);
  mqtt.setBufferSize(512);

  connectWifi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWifi();

  if (!mqtt.connected()) {
    static uint32_t lastAttempt = 0;
    if (millis() - lastAttempt > 3000) {
      lastAttempt = millis();
      connectMqtt();
    }
  } else {
    mqtt.loop();

    static uint32_t lastBeat = 0;
    if (millis() - lastBeat > HEARTBEAT_MS) {
      lastBeat = millis();
      publishStatus();
    }
  }

  delay(10);
}
