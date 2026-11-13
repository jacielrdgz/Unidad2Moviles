# Demo Estación Climatica · ESP32 + Supabase + Flutter

Práctica 2.3 sin ThingsBoard: el ESP32 manda telemetría a **Supabase**, una regla en la base crea las
alarmas y una app **Flutter** (Android y web) hace de dashboard.

## Preparación (una sola vez)
1. **Base de datos.** Usa el mismo proyecto de Supabase de `PERSISTENCIA`. En Supabase > **SQL Editor**:
   1. Pegar `supabase.sql` > **Run** (es idempotente, se puede repetir).
   2. Pegar `supabase_test.sql` > **Run**. Termina en `rollback`: prueba la regla y no deja datos.
      Si no sale error, la regla funciona.
2. **Firmware** (`esp32/estacion_climatica/`):
   1. Copiar `secrets.example.h` como `secrets.h` y llenar `WIFI_SSID`, `WIFI_PASS` (red de **2.4 GHz**),
      `SUPABASE_URL` y `SUPABASE_KEY` (la **publishable key**, nunca la secret/service_role).
      `secrets.h` está en `.gitignore`.
   2. Arduino IDE: placa **ESP32 Dev Module**. Librerías: **DHT sensor library** y **ArduinoJson** 7.
   3. Subir `estacion_climatica.ino`. En **Monitor Serie** a **115200** debe verse
      `[HTTP] POST Status Code: 201` cada pocos segundos.
3. **App**: `flutter pub get`, y luego:
   - **Web**: `flutter run -d web-server --web-port 8080` y abrir http://localhost:8080 en Chrome.
   - **Android**: `flutter run`.

## Prueba de alarma sin calentar el sensor
Simula una lectura de 35 °C. Dos formas equivalentes (con la app abierta en la pestaña **Dashboard**):

**SQL Editor**
```sql
insert into telemetria(temperature,humidity,air_quality,local_alarm_status,rssi)
values (35,40,1800,true,-60);
```

**curl** (el ESP32 hace exactamente este POST; reemplazar los placeholders)
```bash
curl -X POST "https://TU_PROYECTO.supabase.co/rest/v1/telemetria" \
  -H "apikey: TU_PUBLISHABLE_KEY" \
  -H "Authorization: Bearer TU_PUBLISHABLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d '{"temperature":35,"humidity":40,"air_quality":1800,"local_alarm_status":true,"rssi":-60}'
```
Responde `201` sin cuerpo.

Resultado esperado, sin recargar (Realtime):
1. La tarjeta **Temperatura** se pone **roja** y marca `35.0 °C`.
2. Aparece un SnackBar rojo: **High Temperature Alarm – 35.0 °C**.
3. La pestaña dice **Alarmas (1 activas)** y la lista muestra la alarma `CRITICAL · ACTIVE_UNACK`.

Variaciones:
- Un segundo insert con temperatura > 30 **actualiza la misma alarma** (nueva temperatura), no crea otra.
- `30.0` exacto **no** dispara: el umbral es estricto (`> 30`).
- El chip **Online** pasa a **Offline** (gris) si no llega una lectura en 15 s.

## Reconocer / Borrar
En la pestaña **Alarmas**, cada fila ofrece los botones que aplican a su estado:

| Estado | Reconocer | Borrar |
|---|---|---|
| `ACTIVE_UNACK` | pasa a `ACTIVE_ACK` | pasa a `CLEARED_UNACK` |
| `ACTIVE_ACK` | no se muestra | pasa a `CLEARED_ACK` |
| `CLEARED_UNACK` | pasa a `CLEARED_ACK` | no se muestra |
| `CLEARED_ACK` | no se muestra | no se muestra |

- Reconocer guarda `ack_at`; Borrar guarda `cleared_at`.
- **No hay limpieza automática**: si la temperatura baja de 30 la alarma sigue activa hasta pulsar **Borrar**.
- Con la alarma en `CLEARED_*`, el siguiente insert > 30 crea una alarma nueva.

## Equivalencias con ThingsBoard
| ThingsBoard (Práctica 2.3) | Este proyecto |
|---|---|
| Save Timeseries | `insert` en la tabla `telemetria` |
| Script Filter `return msg.temperature > 30;` | `if new.temperature > 30` en `regla_temperatura()` |
| Create Alarm | `insert` / `update` en la tabla `alarmas` |
| Dashboard | App Flutter (Android y web) |
| Respuesta HTTP 200 | Respuesta HTTP 201 |

## Archivos
| Archivo | Rol |
|---|---|
| `supabase.sql` | Tablas `telemetria` y `alarmas`, trigger `regla_temperatura`, RLS para la key pública y Realtime. |
| `supabase_test.sql` | Prueba de la regla (25, 30.0, 35, 36, alarma limpiada). Termina en `rollback`. |
| `esp32/estacion_climatica/estacion_climatica.ino` | Lee DHT11 y MQ-2, enciende LED/buzzer local y hace POST a Supabase. |
| `esp32/estacion_climatica/secrets.example.h` | Plantilla de credenciales; se copia como `secrets.h`. |
| `lib/main.dart` | Inicializa Supabase, escucha los streams, SnackBar de alarmas nuevas y pestañas. |
| `lib/dashboard.dart` | Tarjetas de temperatura, humedad, calidad de aire y señal; chip Online/Offline. |
| `lib/alarmas.dart` | Lista de alarmas con botones Reconocer / Borrar. |
| `lib/modelos.dart` | Modelos `Telemetria` y `Alarma` y transiciones de estado. |
| `lib/repo.dart` | Acceso a Supabase: streams Realtime y cambio de estado. |
| `lib/config.dart` | URL y publishable key de la app. |

## Límites conocidos (para la sustentación)
- La publishable key va en el firmware y en la app. Quien la tenga puede **insertar telemetría**, **leer**
  ambas tablas y cambiar solo `status`, `ack_at` y `cleared_at` de `alarmas` (Reconocer/Borrar). No puede crear
  ni borrar alarmas: solo las crea la regla.
- `client.setInsecure()` en el ESP32 **no valida el certificado TLS**. Para publicarlo habría que usar `setCACert`.
- Las alertas (SnackBar) solo aparecen **con la app abierta**; no hay notificaciones push.

## Tests
`flutter test` cubre modelos, transiciones de alarma y la UI del dashboard y las alarmas.
