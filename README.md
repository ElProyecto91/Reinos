# Reinos

Estrategia en tiempo real para Android, estilo Age of Empires, **100 % en español, sin internet y sin coste**.
Hecho con Godot 4.4.1 (gratuito). Todo el arte y los sonidos se generan por código: no hay imágenes dibujadas a mano ni música. (Las hojas de unidades se «hornean» una vez con `tools/bake_units.gd` a `art/units/*.png` para que el juego arranque rápido; ver «Arte».)

- 1 jugador contra 1–3 IAs (aliadas entre sí por defecto, o todos contra todos).
- Mapa plano de 128×128, 192×192 o 256×256 casillas con continentes, islas y mar, cordilleras infranqueables y climas (nieve, templado, desierto).
- Aspecto: terreno dibujado por shader (agua con olas y espuma, relieve, montañas), ciclo día/noche, nubes, lluvia ocasional, árboles por bioma, poblados a escala del mapa (el centro urbano es un ayuntamiento con campanario, no un castillo). Las personas son figuras articuladas con animación de caminar y de oficio (talar, picar, cultivar, construir, golpear, apuntar) y tres capas para teñir el uniforme con el color del equipo.
- Edades Oscura y Feudal, economía (comida, madera, oro), granjas, cuartel, arquería, establo, taller de asedio, murallas, puertas y torres.
- Soldados: piquero (Edad Oscura) y, en Feudal, arquero, jinete, espadachín (vence a piqueros y arietes), ballestero (daño alto, cadencia lenta, bueno contra caballería), explorador (rápido, ve lejos), caballero (caballería pesada) y ariete (asedio: casi inmune a flechas y torres, destroza edificios; se hace en el taller). Hay tabla de ventajas entre tipos (`Defs.BONUS`).
- **Puerto y flota:** el puerto se construye en la orilla (la casilla de salida al agua se comprueba). Entrena barco de pesca (recoge los peces del mar y los lleva al puerto) y barco de transporte (8 pasajeros) desde la Edad Oscura, y galera de guerra y galeón con cañones en Feudal. Embarcar: con soldados/aldeanos seleccionados toca el transporte junto a la orilla. Desembarcar: selecciona el transporte y toca tierra (o pulsa **Desembarcar**). Los barcos se hunden con su carga.
- Sin campaña, sin música. Solo sonidos de acción y ambiente.
- Perfiles de batería: Ahorro (20 fps), Normal (30 fps), Alta (60 fps, resolución nativa).

## Qué NO está comprobado (léelo antes de nada)

| Cosa | Estado |
|---|---|
| Juego completo | Probado en un PC sin tarjeta gráfica (renderizado por software) con toques simulados. **No probado en un móvil real.** |
| APK | Se compila en GitHub Actions (no aquí) y, con la clave de firma configurada, se publica en *Releases*. **Sin probar en un móvil real.** Ver «Seguridad». |
| Sonido | Sintetizado por código; **nadie lo ha escuchado**. Puede sonar mal. Se regenera con `tools/gen_audio.py`. |
| Batería y rendimiento en móvil | **Sin medir.** Las medidas de fps son de PC con GPU por software. Los shaders de terreno/nubes/lluvia duplican el coste por fotograma en ese entorno; el perfil Ahorro usa una variante más ligera del terreno. Cuenta con **menos autonomía** que antes. |
| Islas y barcos | Se llega a las islas con transportes. Las montañas bloquean el paso; el generador comprueba que todas las bases quedan conectadas por tierra. Barcos, pesca, embarque y combate naval están probados con pruebas automáticas y toques simulados, **no en un móvil**. |
| Guardar/cargar partida | No existe. |
| IA | Sube de edad, construye economía, ejército, torres, taller (con arietes), puerto y barcos de pesca, y ataca por tierra. **No usa murallas ni puertas, y no invade por mar**: sus galeras defienden y los barcos hostiles que se acercan los ataca, pero no desembarca tropas. |
| Rendimiento del arte nuevo | Las figuras nuevas son más detalladas que las anteriores. En el PC de pruebas (sin GPU) un fotograma con muchas unidades cuesta ~10-15 % más que antes. Las texturas de unidades ocupan unos **39 MB** como máximo (se cargan al hacer falta). Sin medir en móvil. |

## Seguridad

Qué se ha hecho y qué NO se puede prometer («100 % segura» no existe):

- **Permisos del APK:** solo `VIBRATE` e `INTERNET`. Internet se usa únicamente para el aviso de versión nueva (se desactiva en el menú, «Actualizaciones: No») y no envía ningún dato tuyo. No pide ubicación, contactos, cámara, micrófono ni almacenamiento. El flujo de GitHub **falla** si el APK pide cualquier otro permiso o es depurable.
- **Datos:** solo `ajustes.cfg` en el almacenamiento privado de la app (perfil, auto-pausa, avisos). No hay cuentas, ni publicidad, ni estadísticas. El juego no ejecuta nada que venga de fuera.
- **Firma:** el APK es *release* (no depurable) y va firmado con una clave privada que **solo existe en los secretos de GitHub** (`ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`). Su huella SHA-256 está en `.github/signing-cert.sha256` y en las notas de cada release; el flujo se niega a publicar si la huella no coincide.
- **Actualizaciones:** el juego consulta (HTTPS) la última release; si hay una nueva, avisa en el menú. Al tocar el aviso abre en el navegador una dirección fija del código. La instala Android, que **solo acepta un APK firmado con la misma clave** que el instalado: uno manipulado no puede sustituirlo. Android no permite instalar sin que toques «Instalar»; esto no se puede automatizar más sin permisos peores.
- **Cadena de compilación:** Godot y sus plantillas se verifican con SHA-512 fijados, las acciones de terceros van fijadas por commit y el token del flujo es de solo lectura salvo para publicar la release.
- **Verificar tú mismo un APK:** `sha256sum -c reinos.apk.sha256` y `apksigner verify --print-certs reinos.apk` (la huella debe ser la de `.github/signing-cert.sha256`).

Lo que NO está cubierto:

- **Play Protect** seguirá avisando de «app desconocida» mientras no esté en Google Play (cuesta 25 USD una vez; fuera del objetivo de coste 0).
- Todo depende de **tu cuenta de GitHub**: activa la verificación en dos pasos y no compartas tokens. Quien controle el repositorio controla las actualizaciones.
- Si pierdes los secretos de firma habrá que crear una clave nueva y **desinstalar el juego una vez** (sin pérdida de partidas: no existen).
- El historial de git contiene una clave de depuración antigua, ya descartada y sin uso.

### Configurar la firma (una sola vez)

1. Genera la clave en tu ordenador (hace falta Java): `keytool -genkeypair -alias reinos -keyalg RSA -keysize 4096 -sigalg SHA256withRSA -validity 10000 -keystore reinos-release.p12 -storetype PKCS12`
2. GitHub → repositorio → Settings → Secrets and variables → Actions → New repository secret: `ANDROID_KEYSTORE_PASSWORD` (la contraseña, sin espacios) y `ANDROID_KEYSTORE_B64` (`base64 -w0 reinos-release.p12`). Pega solo el valor: el flujo usa únicamente la primera palabra de la primera línea de cada secreto y, si la clave no abre, falla con un mensaje claro (no cae en la clave desechable).
3. Escribe la huella (`keytool -list -v -keystore reinos-release.p12`, la línea SHA256, en minúsculas y sin dos puntos) en `.github/signing-cert.sha256`.
4. Guarda el `.p12` y la contraseña en un gestor de contraseñas; nunca en el repositorio.

## Abrirlo en el PC

1. Descarga Godot 4.4.1 estándar (no hace falta la versión .NET): <https://godotengine.org/download/archive/4.4.1-stable/>
2. Importa esta carpeta (`project.godot`) y pulsa ▶. Se maneja con ratón (el clic emula el toque).

## Generar el APK

### Opción A: GitHub Actions (no instalas nada)

1. Sube esta carpeta a GitHub (incluye `.github/workflows/apk.yml`) y configura la firma (ver «Seguridad»).
2. Cada subida a `main` compila y, si todo está correcto, publica una *Release* `build-N` con `reinos.apk` y `reinos.apk.sha256`. También puedes lanzarlo a mano: **Actions → APK Android → Run workflow**.
3. Descarga `reinos.apk` de **Releases → Latest** (si el repositorio es público, desde el navegador del móvil sin iniciar sesión) e instálalo. Las actualizaciones se instalan encima sin desinstalar.

Sin los secretos de firma el flujo compila igualmente, pero con una clave desechable: el artefacto se llama `reinos-apk-SIN-CLAVE-FIJA`, no se publica y no se podrá actualizar encima de otro.

### Opción B: en tu ordenador

1. Instala **Android Studio** (trae el SDK) o solo las *command-line tools*, y un **JDK 17**.
2. En el SDK instala: `platform-tools`, `build-tools;35.0.1` (o 34.0.0) y `platforms;android-35`.
3. En Godot: *Editor → Gestionar plantillas de exportación → Descargar* (4.4.1).
4. *Editor → Ajustes del editor → Exportar → Android*: ruta del SDK, ruta del JDK y la clave de depuración (Godot puede crearla con `keytool`).
5. *Proyecto → Exportar → Android* (ya está configurado en `export_presets.cfg`: arm64, sin Gradle, horizontal) → *Exportar proyecto*.
6. Activa la instalación de orígenes desconocidos en el móvil y copia el `.apk`.

Para publicar en Google Play necesitarías un `.aab` firmado con tu propia clave (y una cuenta de desarrollador, que tiene coste). Eso queda fuera del «coste 0».

## Controles (también en «Cómo jugar» dentro del juego)

- Un dedo: tocar selecciona o da órdenes; arrastrar mueve la cámara. Mantener pulsado y arrastrar: recuadro de selección.
- Dos dedos: zoom. Minimapa (abajo a la izquierda): toca para saltar.
- Aldeanos → **Construir** → edificio → mueve el fantasma → **Construir**. **Militares** agrupa cuartel, arquería, establo y taller; **Defensas** agrupa murallas (arrastra para trazar la línea, o toca inicio y final), puertas (sobre un tramo de muralla) y torres. El **Puerto** va en la orilla (el fantasma se pone verde si hay mar junto a él).
- Barcos de pesca: tócalos y toca un banco de peces (hay que haberlo explorado navegando cerca). Con el puerto seleccionado, **Reunión** sobre un banco de peces hace que los barcos nuevos pesquen solos.
- Pausa (☰ arriba a la derecha): velocidad ×1/×2/×3, sonido, auto-pausa, perfil de rendimiento.

## Batería

Lo que hace el juego para gastar poco (los números son decisiones de diseño, no mediciones):

- Límite de fps por perfil (20/30/60) y, en Ahorro y Normal, dibuja a ~720p y escala a la pantalla.
- Menú, pausa y fin de partida: el motor baja a 15 fps y solo redibuja si cambia algo; el ambiente sonoro se detiene.
- La pantalla solo se mantiene encendida mientras la partida corre sin pausa.
- Auto-pausa tras 90 s (Ahorro), 180 s (Normal) o 300 s (Alta) sin tocar la pantalla; se puede desactivar.
- Panel de recursos, niebla de guerra y minimapa se refrescan menos veces por segundo en los perfiles de ahorro.
- La simulación va a 10 pasos por segundo con interpolación; los sonidos van a 22 kHz mono.
- El realismo visual (shaders, día/noche, lluvia) se mantiene en todos los perfiles; Ahorro sólo simplifica el relieve del terreno. El agua se queda quieta en pausa.

Lo que no se puede controlar desde el juego: el brillo y el tiempo de pantalla del móvil. Es, con diferencia, lo que más gasta.

## Estructura

```
scripts/        código del juego (GDScript)
  sim.gd        simulación pura (sin dibujo): unidades, edificios, combate, murallas
  ai_player.gd  IA
  game.gd       cámara, entrada táctil, bucle; renderer.gd / art.gd / painter.gd dibujan
  art_units.gd  figuras de personas (esqueleto, herramientas, cascos); art_mounts.gd caballos y ariete; art_ships.gd barcos
  art_buildings.gd edificios por capas (base, equipo)
  hud.gd        interfaz táctil; ui_kit.gd botones; menu.gd menú
  settings.gd   perfiles de batería y calidad (se guardan en user://ajustes.cfg)
data/es.json    todos los textos en español (para traducir: otro JSON y cambiar Lang.FILE)
audio/*.wav     sonidos generados por tools/gen_audio.py
art/units/      hojas de unidades horneadas por tools/bake_units.gd (3 capas: fondo, equipo, primer plano)
tools/          pruebas automáticas y utilidades (no se exportan al APK)
```

## Pruebas automáticas

Con el ejecutable de Godot 4.4.1 (`$GODOT`):

```
# lógica pura, sin pantalla
$GODOT --headless --path . --script res://tools/sim_test.gd -- seed=3 min=14 n=3 size=192
$GODOT --headless --path . --script res://tools/wall_test.gd

# puerto, pesca, transporte, desembarco y combate naval (lógica pura; seeds 1, 2, 3, 5, 8 probadas)
$GODOT --headless --path . --script res://tools/naval_test.gd -- seed=1

# interfaz con toques simulados (necesita xvfb o pantalla)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/ui_test2.tscn --rendering-driver opengl3
# también ui_test3, ui_test4 (granjas, edades...), ui_test5 (murallas y puertas), ui_test6 (recolectar oro),
# ui_test7 (puerto: construir, entrenar barcos, pescar, embarcar, desembarcar, atacar), battery_test, perf_test

# aviso de actualización (necesita el servidor de pruebas en marcha)
python3 tools/mock_release_server.py 18765 &
$GODOT --headless --path . --script res://tools/updater_test.gd -- port=18765

# utilidades: capturas del mundo (world_shot, en el minimapa con at=minimap), estadísticas de mapa (map_stats),
# alcance de recursos desde cada base (reach_dbg), depuración de la economía de la IA (ai_food_dbg)
```

## Arte

Las figuras y edificios se dibujan por código (`art_units.gd`, `art_mounts.gd`, `art_ships.gd`, `art_buildings.gd`) con un rasterizador propio (`painter.gd`). Para no pagar ~3 s de arranque, las hojas de unidades están horneadas en `art/units/*.png`; si no existen se generan al vuelo (más lento). **Si cambias el dibujo de una unidad, vuelve a hornear y a importar:**

```
$GODOT --headless --path . --script res://tools/bake_units.gd
$GODOT --headless --path . --import
# ver cada unidad: tools/dump_units.gd → /tmp/units_<tipo>.png; captura en juego: tools/units_shot.tscn
```

## Licencias

Godot Engine: MIT. El código de este proyecto lo escribió Claude (Anthropic) a petición del autor; no incluye assets de terceros.
