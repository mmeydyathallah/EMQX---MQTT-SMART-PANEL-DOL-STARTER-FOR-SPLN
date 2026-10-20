# MQTT DOL Starter

Flutter starter for the Stitch design **IoT DOL Starter Controller**.

## Run

After installing Flutter, run:

```bash
flutter pub get
flutter run -d <device-id> --dart-define=EMQX_HOST=YOUR_EMQX_HOST --dart-define=EMQX_PORT=8084 --dart-define=EMQX_USERNAME=YOUR_MQTT_USERNAME --dart-define=EMQX_PASSWORD=YOUR_MQTT_PASSWORD
```

Broker settings can also be entered at runtime via the in-app **Pengaturan** screen. Never commit real credentials: pass them through `--dart-define` or environment variables. `EMQX_PORT` 8084 = MQTT over WebSocket Secure (WSS), 8883 = MQTT over TLS.

## MQTT command contract (ESP32)

The app publishes JSON commands to `dol/starter/command` (QoS 1, non-retained):

| App button     | Published payload                    | ESP32 relay | GPIO |
|----------------|--------------------------------------|-------------|------|
| START FORWARD  | `{"command":"START_FORWARD"}`        | Relay 1     | 13   |
| START REVERSE  | `{"command":"START_REVERSE"}`        | Relay 2     | 14   |
| STOP           | `{"command":"STOP"}`                 | Relay 3     | 25   |
| MODE MANUAL    | `{"command":"MODE_MANUAL"}`          | Relay 4     | 26   |
| MODE AUTO      | `{"command":"MODE_AUTO"}`            | Relay 5     | 27   |
| SPACE          | `{"command":"SPACE"}`                | Relay 6     | 32   |

ESP32 subscribes to `dol/starter/command`, matches the `command` value, then pulses/drives the matching relay pin.

## Telemetry (ESP32 -> app)

The ESP32 publishes retained JSON to `dol/starter/status`; the app subscribes and shows the real device state:

```json
{"forward":false,"reverse":false,"manual":false,"auto":false,"space":false,"rssi":-58,"online":true}
```

- `online:false` (Last Will) marks the device as disconnected (`ESP32 OFFLINE`).
- The app maps the first active flag to the status card: `forward` -> MAJU, `reverse` -> MUNDUR, `manual` -> MODE MANUAL, `auto` -> MODE AUTO, `space` -> SPACE, else SIAGA.

Firmware: [`esp32/dol_starter_esp32/dol_starter_esp32.ino`](esp32/dol_starter_esp32/dol_starter_esp32.ino) (Libraries: PubSubClient >= 2.8.0).
