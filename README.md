# Reinos

Estrategia en tiempo real para Android, estilo Age of Empires, **100 % en español, sin internet y sin coste**.
Hecho con Godot 4.4.1 (gratuito). Todo el arte y los sonidos se generan por código: no hay ficheros de imagen ni de música.

- 1 jugador contra 1–3 IAs (aliadas entre sí por defecto, o todos contra todos).
- Mapa plano de 128×128, 192×192 o 256×256 casillas con continentes, islas y mar, cordilleras infranqueables y climas (nieve, templado, desierto).
- Aspecto: terreno dibujado por shader (agua con olas y espuma, relieve, montañas), ciclo día/noche, nubes, lluvia ocasional, árboles por bioma, aldeanos animados y poblados a escala del mapa (el centro urbano es un ayuntamiento con campanario, no un castillo).
- Edades Oscura y Feudal, economía (comida, madera, oro), granjas, cuartel, arquería, establo, murallas, puertas y torres.
- Sin campaña, sin música. Solo sonidos de acción y ambiente.
- Perfiles de batería: Ahorro (20 fps), Normal (30 fps), Alta (60 fps, resolución nativa).

## Qué NO está comprobado (léelo antes de nada)

| Cosa | Estado |
|---|---|
| Juego completo | Probado en un PC sin tarjeta gráfica (renderizado por software) con toques simulados. **No probado en un móvil real.** |
| APK | **No se ha podido compilar aquí** (sin acceso al SDK de Android). Abajo tienes dos formas de generarlo. |
| Sonido | Sintetizado por código; **nadie lo ha escuchado**. Puede sonar mal. Se regenera con `tools/gen_audio.py`. |
| Batería y rendimiento en móvil | **Sin medir.** Las medidas de fps son de PC con GPU por software. Los shaders de terreno/nubes/lluvia duplican el coste por fotograma en ese entorno; el perfil Ahorro usa una variante más ligera del terreno. Cuenta con **menos autonomía** que antes. |
| Islas | Son decorativas: no hay barcos, así que no se puede llegar a ellas. Las montañas bloquean el paso; el generador comprueba que todas las bases quedan conectadas por tierra. |
| Guardar/cargar partida | No existe. |
| IA | Sube de edad, construye economía, ejército y torres, y ataca. **No usa murallas ni puertas.** |

## Abrirlo en el PC

1. Descarga Godot 4.4.1 estándar (no hace falta la versión .NET): <https://godotengine.org/download/archive/4.4.1-stable/>
2. Importa esta carpeta (`project.godot`) y pulsa ▶. Se maneja con ratón (el clic emula el toque).

## Generar el APK

### Opción A: GitHub Actions (no instalas nada) — flujo sin probar

1. Crea un repositorio en GitHub y sube esta carpeta (incluye `.github/workflows/apk.yml`).
2. Pestaña **Actions → APK Android → Run workflow**.
3. Al terminar, descarga el *artifact* `reinos-apk`, descomprímelo y copia `reinos.apk` al móvil.

El flujo instala Godot, las plantillas de exportación y los componentes del SDK, crea una clave de depuración y exporta. Está escrito sin poder ejecutarlo: si falla, el error del paso que se pone en rojo dice qué falta.

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
- Aldeanos → **Construir** → edificio → mueve el fantasma → **Construir**. **Defensas** agrupa murallas (arrastra para trazar la línea, o toca inicio y final), puertas (sobre un tramo de muralla) y torres.
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
  hud.gd        interfaz táctil; ui_kit.gd botones; menu.gd menú
  settings.gd   perfiles de batería y calidad (se guardan en user://ajustes.cfg)
data/es.json    todos los textos en español (para traducir: otro JSON y cambiar Lang.FILE)
audio/*.wav     sonidos generados por tools/gen_audio.py
tools/          pruebas automáticas y utilidades (no se exportan al APK)
```

## Pruebas automáticas

Con el ejecutable de Godot 4.4.1 (`$GODOT`):

```
# lógica pura, sin pantalla
$GODOT --headless --path . --script res://tools/sim_test.gd -- seed=3 min=14 n=3 size=192
$GODOT --headless --path . --script res://tools/wall_test.gd

# interfaz con toques simulados (necesita xvfb o pantalla)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/ui_test2.tscn --rendering-driver opengl3
# también ui_test3, ui_test4 (granjas, edades...), ui_test5 (murallas y puertas), ui_test6 (recolectar oro), battery_test

# utilidades: capturas del mundo (world_shot, en el minimapa con at=minimap), estadísticas de mapa (map_stats),
# alcance de recursos desde cada base (reach_dbg), depuración de la economía de la IA (ai_food_dbg)
```

## Licencias

Godot Engine: MIT. El código de este proyecto lo escribió Claude (Anthropic) a petición del autor; no incluye assets de terceros.
