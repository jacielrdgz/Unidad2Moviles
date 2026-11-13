# Demo Offline-First · Sensor IoT (Flutter + SQLite + Supabase)

## Preparación (una sola vez)
1. Supabase > **SQL Editor** > pegar `supabase.sql` > **Run**.
2. `flutter pub get`
3. Correr:
   - **Windows (navegador)**: `flutter run -d web-server --release --web-port 8080` y abrir
     http://localhost:8080 en Chrome. Usa siempre el puerto 8080: la BD SQLite (WASM) vive en
     IndexedDB de ese origen, y si cambias de puerto empieza vacía.
   - Android: `flutter run`.
   - `flutter run -d windows` compila, pero Smart App Control de Windows bloquea el .exe sin firma.

## Prueba en laboratorio (Módulo 4.3)
1. Activar **Modo Avión**. Hay tres formas:
   - El botón ✈ de la barra superior: simula el modo avión sin cortar tu internet.
   - El Modo avión real de Windows o apagar el WiFi.
   - En Chrome: F12 > Network > "Offline".

   El chip cambia a **Modo avión** / **Sin conexión**.
2. Pulsar **x5**: se generan 5 lecturas. Cada una muestra el icono de nube gris (pendiente).
3. Cerrar y volver a abrir la app (en web: recargar la pestaña con F5): las 5 lecturas siguen ahí, porque están en SQLite.
4. Desactivar Modo Avión: sin tocar nada, la app sincroniza sola y los iconos pasan a verde.
5. En Supabase > Table Editor > `lecturas` aparecen exactamente 5 filas, sin duplicados.

## Demo de conflicto (Last-Write-Wins)
1. Con conexión, generar una lectura y esperar a que esté verde.
2. Activar Modo Avión y editar la lectura en la app: nota "desde el celular".
3. En Supabase, editar la misma fila: nota "desde la nube". El trigger pone `updated_at = now()`.
4. Quitar Modo Avión. Gana la edición con el `updated_at` más reciente (la de la nube, porque se hizo después).
   Si se repite con el orden inverso, gana la del celular.

## Arquitectura (para la sustentación)
| Archivo | Rol |
|---|---|
| `lib/lectura.dart` | Modelo. `id` UUID generado en el dispositivo, `updated_at` para LWW, `synced` solo local. |
| `lib/local_db.dart` | SQLite: fuente de verdad. `aplicarRemoto` = LWW local. |
| `lib/sync_service.dart` | Escucha la red, sube pendientes, baja cambios, candado anti-concurrencia. |
| `supabase.sql` | Tabla, trigger LWW del servidor, RLS para la key pública. |

**Offline-First.** La UI solo lee y escribe SQLite. Escribir nunca depende de la red, así que no hay
congelamientos ni crashes en Modo Avión. La nube es una réplica que se pone al día cuando hay red.

**Sin duplicados.** El `id` es un UUID que se crea en el teléfono, antes de que exista conexión. Al subir se
usa `upsert(onConflict: 'id')`: si una subida se corta y se reintenta, la fila ya existe y solo se
actualiza, nunca se inserta dos veces.

**Last-Write-Wins.** Cada cambio pone `updated_at = ahora`. Cuando dos versiones chocan, gana la de
marca más reciente:
- Al subir, lo resuelve el servidor: el trigger `lecturas_lww` rechaza una versión más vieja que la guardada.
- Al bajar, lo resuelve el dispositivo: `aplicarRemoto` solo reemplaza si la nube es más nueva.

Limitación a defender: depende de que los relojes estén razonablemente sincronizados. Además, la edición
perdedora se descarta completa; no se mezclan campos.

**Subprocesos / concurrencia.**
- Todo es asíncrono (`async/await`): el hilo de UI nunca se bloquea con red ni disco.
- El flag `_syncing` impide dos sincronizaciones a la vez, aunque coincidan la reconexión, el timer y una lectura nueva.
- `marcarSincronizado` solo marca si `updated_at` no cambió mientras se subía: una edición
  hecha durante la subida no se pierde.
- `aplicarRemoto` corre en una transacción SQLite (lectura y escritura atómicas).

**Disparadores de sync.** Reconexión (`connectivity_plus`), cada 15 s si hay red (por si hay WiFi
sin internet) y tras cada lectura o edición. Nunca hace falta un botón.

## Tests
`flutter test` cubre: LWW (gana la nube más nueva, gana la local más nueva), que no se pierda una
edición concurrente, y que el timestamp se conserve en el viaje a la nube.
