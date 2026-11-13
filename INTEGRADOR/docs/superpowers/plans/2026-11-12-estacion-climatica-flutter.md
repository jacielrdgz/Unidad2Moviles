# Estación climática ESP32 + Supabase + Flutter — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replicar la Práctica 2.3 cambiando ThingsBoard por Supabase (motor de reglas en un trigger) y una app Flutter Android + web.

**Architecture:** El ESP32 hace POST HTTPS a `/rest/v1/telemetria`. Un trigger `AFTER INSERT` crea o actualiza la alarma en `alarmas` si `temperature > 30`. La app lee ambas tablas con `.stream()` de `supabase_flutter` (Realtime) y muestra Dashboard + Alarmas.

**Tech Stack:** Flutter 3.47.5 / Dart `^3.13.4`, `supabase_flutter: ^2.18.3`, Postgres (Supabase), Arduino ESP32 + `DHT sensor library` + `ArduinoJson 7`.

**Spec:** `INTEGRADOR/docs/superpowers/specs/2026-11-12-estacion-climatica-flutter-design.md`

## Global Constraints
- Todo vive en `PROYECTOS FLUTTER/INTEGRADOR/`. Paquete Dart: `estacion_climatica`. Plataformas: `android,web`.
- Umbral: `30.0`, comparación estricta `>` (30.0 exacto NO es alarma), en firmware y en trigger.
- Dispositivo: `'ESP32_Estacion_Climatica'`. Tipo de alarma: `'High Temperature Alarm'`. Severidad: `'CRITICAL'`.
- Estados de alarma: `ACTIVE_UNACK`, `ACTIVE_ACK`, `CLEARED_UNACK`, `CLEARED_ACK`.
- Online = última lectura con antigüedad `< 15 s`.
- Solo la publishable key. Nunca la `service_role`/secret, ni en app ni en firmware.
- Reusar el proyecto Supabase de `PERSISTENCIA/lib/config.dart` (copiar URL + key). No tocar la tabla `lecturas`.
- Web: `flutter run -d web-server --web-port 8080`.
- Git: rama `feat/estacion-climatica`. Commit solo con OK del usuario. `esp32/**/secrets.h` en `.gitignore`.

## Review Focus
1. **Alarma deduplicada llega como UPDATE, no INSERT**: la lista debe reflejar la nueva temperatura y el banner NO debe repetirse. Test: `nuevasAlarmas` ignora ids ya vistos (Task 2).
2. **Base sin lecturas todavía**: Dashboard muestra "Sin datos" y "Offline", sin crash. Test widget (Task 3).
3. **Fila insertada a mano sin `rssi`/`air_quality`** (prueba con SQL/curl): los modelos aceptan null y la UI muestra "—". Test de modelo (Task 2).
4. **El dispositivo deja de enviar**: el chip debe pasar a Offline sin datos nuevos (refresco con `Timer` de 1 s). Test widget con reloj inyectado (Task 3).
5. **Temperatura exactamente 30.0** no crea alarma ni pinta rojo. Tests en SQL (Task 1) y modelo (Task 2).

---

### Task 1: Base de datos y motor de reglas (Supabase)

**Files:**
- Create: `INTEGRADOR/supabase.sql`
- Test: `INTEGRADOR/supabase_test.sql`

**Interfaces:**
- Produces: tablas `public.telemetria(id bigserial, device text, temperature float8 not null, humidity float8 not null, air_quality int null, local_alarm_status bool not null default false, rssi int null, created_at timestamptz default now())` y `public.alarmas(id bigserial, device text, type text, severity text, status text check in los 4 estados, temperature float8, created_at, updated_at, ack_at null, cleared_at null)`, ambas en `supabase_realtime`. Función `public.regla_temperatura()`, trigger `regla_temperatura` en `telemetria`.

- [ ] **Step 1: Escribir `supabase_test.sql`** dentro de `begin; … rollback;` con `do $$ … assert … $$`:
  - insert `temperature=25` → `count(*) from alarmas where device='TEST'` = 0
  - insert `temperature=30.0` → sigue 0
  - insert `temperature=35` → 1 fila, `status='ACTIVE_UNACK'`, `temperature=35`
  - insert `temperature=36` → sigue 1 fila, `temperature=36`, `updated_at >= created_at`
  - `update alarmas set status='CLEARED_UNACK'`; insert `temperature=35` → 2 filas
  - Usar `device='TEST'` en todos los inserts.
- [ ] **Step 2: Correr el test** (Supabase MCP `execute_sql` si el proyecto es accesible; si no, SQL Editor). Expected: FAIL, `relation "telemetria" does not exist`.
- [ ] **Step 3: Escribir `supabase.sql`** idempotente (`create table if not exists`, `create or replace function`, `drop trigger/policy if exists`). Trigger `after insert … for each row`. Lógica: si `new.temperature > 30`, buscar alarma del mismo `device` y `type` con `status like 'ACTIVE%'`; si existe, `update temperature, updated_at=now()`; si no, `insert` `ACTIVE_UNACK`. RLS: `anon` insert+select en `telemetria`; select+update en `alarmas`. Publicación: agregar cada tabla a `supabase_realtime` dentro de un `do` que revise `pg_publication_tables` para no fallar al re-ejecutar. Comentarios que mapeen a Save Timeseries / Script Filter / Create Alarm.
- [ ] **Step 4: Aplicar `supabase.sql` dos veces y correr el test.** Expected: sin errores, todas las aserciones pasan.
- [ ] **Step 5: Commit** `feat(integrador): esquema Supabase y regla de temperatura`

### Task 2: Proyecto Flutter, modelos y lógica pura

**Files:**
- Create (via `flutter create --project-name estacion_climatica --platforms android,web .` en `INTEGRADOR/`): estructura base
- Create: `lib/config.dart` (copia de PERSISTENCIA), `lib/modelos.dart`
- Test: `test/modelos_test.dart`

**Interfaces:**
- Produces (en `lib/modelos.dart`):
  - `const double umbralTemp = 30.0; const Duration ventanaOnline = Duration(seconds: 15);`
  - `class Telemetria { int id; double temperature; double humidity; int? airQuality; bool localAlarm; int? rssi; DateTime createdAt; factory Telemetria.fromMap(Map<String,dynamic>); bool get critica; }` (`critica` = `temperature > umbralTemp`)
  - `bool estaOnline(DateTime? ultima, DateTime ahora)`
  - `class Alarma { int id; String type; String severity; String status; double temperature; DateTime createdAt; DateTime updatedAt; factory Alarma.fromMap(Map<String,dynamic>); bool get activa; bool get reconocida; }`
  - `String? estadoAlReconocer(String status)` → `ACTIVE_UNACK→ACTIVE_ACK`, `CLEARED_UNACK→CLEARED_ACK`, otro → `null`
  - `String? estadoAlBorrar(String status)` → `ACTIVE_UNACK→CLEARED_UNACK`, `ACTIVE_ACK→CLEARED_ACK`, otro → `null`
  - `List<Alarma> nuevasAlarmas(Set<int> vistas, List<Alarma> actuales)` → las de id no visto

- [ ] **Step 1: Crear proyecto y agregar dependencia.** `flutter create …` y `flutter pub add supabase_flutter:^2.18.3`. Expected: `flutter analyze` sin errores.
- [ ] **Step 2: Escribir `test/modelos_test.dart`:**
  - `fromMap` con `{'id':1,'temperature':24.1,'humidity':37,'air_quality':1830,'local_alarm_status':false,'rssi':-58,'created_at':'2026-11-12T10:00:00Z'}` → `humidity == 37.0` (int→double), `airQuality == 1830`
  - `fromMap` sin `air_quality` ni `rssi` → ambos `null`
  - `critica`: 30.0 → false; 30.1 → true
  - `estaOnline(null, t)` false; 14 s → true; 15 s → false
  - `estadoAlReconocer('ACTIVE_UNACK') == 'ACTIVE_ACK'`; `estadoAlReconocer('ACTIVE_ACK') == null`
  - `estadoAlBorrar('ACTIVE_ACK') == 'CLEARED_ACK'`; `estadoAlBorrar('CLEARED_ACK') == null`
  - `nuevasAlarmas({1}, [a1, a2])` → `[a2]`; `nuevasAlarmas({1,2}, [a1 con temperatura cambiada, a2])` → `[]`
- [ ] **Step 3: Correr** `flutter test test/modelos_test.dart`. Expected: FAIL (no compila, faltan símbolos).
- [ ] **Step 4: Implementar `lib/modelos.dart`** con las firmas de arriba. Números con `(m['x'] as num).toDouble()`.
- [ ] **Step 5: Correr** `flutter test`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(integrador): app Flutter base y modelos`

### Task 3: Repositorio Supabase y UI (Dashboard, Alarmas, aviso)

**Files:**
- Create: `lib/repo.dart`, `lib/dashboard.dart`, `lib/alarmas.dart`
- Modify: `lib/main.dart` (reemplazar el contador de `flutter create`)
- Test: `test/ui_test.dart`

**Interfaces:**
- Consumes: todo `lib/modelos.dart` (Task 2); tablas de Task 1.
- Produces:
  - `abstract class EstacionRepo { Stream<Telemetria?> ultimaLectura(); Stream<List<Alarma>> alarmas(); Future<void> cambiarEstado(int id, String status); }`
  - `class SupabaseRepo implements EstacionRepo` — `telemetria.stream(primaryKey:['id']).order('created_at').limit(1)` (tomar el último o `null`); `alarmas.stream(primaryKey:['id']).order('created_at', ascending:false)`; `cambiarEstado` hace `update({'status': s, 'ack_at'|'cleared_at': now})` según el estado destino.
  - `class HomePage extends StatefulWidget { HomePage({required EstacionRepo repo, DateTime Function() reloj = DateTime.now}) }` con `TabBar` "Dashboard" / "Alarmas (n activas)".
- `main.dart`: `Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)` y `HomePage(repo: SupabaseRepo())`.

- [ ] **Step 1: Escribir `test/ui_test.dart`** con un `FakeRepo` (StreamControllers):
  - Sin emisiones / `null` → aparece `'Sin datos'` y `'Offline'`
  - Emite lectura 24.1 / 37 / 1830 / -58 con `createdAt = reloj()` → textos `'24.1 °C'`, `'37 %'`, `'1830'`, `'-58 dBm'`, `'Online'`
  - Avanzar el reloj inyectado 16 s + `tester.pump(Duration(seconds: 1))` → `'Offline'`
  - Lectura 31.2 → la tarjeta de temperatura usa `Colors.red` (buscar por `Key('card-temp')`)
  - Emite `[a1]` (primera carga) → sin SnackBar; luego `[a2, a1]` → SnackBar con `'High Temperature Alarm – 31.2 °C'`; luego `[a2 con 33.0, a1]` → no aparece un segundo SnackBar
  - En Alarmas, tocar "Reconocer" de una `ACTIVE_UNACK` → `FakeRepo` recibe `cambiarEstado(id, 'ACTIVE_ACK')`; "Borrar" → `'CLEARED_UNACK'`; botones ocultos cuando `estadoAl…` da `null`
- [ ] **Step 2: Correr** `flutter test test/ui_test.dart`. Expected: FAIL (faltan clases).
- [ ] **Step 3: Implementar** `repo.dart`, `dashboard.dart` (grid de 4 tarjetas + chip Online/Offline + "Alarma local: ENCENDIDA/APAGADA · hace N s"; `Timer.periodic(1 s)` para refrescar), `alarmas.dart` (lista con tipo, severidad, estado, temperatura, hora; botones según `estadoAlReconocer/Borrar`), y `HomePage` con el aviso: la primera emisión de `alarmas()` llena `vistas` sin avisar; las siguientes usan `nuevasAlarmas`. Valores null se muestran `'—'`.
- [ ] **Step 4: Correr** `flutter test` y `flutter analyze`. Expected: PASS, `No issues found!`
- [ ] **Step 5: Verificación real (web):** `flutter run -d web-server --web-port 8080`, abrir http://localhost:8080. Insertar desde SQL Editor `insert into telemetria(temperature,humidity,air_quality,local_alarm_status,rssi) values (35,40,1800,true,-60);` Expected: el dashboard muestra 35.0 °C en rojo, aparece el aviso y la pestaña Alarmas muestra `(1)`.
- [ ] **Step 6: Android:** agregar `<uses-permission android:name="android.permission.INTERNET"/>` en `android/app/src/main/AndroidManifest.xml` y correr `flutter build apk --debug`. Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`.
- [ ] **Step 7: Commit** `feat(integrador): dashboard y alarmas en tiempo real`

### Task 4: Firmware ESP32

**Files:**
- Create: `INTEGRADOR/esp32/estacion_climatica/estacion_climatica.ino`, `INTEGRADOR/esp32/estacion_climatica/secrets.example.h`
- Modify: `INTEGRADOR/.gitignore` (agregar `esp32/**/secrets.h`)

**Interfaces:**
- Consumes: endpoint `POST {SUPABASE_URL}/rest/v1/telemetria` (Task 1). `secrets.h` define `WIFI_SSID`, `WIFI_PASS`, `SUPABASE_URL`, `SUPABASE_KEY`.

- [ ] **Step 1: Escribir el `.ino`** partiendo del código del reporte (páginas 8–9). Mantener pines, `TEMP_THRESHOLD = 30.0`, `triggerLocalAlarm`, reconexión Wi-Fi y `delay(4000)`. Cambios: `#include "secrets.h"`; `MQ2_PIN` en lugar de `MQ135_PIN`; mensaje `"[ERROR] Lectura de DHT11 fallida"`; `WiFiClientSecure client; client.setInsecure();` (comentario `// shortcut: no valida el certificado, usar setCACert si se publica`) y `http.begin(client, url)`; headers `apikey`, `Authorization: Bearer …`, `Content-Type: application/json`, `Prefer: return=minimal`; agregar `doc["rssi"] = WiFi.RSSI();`; el log imprime el código e indica éxito con `201`.
- [ ] **Step 2: Compilar.** Si existe `arduino-cli`: `arduino-cli compile --fqbn esp32:esp32:esp32 esp32/estacion_climatica` (con `secrets.h` copiado del ejemplo). Si no, Verificar en Arduino IDE (ESP32 Dev Module). Expected: compila sin errores.
- [ ] **Step 3: Prueba en hardware (usuario):** Monitor Serie 115200 → `[HTTP] POST Status Code: 201`, y la app web muestra las lecturas en vivo con el chip en Online.
- [ ] **Step 4: Commit** `feat(integrador): firmware ESP32 hacia Supabase`

### Task 5: DEMO.md

**Files:**
- Create: `INTEGRADOR/DEMO.md`

- [ ] **Step 1: Escribir DEMO.md** con el mismo estilo que `PERSISTENCIA/DEMO.md`: preparación (SQL, `secrets.h`, `flutter pub get`, web en 8080, Android con `flutter run`); tabla de equivalencias ThingsBoard → Supabase (Save Timeseries → insert en `telemetria`; Script Filter → `if new.temperature > 30`; Create Alarm → insert/update en `alarmas`; Dashboard → app); prueba de alarma sin calentar el sensor (el `insert` del Task 3 Step 5 y su equivalente `curl` con headers `apikey`/`Authorization` y la key como placeholder); Reconocer/Borrar; tabla de archivos.
- [ ] **Step 2: Seguir DEMO.md de cero en web.** Expected: cada paso funciona tal como está escrito.
- [ ] **Step 3: Commit** `docs(integrador): guía de demo`
