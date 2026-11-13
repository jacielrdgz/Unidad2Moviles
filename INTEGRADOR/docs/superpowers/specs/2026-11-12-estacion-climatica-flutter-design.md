# Diseño: Estación climática ESP32 + Supabase + app Flutter

Fecha: 2026-11-12 · Carpeta: `INTEGRADOR/`

## Intención

Replicar la Práctica 2.3 ("Procesamiento en la nube (Rule Engine) y disparo de alertas") cambiando
ThingsBoard Cloud por una app Flutter propia que corra en **Android y en navegador**, igual que
`PERSISTENCIA/`. Regla del equipo: **lo que más se apegue a la práctica original**.

Se conserva la lógica híbrida:
- **Local (ESP32):** temperatura > 30 °C enciende LED (GPIO 19) y buzzer (GPIO 18) sin depender de la red.
- **Nube:** cada lectura se guarda; una regla en el servidor crea la alarma "High Temperature Alarm".
- **App:** dashboard en vivo + lista de alarmas con aviso inmediato al llegar una nueva.

## Objetivos
1. Mismo hardware, pines y umbral que la práctica (DHT11 GPIO 4, MQ-2 GPIO 34 con divisor 10k+10k, LED GPIO 19, buzzer GPIO 18, 30 °C, ciclo de 4 s).
2. Mismas claves de telemetría: `temperature`, `humidity`, `air_quality`, `local_alarm_status`, más `rssi` (la Figura 4 del reporte mostraba "señal Wi-Fi").
3. Motor de reglas en la nube equivalente a `Save Timeseries → Script Filter (temperature > 30) → True → Create Alarm`.
4. App Flutter (Android + web) con indicadores como el dashboard de ThingsBoard: temperatura, humedad, calidad de aire, señal Wi-Fi y estado Online/Offline del dispositivo.
5. Lista de alarmas con estados tipo ThingsBoard (activa sin reconocer / reconocida / borrada) y botones Reconocer y Borrar.

## No-objetivos
- Push notifications con la app cerrada (FCM). El aviso es dentro de la app abierta.
- Login/usuarios. Igual que PERSISTENCIA: publishable key + RLS abierta para `anon`.
- Modo offline/SQLite en la app.
- Gráficas históricas, varios dispositivos, calibración del MQ-2 a ppm (se queda el valor crudo 0–4095 como en la práctica).

## Anti-objetivos
- Que la alarma dependa de que la app esté abierta (eso rompería el "procesamiento en la nube").
- Poner la `service_role`/secret key en el ESP32 o en la app.

## Restricciones
- Red Wi-Fi 2.4 GHz con internet; Supabase exige HTTPS.
- Web corre con `flutter run -d web-server --web-port 8080` (mismo flujo que PERSISTENCIA).

## Enfoques considerados
| Enfoque | Trade-off | Decisión |
|---|---|---|
| **A. Supabase (REST + trigger + Realtime)** | Necesita internet; ESP32 con HTTPS. La regla corre en el servidor aunque la app esté cerrada; funciona en Android y web desde cualquier red; reusa el stack de PERSISTENCIA. | **Elegido por el equipo.** |
| B. ESP32 como servidor web en red local | Mismo Wi-Fi obligatorio, IP cambiante, regla en la app; pierde la parte de nube. | Descartado. |
| C. Broker MQTT público | Sin historial, inseguro, regla en la app. | Descartado. |

## Diseño

### 1. Supabase (`supabase.sql`, se pega en SQL Editor)
Proyecto: el mismo de PERSISTENCIA (*decisión mía*: ya existe y la app ya tiene su URL/key). Tablas nuevas, no toca `lecturas`.

**`telemetria`** (equivale a Save Timeseries)
`id bigserial pk · device text default 'ESP32_Estacion_Climatica' · temperature double precision · humidity double precision · air_quality int · local_alarm_status boolean · rssi int · created_at timestamptz default now()`

**`alarmas`** (equivale a las alarmas de ThingsBoard)
`id bigserial pk · device text · type text default 'High Temperature Alarm' · severity text default 'CRITICAL' · status text ('ACTIVE_UNACK' | 'ACTIVE_ACK' | 'CLEARED_UNACK' | 'CLEARED_ACK') · temperature double precision (última lectura que la disparó) · created_at · updated_at · ack_at · cleared_at`

**Motor de reglas:** función `regla_temperatura()` + trigger `AFTER INSERT ON telemetria`:
- Script Filter: `if new.temperature > 30` (umbral como constante en la función).
- Create Alarm: si ya hay una alarma activa (`ACTIVE_*`) del mismo `device` y `type`, actualiza `temperature` y `updated_at` (ThingsBoard no duplica alarmas activas); si no, inserta una nueva `ACTIVE_UNACK`.
- No hay borrado automático al bajar de 30 °C (la práctica no usó Clear Alarm); se borra a mano desde la app. Una lectura > 30 después de borrar crea una alarma nueva.

**Acceso:** RLS activada; `anon` puede `insert` en `telemetria`, `select` en ambas, `update` en `alarmas` (reconocer/borrar).
**Realtime:** ambas tablas se agregan a la publicación `supabase_realtime`.

### 2. Firmware ESP32 (`esp32/estacion_climatica/estacion_climatica.ino`)
Mismo código de la práctica, con tres cambios:
- Envío: `POST https://<proyecto>.supabase.co/rest/v1/telemetria` con headers `apikey`, `Authorization: Bearer <publishable key>`, `Content-Type: application/json`, `Prefer: return=minimal`. Éxito = **HTTP 201** (antes 200).
- HTTPS con `WiFiClientSecure` + `setInsecure()` (*decisión mía*; atajo: no valida el certificado, aceptable para la práctica).
- Agrega `rssi = WiFi.RSSI()` al JSON. Corrige nombres: `MQ2_PIN` (antes `MQ135_PIN`) y mensaje de error "DHT11".
Las credenciales van en `secrets.h` (ignorado por git) con un `secrets.example.h` de plantilla.

### 3. App Flutter (`INTEGRADOR/`, paquete `estacion_climatica`)
Plataformas: Android y web. Dependencia nueva: solo `supabase_flutter`.

Pantalla principal con dos pestañas:

```
┌ ESP32_Estacion_Climatica      ● Online ┐
│ [Dashboard] [Alarmas (1)]              │
│ ┌─────────┐ ┌─────────┐                │
│ │ 24.1 °C │ │  37 %   │                │
│ │Temperat.│ │ Humedad │                │
│ └─────────┘ └─────────┘                │
│ ┌─────────┐ ┌─────────┐                │
│ │  1830   │ │ -58 dBm │                │
│ │Cal. aire│ │Señal WiFi│               │
│ └─────────┘ └─────────┘                │
│ Alarma local: APAGADA · hace 3 s       │
└────────────────────────────────────────┘
```

- **Dashboard:** última fila de `telemetria` al abrir + stream Realtime de inserts. Tarjeta de temperatura en rojo si > 30. "Online" si la última lectura tiene menos de 15 s (≈3 ciclos), si no "Offline" (*decisión mía*).
- **Alarmas:** lista desde `alarmas` (más reciente primero) con tipo, severidad, estado, temperatura y hora; botones **Reconocer** (`ACTIVE_UNACK → ACTIVE_ACK`) y **Borrar** (`ACTIVE_* → CLEARED_*`). Contador de activas en la pestaña.
- **Aviso:** al llegar por Realtime una alarma nueva (`INSERT`), banner/SnackBar rojo "High Temperature Alarm – 31.2 °C" en cualquier pestaña.
- Config en `lib/config.dart` (URL + publishable key, como PERSISTENCIA).

### 4. Documentación (`DEMO.md`)
Pasos: correr `supabase.sql`, cargar firmware, correr app en web y Android, y **prueba de alarma sin calentar el sensor**: insertar una fila con `temperature = 35` desde SQL Editor o con `curl`. Así queda la evidencia que faltó en el reporte original (> 30 °C).

## Qué queda al constructor
- Estructura interna de archivos Dart, estilo visual y colores.
- Cómo manejar reconexión de Realtime (lo que ofrece `supabase_flutter` por defecto basta).
- Aplicar el SQL vía SQL Editor o vía la conexión Supabase disponible, si el proyecto es accesible.
