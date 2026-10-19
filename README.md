# Reinos

Estrategia en tiempo real para Android, estilo Age of Empires, **100 % en español, sin internet y sin coste**.
Hecho con Godot 4.4.1 (gratuito). Todo el arte y los sonidos se generan por código: no hay imágenes dibujadas a mano ni música. El mundo se ve en **perspectiva isométrica** (proyección 2:1 como Age of Empires II): edificios, árboles, unidades y barcos son modelos 3D hechos por código que se «hornean» una vez a sprites (`tools/iso`, ver «Arte»); la simulación sigue en un plano 2D.

- 1 jugador contra 1–3 IAs (aliadas entre sí por defecto, o todos contra todos).
- Mapa plano de 128×128, 192×192 o 256×256 casillas con continentes, islas y mar, cordilleras infranqueables y climas (nieve, templado, desierto).
- Aspecto: vista isométrica 2:1. Terreno dibujado por shader (agua con olas y espuma, relieve, montañas), ciclo día/noche, nubes, lluvia ocasional; árboles por bioma (robles, pinos, pinos nevados, robles de otoño, palmeras y acacias secas), rocas, pepitas de oro, arbustos de bayas y retoños; 16 tipos de edificio con modelos propios (el centro urbano es un ayuntamiento con campanario, no un castillo); 27 tipos de unidad y barco articulados (marcha de 4 fotogramas, ataque de 2-3, oficios del aldeano) y animales (ciervo, jabalí). Las sombras van horneadas y las partes de equipo se tiñen con el color del jugador mediante una máscara y un shader.
- Tres edades (Oscura, Feudal y de los Castillos), economía (comida, madera, oro y **piedra**), granjas, cuartel, arquería, establo, taller de asedio, monasterio, castillo, murallas, puertas y torres.
- Soldados: piquero (Edad Oscura) y, en Feudal, arquero, jinete, espadachín (vence a piqueros y arietes), ballestero (daño alto, cadencia lenta, bueno contra caballería), explorador (rápido, ve lejos), caballero (caballería pesada) y ariete (asedio: casi inmune a flechas y torres, destroza edificios; se hace en el taller). Hay tabla de ventajas entre tipos (`Defs.BONUS`).
- **Edad de los Castillos** (700 comida + 450 oro, 55 s; exige tener terminados **al menos 2 tipos distintos** de edificio militar: cuartel, arquería, establo o taller; +30 % de vida y daño en total frente a la Edad Oscura). Trae: **alabardero** (cuartel; el mejor contra caballería), **hostigador** (arquería; barato, tira jabalinas y vence a arqueros), **arquero a caballo** (arquería; rápido, dispara en movimiento), **catapulta** (taller; piedras que dañan en área a unidades y edificios), **monasterio** (3×3) con el **monje** (no ataca: cura a los aliados heridos que tiene cerca, hasta 3 a la vez) y el **castillo** (4×4, 4800 de vida, dispara a quien se acerca; entrena el **trabuquete**, que solo derriba edificios pero desde lejos). La tabla de contrarios está en `Defs.BONUS`: piquero/alabardero → caballería, espadachín → piquero y asedio, arquero → infantería, hostigador → arqueros, caballería → arqueros y monjes, ballestero → caballería.
- **8 civilizaciones** (build-20): Castellanos, Francos, Ingleses, Teutones, Vikingos, Bizantinos, Sarracenos y Mongoles. Eliges la tuya en el menú (o Aleatoria); cada IA rival recibe una al azar sin repetir. Cada una trae **bonificaciones pasivas** (vida, daño, velocidad, alcance, vista, costes, tiempos de entrenamiento, recolección, vida de edificios, población de las casas, coste de las edades), una **unidad única** que se entrena en el Castillo (conquistador con arcabuz, hachero lanzador, arquero de arco largo, caballero teutónico, berserker, catafracta, mameluco y mangudai) y una **habilidad activa** desde la Edad Feudal con recarga: buff de ejército (Castellanos, Ingleses, Teutones, Vikingos), recursos de golpe (Francos), fuego griego que se apunta en el mapa (Bizantinos), ver a todos los enemigos y correr más (Sarracenos) y tropas nuevas en el Centro urbano (Mongoles). Todo está en `scripts/civs.gd` como datos; los textos, en `data/es.json`; la pantalla de elección enseña las bonificaciones de cada una.
- **Mecánicas de la build-23** (todo en español y dentro de «Cómo jugar»): **piedra** como 4.º recurso (peñascos grises que se pican como el oro; hacen falta para torres, murallas, puertas y castillos); **caza** (ciervos y jabalíes que pasean por el mapa y dan mucha comida deprisa); **Mercado** (compra y vende 100 de comida, madera o piedra por oro; el precio sube al comprar, baja al vender y vuelve despacio a 100, con 25 % de comisión); **Herrería** (Edad Feudal) y **mejoras** (17: forja, flechas, corazas de infantería/arqueros/caballería en dos niveles; telar, arado, carretilla en el Centro; hacha, sierra, pico en el Almacén) que se investigan en la cola del edificio; **guarnición** (Centro 15, Torre 5, Castillo 20: los refugiados no reciben daño, se curan y los arqueros añaden flechas al edificio); **rebato** (botón de la campana: todos los aldeanos corren a refugiarse; los aldeanos heridos por un soldado enemigo huyen solos al refugio más cercano); **posturas** (agresiva, defensiva, mantener posición, pasiva) y **formaciones** (libre, línea con la infantería delante y los arqueros detrás, columna). La IA investiga mejoras, vende excedentes en el mercado, da el rebato cuando le atacan (Normal y Difícil) y marcha en línea (Normal y Difícil).
- **Plantar árboles y minas de oro** (build-24; en Construir → **Recursos**): «Plantar árbol» (12 de madera, como las granjas se repite tocando casillas) deja un retoño que a los 90 s es un árbol normal de 100 de madera; hasta 30 retoños a la vez por jugador, solo en hierba y con un hueco libre alrededor de los edificios. La **Mina de oro** (Edad Feudal, 80 de madera y 70 de piedra, hasta 3 a la vez) se construye como un edificio de 2×2 y, al terminar, se convierte en un filón de 400 de oro (una casilla; las otras tres quedan libres) y los constructores empiezan a picarlo. Cuando se agota queda hueco para otra. La IA no planta ni abre minas.
- **Puerto y flota:** el puerto se construye en la orilla (la casilla de salida al agua se comprueba). Entrena barco de pesca (recoge los peces del mar y los lleva al puerto) y barco de transporte (8 pasajeros) desde la Edad Oscura, y galera de guerra y galeón con cañones en Feudal. Embarcar: con soldados/aldeanos seleccionados toca el transporte junto a la orilla. Desembarcar: selecciona el transporte y toca tierra (o pulsa **Desembarcar**). Los barcos se hunden con su carga.
- **Explorar solo:** selecciona un explorador (o un jinete, o un barco) y pulsa **Explorar**: recorre el mapa por su cuenta, prefiere lo más cercano que aún no ha visto, evita los sitios donde ya le han herido (huye sin pelear) y vuelve al centro urbano (o al puerto) cuando termina. Los exploradores nuevos salen explorando si no les das un punto de reunión. Cualquier orden manual lo cancela. Lo explorado se sigue por una rejilla gruesa que mantiene la niebla (sin coste extra por fotograma).
- **Edificios más realistas** (todo horneado una vez al arrancar: coste de batería por fotograma cero): sillares con bisel, musgo e hiedra, tejas una a una con liquen, entramado con relieve, ventanas con dintel y jardineras, buhardillas, antorchas, matacanes y aspilleras en torres y murallas, sombra del alero sobre la pared.
- Sin campaña, sin música. Solo sonidos de acción y ambiente.
- Perfiles de batería: Ahorro (20 fps), Normal (30 fps), Alta (60 fps, resolución nativa).
- Se guarda sola: **Continuar partida** en el menú retoma donde la dejaste (una sola partida guardada). Población máxima 200.

## Qué NO está comprobado (léelo antes de nada)

| Cosa | Estado |
|---|---|
| Juego completo | Probado en un PC sin tarjeta gráfica (renderizado por software) con toques simulados. **No probado en un móvil real.** |
| APK | Se compila en GitHub Actions (no aquí) y, con la clave de firma configurada, se publica en *Releases*. **Sin probar en un móvil real.** Ver «Seguridad». |
| Sonido | Sintetizado por código; **nadie lo ha escuchado**. Puede sonar mal. Se regenera con `tools/gen_audio.py`. |
| Batería y rendimiento en móvil | **Sin medir con instrumentos en ningún móvil.** Único dato real: el autor jugó unas 3 h con la build-21 en el móvil con Spotify abierto y la batería bajó **~20 %** (estimación a ojo, una sola sesión, sin controlar brillo, perfil ni red). Se optimizó lo que se puede medir en un PC sin GPU (milisegundos de GDScript, llamadas de dibujo y fotogramas dibujados por segundo; ver «Batería»); cuánto baja el consumo real en tu Redmi Note 13 5G **no se sabe** hasta probarlo. Los shaders de terreno/nubes/lluvia siguen siendo el mayor coste de GPU; el perfil Ahorro usa una variante más ligera del terreno. |
| Islas y barcos | Se llega a las islas con transportes. Las montañas bloquean el paso; el generador comprueba que todas las bases quedan conectadas por tierra y, si el único paso estaba taponado por bosque o roca, talla un camino (antes ~16 % de los mapas dejaba a las bases aisladas y la IA no atacaba nunca; ahora 0 de 270 mapas probados, `tools/connect_test.gd`). Barcos, pesca, embarque y combate naval están probados con pruebas automáticas y toques simulados, **no en un móvil**. |
| Guardar/cargar partida | Una sola ranura (`user://partida.sav`). Se guarda sola cada ~90 s de juego, al pausar, al salir al menú y cuando Android manda la app a segundo plano; al terminar la partida se borra. Probado en PC: guardar → cargar → seguir da **exactamente** el mismo resultado que no haber guardado (también con barcos con pasajeros). **No probado en un móvil real**: los tiempos medidos (guardar ~15-30 ms, cargar ~0,1-0,3 s en PC) en el móvil serán varias veces mayores. Si Android mata la app a mitad de un autoguardado, queda la partida anterior (se escribe en un archivo temporal y se renombra). |
| IA | Economía con ratios que se ajustan a las existencias, amplía con más centros urbanos cuando la base se queda sin recursos, sube de edad, elige qué soldados entrenar según lo que ve del enemigo (tabla de contrarios `Defs.BONUS`: piqueros contra caballería, arqueros contra piqueros, espadachines contra piqueros y arietes…), ataca por oleadas que crecen, deja reserva para defender, hostiga aldeanos con jinetes y manda galeras a cazar barcos y puertos. Tres dificultades (Fácil/Normal/Difícil). **No usa murallas ni puertas, y no invade por mar** (sus galeras no desembarcan tropas). En Normal y Difícil sube a la Edad de los Castillos (economía grande y 2 tipos de edificio militar), reserva el coste del monasterio y del castillo antes de gastar en soldados (sin esa reserva, medido, no llegaba a construirlos nunca), y entrena alabarderos, hostigadores, arqueros a caballo, catapultas, monjes y trabuquetes con límites por dificultad. Medido (solo en PC, IA contra IA): la IA nueva gana a la anterior (congelada en `tools/ai_legacy.gd`) desde los dos asientos en los mapas de semilla 3 y 8 (4 de 4 partidas, 15-24 min); en Difícil el monasterio sale ~2 min después de subir de edad y el castillo ~3-4 min después (mapas de semilla 3, 8 y 11). No se ha probado con más mapas ni contra una persona. **Ritmo de la IA (build-22):** hasta la build-21 el primer enemigo llegaba a ~13,5 min en Fácil, ~11 en Normal y ~9-10 en Difícil (con 30-45 soldados rivales entre dos IAs), y en una partida real los rivales «ya venían a destruirte a los pocos minutos» incluso en Fácil. Medido con `tools/rush_probe.gd` (jugador que no hace nada, mapa 192, 2 rivales, semillas 3, 8 y 13): ahora el primer enemigo llega a **~26 min (Fácil), ~17,5 min (Normal) y ~12 min (Difícil)**, y mientras espera la IA no junta más soldados de los previstos (`_army_cap`), así que la primera oleada tiene un tamaño razonable (Fácil: ~12 soldados por IA). Esto es contra un jugador pasivo: **no se ha medido contra una persona que juega**, así que el número «justo» es una suposición. Entre IAs iguales, en Normal una oleada decisiva acaba la partida en ~28 min; en Fácil entre dos IAs no hay vencedor en 70 min. |
| Equilibrio de la 3ª edad | Costes, vida, daño y ventajas de las unidades nuevas están puestos a ojo siguiendo el esquema de contrarios de Age of Empires II; **no se han jugado a mano ni en un móvil**. Lo comprobado por pruebas automáticas es que las reglas se cumplen (`tools/age2_test.gd`: requisitos, splash de la catapulta, curación del monje, guardar/cargar con 3ª edad, IA que la alcanza) y que la interfaz funciona con toques simulados (`tools/ui_test9.gd`), no que esté bien equilibrada. |
| Mecánicas de la build-23 | **Equilibrio puesto a ojo, nunca jugado por una persona ni en un móvil.** Costes y efectos de las 17 mejoras, precios y comisión del mercado (25 %), plazas y flechas extra de la guarnición, daño de las posturas y velocidad de las formaciones no se han medido contra nadie. Comprobado por pruebas automáticas: `tools/eco_test.gd` (110 comprobaciones: piedra, caza, mercado, mejoras, guarnición, rebato, posturas, formaciones, guardar/cargar), `tools/ui_test12.gd` (toques reales en los botones nuevos) y los tests antiguos de interfaz y simulación, todos sin fallos tras actualizar el de murallas (ahora cuestan piedra). Límites conocidos: los animales se quedan quietos mientras haya alguien a menos de 5 casillas; la formación no mantiene la geometría exacta, solo agrupa la marcha (infantería delante, arqueros detrás) y limita la velocidad al más lento; las partidas guardadas antes de esta versión cargan pero su mapa no tiene piedra ni animales. Ritmo de la IA tras añadir sus mejoras (jugador pasivo, mapa 192, semilla 3, `tools/rush_probe.gd`): primer enemigo a ~25,8 min en Fácil, ~17,5 en Normal y ~11,8 en Difícil (igual que la build-22); IA contra IA en mapa 128: Normal acaba con vencedor a los 23 y 32 min (semillas 3 y 8), Difícil a los 14 min (semilla 13) y Fácil sigue sin vencedor en 70 min (semilla 3). En Fácil la IA no da el rebato ni marcha en formación, y ninguna IA mete soldados en edificios a propósito (solo se refugian aldeanos). |
| Plantar árboles y minas de oro (build-24) | **Equilibrio puesto a ojo, nunca jugado por una persona ni en un móvil.** Retoño: 12 de madera, 90 s, 100 de madera, tope 30; mina: 80 de madera + 70 de piedra por 400 de oro, tope 3. Por referencia (no es una medición): el mercado paga 75 de oro por 100 de madera, así que la mina convierte ~150 de materiales en 400 de oro, pero hace falta piedra (Edad Feudal), un aldeano que construya 30 s y mucho tiempo de picado (0,7 de oro/s por aldeano), y el límite de 3 la frena. Plantar no crea riqueza por sí solo: el cuello de botella de la madera es el trabajo del aldeano (0,8/s), no el número de árboles; sirve cuando el bosque cercano se acaba. Comprobado por `tools/grow_test.gd` (80 comprobaciones) y `tools/ui_test13.gd` (43, con toques reales). Límites conocidos: el retoño se coloca al instante, sin que el aldeano camine hasta él; un árbol nunca crece con alguien encima (espera y reintenta cada 3 s); no se planta junto a un edificio (hueco de una casilla) ni en arena ni en agua; la IA no planta ni minea (así no cambia su ritmo); un filón creado es del jugador solo para el tope: cualquiera puede picarlo. |
| Vida de las defensas (build-25) | **Puesta a ojo y medida solo en simulación, nunca jugada.** Muralla 550→1400, puerta 800→1800, torre 700→1500, castillo 3200→4800 (los costes no cambian; Centro urbano y casas tampoco). Medido con `tools/defense_test.gd` en un claro sin obstáculos, 10 espadachines tardan 34 s en tirar una muralla (antes 14 s) y 43 s una puerta (antes 20 s); 3 arietes tardan 13 y 16 s (antes 6 y 8 s). Una torre sin nadie dentro cae a 10 espadachines en 40 s (antes 18 s) y les mata ~3; con 3 arqueros dentro **ya no cae** (antes caía en 19 s). El castillo aguanta 300 s a 10 espadachines con y sin guarnición (ya los aguantaba antes) y 3 arietes lo tiran en 42 s (antes 28 s). Efecto colateral: la IA también construye torres (2/4/6 según dificultad) y castillos, así que sus defensas aguantan más. IA contra IA tras el cambio (mapa 128, `tools/ai_match.gd`): Normal acaba con vencedor a los 22,4 y 32,7 min (semillas 3 y 8; antes 23 y 32), Difícil a los 14,1 min (semilla 13; antes 14) y Fácil sigue sin vencedor a los 70 min (semilla 3), es decir, no se atascan más que antes. Ritmo de la IA contra un jugador pasivo (`tools/rush_probe.gd`, mapa 192, semilla 3): idéntico (1549 / 1047 / 708 s hasta el primer enemigo en Fácil / Normal / Difícil), porque el cambio no toca al Centro urbano ni a las casas. Lo que **no** he medido: partidas largas contra una persona con muros y torres, ni si ahora conviene más defender que atacar. |
| Aspecto isométrico (versión actual) | **Desde esta versión el juego se dibuja en isométrico (2:1, como Age of Empires II) y es la «última» de Releases; yo no lo he visto en un móvil, solo en capturas de un PC sin tarjeta gráfica.** La versión cenital anterior sigue descargable como `build-26` (Android no deja instalar una versión anterior encima: habría que desinstalar, y se pierde la partida guardada). Todo el arte son modelos 3D hechos por código (`tools/iso/iso_*.gd`: 16 edificios, 27 unidades con andar y acciones, 2 animales, 4 barcos, árboles por clima, rocas, minas y montañas con relieve) que se **hornean a sprites** (`tools/iso/iso_bake.gd` → `iso_post.py` → `iso_atlas.py`, ver «Estructura») en 2 hojas de atlas (`art/iso/`, ~15 MB de PNG, ~1050 sprites, 5 direcciones horneadas y 3 espejadas) con máscara de equipo (canal R) y de ventanas que brillan de noche (canal G). La simulación, la niebla y el guardado no cambian (siguen en píxeles lógicos de 32 por casilla; solo se proyecta al dibujar). Probado con las pruebas automáticas de siempre (reglas: todas sin fallos; interfaz con toques simulados: 13 de 13 tras adaptarlas a la proyección) y con capturas. **Sin medir en el móvil:** el único dato real es la prueba «Reinos ISO» de rendimiento (61 FPS fijos con 800 unidades en un Mali-G57 MC2) que no incluía simulación ni interfaz; la memoria de vídeo del atlas completo es ~125 MB en PC (el pico al cargar, ~280 MB) y **no se ha comprobado en un móvil**. Una compilación normal publica `build-N` (la «última»); para probar cambios sin sustituirla, `[iso-game]` en el mensaje del commit (o `variant = isogame`) compila otra aplicación, «Reinos ISO» (`com.reinos.iso`), como versión preliminar `iso-N` que se instala al lado de «Reinos». `iso-29` fue la primera. Toque de edificios por los píxeles reales del sprite (máscara en `atlas.json`). Límites conocidos: el humo de chimeneas solo sale de casa, cuartel y herrería; el andamio de obra es el edificio entero en transparencia que se va completando de abajo arriba; las sombras de unidades son una elipse genérica. |
| Edificios por civilización | **Los 13 edificios con arquitectura propia (casa, centro urbano, almacén, cuartel, arquería, establo, taller, puerto, torre, monasterio, castillo, herrería, mercado), las murallas y la puerta son distintos en cada una de las 8 civilizaciones**, y cada jugador ve los suyos con su estética (castellanos, francos, ingleses, teutones, vikingos, bizantinos, sarracenos, mongoles; ver «Arquitectura por civilización» más abajo, con la guía para añadir una nueva). La granja y la mina siguen siendo iguales para todos. **Peso (medido):** `art/iso` pasa de ~17 MB a 34,6 MB de PNG (global + iconos 14,1 MB; ocho paquetes de 1,8–3,1 MB, 20,5 MB en total) y el APK de la build-35 pesa **51,8 MB** (la build-34 pesaba 39,1). **Memoria de vídeo (cuenta en PC, no medida en un móvil):** el atlas global ~127 MB más ~31 MB por cada civilización que juega la partida (el juego sólo carga los paquetes de las civilizaciones presentes): ~190 MB en una partida de dos, hasta ~250 MB con cuatro jugadores de civilizaciones distintas. Si pesa demasiado en un móvil, las salidas previstas son texturas comprimidas (ETC2/ASTC), PNG de paleta reducida en los paquetes y cargar sólo los edificios de la edad alcanzada; ninguna está hecha. Comprobado: `tools/age2_test.gd` (615 comprobaciones: cada civilización tiene paquete, sprites, iconos y murallas completos), `tools/civ_test.gd` (300), el resto de pruebas de reglas y los 13 de interfaz, todos sin fallos; capturas en partida de todas las parejas. **Sin ver en un móvil.** Límites: la estética está puesta a ojo y el cono del homenaje del castillo francés va teñido con el color del jugador a propósito; si una civilización nueva no tiene arte aún, el juego usa el de los castellanos. |
| Prototipo isométrico (sin publicar) | **Es un experimento aparte: el juego publicado sigue siendo cenital y no cambia.** `tools/iso/` hornea modelos 3D hechos por código (casa, centro urbano, torre redonda y cuadrada, atalaya, tramo de muralla, castillo, trabuquete, catapulta, 7 robles con 3 de otoño, 2 pinos, roca, oro, aldeano y espadachín en 2 equipos) a sprites 2D en proyección 2:1 de 8 direcciones (`iso_bake.tscn` → `iso_post.py`; 204 sprites, ~2.3 MB). Cada modelo estático lleva además una **sombra horneada** (segundo pase con otra luz, que cae hacia abajo a la derecha). `iso_proto.tscn` los coloca sobre el mapa real de `Sim` con un terreno isométrico (`terrain_iso.gdshader`: hierba con trazos y caminos empedrados por máscara) y los ordena por profundidad; `scene=ref` monta un asedio a una fortaleza con la composición de una captura de Age of Empires II dada como referencia; las unidades van a 0.65 de escala para tener la proporción respecto a la casilla de ese juego. **Variante "ladrillo"** (`style=lego` en el baker y en `iso_proto`; sprites a `/tmp/iso_sprites_lego`, ~1,6 MB): texturas de ladrillo planas, plástico brillante, tacos en almenas y suelo (`lego` en `terrain_iso.gdshader`: color plano por casilla, costa y agua en bloques, caminos lisos) y personas de bloques genéricas; es una alternativa de estilo, no la sustituye. Comprobado solo en capturas en PC: **sin medida de rendimiento en móvil, sin toques isométricos y sin animaciones de ataque o trabajo**. El resultado se ve "de plástico" (superficies lisas, almenas cúbicas, árboles y personas de baja poligonación); para acercarse más hacen falta modelos de artista (packs CC0). Faltan ~10 de 16 edificios, las unidades únicas, puertas, barcos, caballos y el resto de máquinas. Pasarlo al juego exige rehacer cámara, dibujo, selección táctil, niebla, minimapa y terreno, sin tocar la simulación. |
| Prueba de rendimiento isométrica (APK aparte) | **No es el juego ni lo sustituye:** `isotest/` es una escena (`iso_bench.tscn`) con el mapa real de `Sim`, el terreno isométrico, la fortaleza, árboles, máquinas y de 150 a 800 unidades que caminan con sprites 3D pre-renderizados (atlas de 2048×2048 en `isotest/sprites/`, hecho con `tools/iso/iso_atlas.py`). Controles táctiles reales (un dedo arrastra, dos dedos hacen zoom, un toque selecciona y muestra a cuántos píxeles estaba el dedo del cuerpo), botones para subir/bajar unidades, activar o no atlas, sombras y shader de terreno, y **«Medir 10 s»** (recorre el mapa y da FPS medios, el 1 % peor y el peor fotograma) y **«Prueba escalonada»** (150/300/500/800 unidades, 5 s cada una). Se compila como otra aplicación, «Reinos ISO» (`com.reinos.isotest`), que se instala al lado del juego sin tocarlo: se pide con `[iso-test]` en el mensaje del commit o ejecutando el flujo a mano con `variant = isotest`, y sale como versión preliminar `iso-test-N` (nunca como «última»). El APK del juego excluye `isotest/*`. Limitaciones: no incluye simulación, niebla ni interfaz del juego (el coste real será mayor), ni animaciones de ataque o trabajo; los FPS de un PC sin GPU no valen, sólo los del móvil. |
| Civilizaciones (build-20) | **Equilibrio medido solo entre IAs, nunca jugado por una persona ni en un móvil.** Torneo IA contra IA (`tools/civ_arena.sh`, dificultad Normal, mapa 128, semillas 3, 8 y 13, todas las parejas en los dos asientos): con los números iniciales el reparto de victorias iba del **30 % (Ingleses) al 83 % (Francos)**, y Mongoles (71 %) y Bizantinos (70 %) también sobraban; tras recortar a esas tres y reforzar a las cinco restantes (168 partidas) quedó en **40 % (Mongoles) – 63 % (Bizantinos)**, con un error de ±7,6 puntos por civilización (42 partidas cada una): solo se puede decir que no hay ya un claro ganador ni un claro perdedor entre IAs. Después se hizo un último retoque (Mongoles: 4 mangudai por habilidad en vez de 3; Bizantinos: edades un 5 % más baratas en vez de un 8 %) **que no llegó a medirse**. La IA solo usa bien lo que sabe usar: el *Espejismo* de los Sarracenos (ver a todo el enemigo) y apuntar el fuego a mano no se aprovechan igual que lo hará una persona, así que el número de las IAs no los refleja. La IA no usa habilidades en Fácil. Las unidades únicas están puestas a ojo con el mismo esquema de contrarios (`Defs.BONUS` y el campo `as`). Comprobado por pruebas automáticas: `tools/civ_test.gd` (reglas, las 8 habilidades, niebla, guardar/cargar, determinismo) y `tools/ui_test10.gd` (menú, botón de habilidad, apuntar, Castillo). |
| Error corregido en la build-16 | Hasta la build-15 el cuartel solo entrenaba piqueros, la arquería solo arqueros y el establo solo jinetes: las listas de entrenamiento no incluían espadachín, ballestero, explorador ni caballero (existían en `Defs.UNITS`, pero no se podían fabricar, y la IA tampoco). Lo que esta documentación decía de ellos y de la elección de contrarios por la IA no se cumplía en el juego. Ahora `tools/age2_test.gd` comprueba que cada unidad se entrena en el edificio que dice su ficha y viceversa. |
| Logo e icono (build-34) | Emblema heráldico dibujado en SVG por `tools/logo/make_logo.py` (escudo azul partido con marco dorado, corona y castillo con pendón) y rótulo «REINOS» en Lora Negrita (SIL OFL) con acabado dorado; genera el icono de lanzador clásico (192), las capas adaptativas (primer plano dentro de la zona segura, fondo y capa monocroma para iconos temáticos de Android 13+), `icon.png` y el logotipo del menú (`art/logo/`). Probado solo en imagen: máscaras circular, squircle y cuadrada simuladas y reducciones a 96, 64 y 48 px. **No visto en un lanzador de Android real** (cada fabricante recorta a su manera) y «más profesional» sigue siendo un criterio subjetivo. |
| Rendimiento del arte nuevo | Las figuras nuevas son más detalladas que las anteriores. En el PC de pruebas (sin GPU) un fotograma con muchas unidades cuesta ~10-15 % más que antes. Las texturas de unidades ocupan unos **57 MB** como máximo con las 3 edades (se cargan al hacer falta; antes de la 3ª edad eran ~39 MB). Sin medir en móvil. |

## Seguridad

Qué se ha hecho y qué NO se puede prometer («100 % segura» no existe):

- **Permisos del APK:** solo `VIBRATE`, `INTERNET` e `REQUEST_INSTALL_PACKAGES`. Internet se usa únicamente para el aviso de versión nueva y, si lo tocas, para descargar la actualización (se desactiva en el menú, «Actualizaciones: No») y no envía ningún dato tuyo. `REQUEST_INSTALL_PACKAGES` es el permiso que Android exige para entregar un APK al instalador del sistema: la primera vez te llevará a *Ajustes → «Permitir de esta fuente»*. No pide ubicación, contactos, cámara, micrófono ni almacenamiento. El flujo de GitHub **falla** si el APK pide cualquier otro permiso o es depurable.
- **Datos:** solo `ajustes.cfg` (perfil, auto-pausa, avisos) y `partida.sav`/`partida.json` (tu partida guardada, comprimida) en el almacenamiento privado de la app. No hay cuentas, ni publicidad, ni estadísticas. El juego no ejecuta nada que venga de fuera.
- **Firma:** el APK es *release* (no depurable) y va firmado con una clave privada que **solo existe en los secretos de GitHub** (`ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`). Su huella SHA-256 está en `.github/signing-cert.sha256` y en las notas de cada release; el flujo se niega a publicar si la huella no coincide.
- **Actualizaciones:** el juego consulta (HTTPS) la última release; si hay una nueva, avisa en el menú con su tamaño. Al tocar el aviso **descarga el APK dentro del juego** (barra de progreso; tocar otra vez cancela), comprueba que su SHA-256 coincide con el de `reinos.apk.sha256` y se lo entrega al instalador de Android (`PackageInstaller`); tú solo tocas «Instalar». La dirección de descarga se construye siempre con el host fijo `github.com/ElProyecto91/reinos` y un número de build validado como solo dígitos: nada de lo que diga la respuesta de la API decide qué se descarga. La suma SHA-256 detecta descargas corruptas; la **autenticidad** la garantiza Android, que **solo acepta un APK firmado con la misma clave** que el instalado: uno manipulado no puede sustituirlo aunque llegara a descargarse. Si algo falla (sin permiso, sin red, suma distinta, el instalador no responde) el botón ofrece reintentar y después abrir la descarga en el navegador. Android no permite instalar del todo en silencio fuera de Google Play: el toque en «Instalar» no se puede quitar. **No está probado en un móvil real**: las pruebas automáticas cubren la descarga, el hash y el recorrido de estados con un instalador simulado; el tramo del plugin Java con `PackageInstaller` solo se ha compilado y comprobado dentro del APK.
- **Cadena de compilación:** Godot y sus plantillas se verifican con SHA-512 fijados, las acciones de terceros van fijadas por commit y el token del flujo es de solo lectura salvo para publicar la release.
- **Verificar tú mismo un APK:** `sha256sum -c reinos.apk.sha256` y `apksigner verify --print-certs reinos.apk` (la huella debe ser la de `.github/signing-cert.sha256`).

Lo que NO está cubierto:

- **Play Protect** seguirá avisando de «app desconocida» mientras no esté en Google Play (cuesta 25 USD una vez; fuera del objetivo de coste 0).
- Todo depende de **tu cuenta de GitHub**: activa la verificación en dos pasos y no compartas tokens. Quien controle el repositorio controla las actualizaciones.
- Si pierdes los secretos de firma habrá que crear una clave nueva y **desinstalar el juego una vez** (y se pierde la partida guardada).
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
3. Descarga `reinos.apk` de **Releases → Latest** (si el repositorio es público, desde el navegador del móvil sin iniciar sesión) e instálalo. Las actualizaciones se instalan encima sin desinstalar, y desde la primera build con actualizador integrado las siguientes se descargan desde el propio menú del juego.

Sin los secretos de firma el flujo compila igualmente, pero con una clave desechable: el artefacto se llama `reinos-apk-SIN-CLAVE-FIJA`, no se publica y no se podrá actualizar encima de otro.

### Opción B: en tu ordenador

1. Instala **Android Studio** (trae el SDK) o solo las *command-line tools*, y un **JDK 17**.
2. En el SDK instala: `platform-tools`, `build-tools;35.0.1` (o 34.0.0) y `platforms;android-35`.
3. En Godot: *Editor → Gestionar plantillas de exportación → Descargar* (4.4.1).
4. *Editor → Ajustes del editor → Exportar → Android*: ruta del SDK, ruta del JDK y la clave de depuración (Godot puede crearla con `keytool`).
5. *Proyecto → Exportar → Android* (ya está configurado en `export_presets.cfg`: arm64, sin Gradle, horizontal) → *Exportar proyecto*.
6. Activa la instalación de orígenes desconocidos en el móvil y copia el `.apk`.

Una exportación local así **no lleva el instalador de actualizaciones** (el plugin `ReinosInstaller` y su permiso van en `android_extra/` y solo los incluye el flujo de GitHub, que compila con la plantilla Gradle de Godot y comprime las bibliotecas nativas para que el APK pese ~40 MB y no ~90 MB): en ese caso el aviso de versión nueva abre el navegador, como antes.

Para publicar en Google Play necesitarías un `.aab` firmado con tu propia clave (y una cuenta de desarrollador, que tiene coste). Eso queda fuera del «coste 0».

## Controles (también en «Cómo jugar» dentro del juego)

- Un dedo: tocar selecciona o da órdenes; arrastrar mueve la cámara. Mantener pulsado y arrastrar: recuadro de selección.
- Dos dedos: zoom. Minimapa (abajo a la izquierda): toca para saltar.
- Aldeanos → **Construir** → edificio → mueve el fantasma → **Construir**. **Militares** agrupa cuartel, arquería, establo, taller y monasterio; **Defensas** agrupa murallas (arrastra para trazar la línea, o toca inicio y final), puertas (sobre un tramo de muralla), torres y el castillo (Edad de los Castillos). El **Puerto** va en la orilla (el fantasma se pone verde si hay mar junto a él). **Recursos** agrupa «Plantar árbol» (toca cada casilla de hierba; «Listo» al terminar) y la «Mina de oro» (fantasma de 2×2 como un edificio).
- Barcos de pesca: tócalos y toca un banco de peces (hay que haberlo explorado navegando cerca). Con el puerto seleccionado, **Reunión** sobre un banco de peces hace que los barcos nuevos pesquen solos.
- **Mejoras:** toca la Herrería, el Centro o el Almacén y pulsa una mejora (se ofrece sólo el siguiente nivel de cada cadena); entra en la cola del edificio. **Mercado:** botones «Comprar» (fila de arriba) y «Vender» (fila de abajo).
- **Refugio y rebato:** con soldados o aldeanos seleccionados pulsa **Refugiar** y toca el Centro, la Torre o el Castillo; con el edificio seleccionado, **Salir** los saca. El botón de la campana (columna derecha) da el **rebato** y lo quita.
- **Postura y formación:** con soldados seleccionados, **Postura** alterna agresiva → defensiva → mantener → pasiva; **Formación** (global, afecta a las órdenes de mover en grupo) alterna libre → línea → columna.
- **Civilización:** se elige en el menú (**Civilización ▸**, o Aleatoria). Desde la Edad Feudal aparece a la derecha un botón con su **habilidad** (barra de recarga y segundos; resaltado mientras dura). La de los Bizantinos (fuego griego) pide apuntar: pulsa el botón y toca el mapa. La unidad única se entrena en el Castillo.
- Pausa (☰ arriba a la derecha): velocidad ×1/×2/×3, sonido, auto-pausa, perfil de rendimiento. **Salir al menú guarda la partida**; en el menú aparece **Continuar**. Empezar una partida nueva con otra guardada pide confirmación y la sustituye.
- Población máxima: 200 (casas +5, centro urbano +10).

## Batería

Lo que hace el juego para gastar poco (los números son decisiones de diseño, no mediciones):

- Límite de fps por perfil (20/30/60) y, en Ahorro y Normal, dibuja a ~720p y escala a la pantalla. Si pasan 6 s sin tocar la pantalla (solo mirando) baja a 15/20/30 fps; al tocar vuelve al límite normal.
- Menú, pausa y fin de partida: el motor baja a 15 fps y solo redibuja si cambia algo; el ambiente sonoro se detiene.
- La pantalla solo se mantiene encendida mientras la partida corre sin pausa.
- Auto-pausa tras 90 s (Ahorro), 180 s (Normal) o 300 s (Alta) sin tocar la pantalla; se puede desactivar.
- Panel de recursos, niebla de guerra y minimapa se refrescan menos veces por segundo en los perfiles de ahorro.
- La simulación va a 10 pasos por segundo con interpolación; los sonidos van a 22 kHz mono.
- El realismo visual (shaders, día/noche, lluvia) se mantiene en todos los perfiles; Ahorro sólo simplifica el relieve del terreno.
- **En pausa, en el menú y con la partida terminada el motor no dibuja ningún fotograma** (medido: 0 por segundo). Antes dibujaba todos: los shaders del mundo usaban `TIME`, y con `TIME` Godot redibuja la pantalla entera aunque no cambie nada. Ahora usan un reloj propio (`tm`) que solo avanza con la partida en marcha; el agua y las nubes se quedan quietas en pausa. No vuelvas a usar `TIME` en un shader del juego (`battery_test` lo detecta).
- Las unidades se dibujan agrupadas por textura (sombras juntas, figuras por tipo, humo y cargas en una sola llamada, anillos de selección y cargas como texturas en vez de polígonos): con 128 unidades y 20 edificios a la vista pasa de ~475 a ~195 llamadas de dibujo por fotograma y de 2,4 a 1,5 ms de GDScript (medido en PC; en el móvil cada llamada de dibujo y cada instrucción cuesta bastante más). La lista de edificios ordenada por altura se reutiliza entre fotogramas. Efecto visual: las barras de vida y las cargas quedan por encima de todas las figuras, y al solaparse dos unidades de distinto tipo las más pesadas (caballería, ariete) quedan siempre encima.
- La niebla de guerra deduplica las unidades que comparten casilla y alcance y marca lo que pasa a verse al revelarlo: ~33 % menos de tiempo por actualización con el mismo resultado exacto (`tools/fog_test.gd` lo compara con el algoritmo original).
- La cámara solo escribe su transformación cuando cambia.
- En partidas largas (200 de población por bando, ~525 entidades) lo que más costaba era que cada soldado ocioso buscaba enemigos cerca de sí: ahora cada celda del mapa guarda qué bandos hay dentro y se salta la búsqueda si ninguno es hostil (mismo resultado exacto, `tools/scan_test.gd`): el paso de simulación baja de 16,8 a 4,5 ms. Además la IA no repite la búsqueda de un recurso agotado hasta 12 s después (a los 60 min de partida el paso baja de 7,65 a 4,45 ms). Todo medido en PC.

Lo que no se puede controlar desde el juego: el brillo, el tiempo de pantalla y la frecuencia de refresco del móvil. Es, con diferencia, lo que más gasta.

### Redmi Note 13 5G (2400×1080, AMOLED de 120 Hz, Dimensity 6080, Mali-G57 MC2)

- Perfil **Normal** (el de serie): dibuja a 1600×720 y lo escala a la pantalla (×1,5) a 30 fps. Es el punto recomendado. **Alta** dibuja a 2400×1080 y a 60 fps: sólo si te sobra batería.
- En *Ajustes → Pantalla → Frecuencia de actualización* elige **60 Hz** (o «Estándar»): el juego va a 30 fps como mucho y el panel a 120 Hz gasta más sin que se note. El juego no puede cambiarlo por ti (en Godot no hay forma de pedirlo desde el código); el ahorro es una estimación, no está medido.
- Brillo manual bajo: en AMOLED el brillo es el mayor consumo individual. Los negros (la niebla sin explorar) no gastan.
- Si no vas a seguir jugando, pausa (☰): en pausa el motor deja de dibujar y la partida se guarda.

## Estructura

```
scripts/        código del juego (GDScript)
  sim.gd        simulación pura (sin dibujo): unidades, edificios, combate, murallas
  ai_player.gd  IA
  game.gd       cámara isométrica, entrada táctil, bucle; iso_view.gd (sprites del mundo ordenados por profundidad), renderer.gd (efectos
                y marcas sobre el suelo) y art.gd (atlas, iconos) dibujan
  iso.gd        proyección isométrica (proj/unproj 2:1) y transformación para dibujar el plano lógico sobre el suelo
  iso_art.gd    atlas de sprites isométricos (art/iso; un paquete por civilización que se carga al empezar la partida) y shader de color de equipo (shaders/iso_sprite.gdshader)
  civs.gd       las 8 civilizaciones: bonificaciones, unidad única y habilidad (todo es dato; Sim lo lee una sola vez)
  hud.gd        interfaz táctil; ui_kit.gd botones; menu.gd menú
  settings.gd   perfiles de batería y calidad (se guardan en user://ajustes.cfg)
  save_game.gd  guardar/cargar partida (Sim + IA + niebla + cámara) en user://partida.sav
data/es.json    todos los textos en español (para traducir: otro JSON y cambiar Lang.FILE)
audio/*.wav     sonidos generados por tools/gen_audio.py
art/iso/        atlas de sprites isométricos (atlas_N.png + mask_N.png + atlas.json; atlas_<civ>_N.png + civ_<civ>.json + civ_<civ>_meta.json por civilización; iconos de menú), generado por tools/iso
art/icon/       iconos de lanzador de Android (clásico 192 y capas adaptativas 432), generados por tools/logo/make_logo.py
art/logo/       emblema y logotipo del menú (generados por tools/logo/make_logo.py)
icon.png        icono del proyecto (512)
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

# economía nueva (piedra, caza, mercado, mejoras, guarnición, rebato, posturas, formaciones, guardar/cargar; 110 comprobaciones)
$GODOT --headless --path . --script res://tools/eco_test.gd

# plantar árboles y minas de oro (reglas, crecimiento, esperar a que nadie esté encima, minas en obra → filón, topes, guardar/cargar; 80 comprobaciones)
$GODOT --headless --path . --script res://tools/grow_test.gd

# capturas del aspecto (bosque, costa, desierto, montaña, nieve) a mediodía y sin niebla ni interfaz; bench=N mide ms por fotograma (necesita xvfb)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/look_shot.tscn --rendering-driver opengl3 --resolution 1280x720 -- tag=x seed=7 size=192 zoom=1.6   # → /tmp/look_x_<sitio>.png

# prototipo isométrico: hornear sprites (modelos → /tmp/iso_raw → /tmp/iso_sprites) y componer una escena con el mapa real (necesitan xvfb)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/iso/iso_bake.tscn --rendering-driver opengl3 --resolution 800x600 -- out=/tmp/iso_raw only=casa,centro,torre,torrec,atalaya,muralla,castillo,asedio,roble,pino,roca,aldeano,espadachin   # teams=blue,red para las personas
python3 tools/iso/iso_post.py /tmp/iso_raw /tmp/iso_sprites
python3 tools/iso/iso_atlas.py /tmp/iso_sprites isotest/sprites   # atlas para la prueba de rendimiento (isotest/)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/iso/iso_proto.tscn --rendering-driver opengl3 --resolution 1280x720 -- shot=/tmp/iso_proto.png scene=ref seed=4 cx=3.2 cy=0.3 zoom=1.3   # scene=base: casas y soldados junto al centro urbano

# cuánto aguantan muralla, puerta, torre y castillo frente a soldados y arietes, con la vida de antes y la de ahora (31 comprobaciones)
$GODOT --headless --path . --script res://tools/defense_test.gd

# interfaz con toques simulados (necesita xvfb o pantalla)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/ui_test2.tscn --rendering-driver opengl3
# ui_test12 = herrería/mejoras, mercado, postura, formación, refugio, rebato con toques reales; capturas: tools/mech_shot.tscn (mode=forge|market|hunt|stone|garrison|plant|mine)
# ui_test13 = Construir → Recursos, plantar con toques sobre el mapa, retoño → árbol en la capa de casillas, mina en obra → filón de oro, tope de minas
# también ui_test3, ui_test4 (granjas, edades...), ui_test5 (murallas y puertas), ui_test6 (recolectar oro),
# ui_test7 (puerto: construir, entrenar barcos, pescar, embarcar, desembarcar, atacar), ui_test9 (Edad de los Castillos:
# requisito de 2 tipos militares, menús, construir monasterio y castillo, botones de las unidades nuevas), battery_test, perf_test

# niebla de guerra: idéntica al algoritmo original y más rápida
$GODOT --headless --path . --script res://tools/fog_test.gd -- seed=3 size=192 min=10

# banco de dibujo: aldea densa (ms de GDScript y llamadas de dibujo por fotograma; con shot=… guarda una captura para comparar)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/draw_bench.tscn --rendering-driver opengl3 --resolution 1280x720 -- frames=100 zoom=0.8
# fotogramas que dibuja de verdad el motor en juego/pausa y en el menú (deben ser 0 en pausa y menú)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/frames_probe.tscn --rendering-driver opengl3 --resolution 1280x720
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/frames_menu.tscn --rendering-driver opengl3 --resolution 1280x720

# guardar y cargar (ida y vuelta idéntica, barcos con carga, archivo corrupto o de otra versión)
$GODOT --headless --path . --script res://tools/save_test.gd -- seed=8 size=256 min=11
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/ui_test8.tscn --rendering-driver opengl3 --resolution 1280x720

# aviso y descarga de actualización: suma SHA-256, redirecciones, cortes, permiso, cancelar, errores del instalador (necesita el servidor de pruebas en marcha)
python3 tools/mock_release_server.py 18765 &
$GODOT --headless --path . --script res://tools/updater_test.gd -- port=18765
# capturas del botón del menú en cada estado de la actualización
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/update_shot.tscn --rendering-driver opengl3 --resolution 1280x720 -- out=/tmp/upd

# conectividad de mapas, exploración autónoma y filtro de búsqueda de enemigos
$GODOT --headless --path . --script res://tools/connect_test.gd
$GODOT --headless --path . --script res://tools/explore_test.gd
$GODOT --headless --path . --script res://tools/scan_test.gd
# Edad de los Castillos: coherencia de Defs (cada unidad se entrena donde dice), requisitos de edad, splash, curación...
$GODOT --headless --path . --script res://tools/age2_test.gd
# ... y además una partida IA contra IA que comprueba que llegan a la 3ª edad, construyen monasterio/castillo y usan las unidades nuevas
$GODOT --headless --path . --script res://tools/age2_test.gd -- ai=1 min=30 seed=3 diff=2,2
# civilizaciones: datos, bonificaciones, unidad única en el Castillo, las 8 habilidades, niebla (Espejismo, vista mongola), guardar/cargar, determinismo
$GODOT --headless --path . --script res://tools/civ_test.gd
# ... con interfaz real: panel de elección del menú, botón de habilidad (edad, recarga, apuntar el fuego), botón de la unidad única, guardado
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/ui_test10.tscn --rendering-driver opengl3 --resolution 1280x720
# torneo de civilizaciones IA contra IA (todas las parejas, dos asientos, varios mapas) y su resumen; capturas en juego: tools/civ_shot.tscn
tools/civ_arena.sh /tmp/arena.txt 3 8 13 && python3 tools/civ_arena_report.py /tmp/arena.txt
# captura en juego de la 3ª edad (castillo, monasterio y unidades nuevas)
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/age2_shot.tscn --rendering-driver opengl3 --resolution 1280x720 -- shot=/tmp/a.png zoom=1.4 select=castillo
# IA: coste en partida larga y partidas IA contra IA (la IA nueva contra la congelada de tools/ai_legacy.gd)
$GODOT --headless --path . --script res://tools/late_prof.gd -- seed=3 size=192 min=60
$GODOT --headless --path . --script res://tools/ai_match.gd -- seed=3

# utilidades: capturas del mundo (world_shot, en el minimapa con at=minimap), estadísticas de mapa (map_stats),
# alcance de recursos desde cada base (reach_dbg), depuración de la economía de la IA (ai_food_dbg)
```

## Arte

Todo se modela en 3D por código y se hornea a sprites; no hay nada dibujado a mano. Tubería (`tools/iso/`):

1. **Modelos** (`iso_models.gd`, `iso_build.gd`, `iso_nature.gd`, `iso_people.gd`, `iso_riders.gd`, `iso_machines.gd`): mallas primitivas con texturas procedurales (piedra, yeso, madera, tejas, hojas). Cada modelo mira a +z, 1 unidad = 1 casilla, origen en el suelo. Lo que debe teñirse con el color del jugador se construye con un gris neutro (`IsoModels.TEAM_BASE`): el horneado lo detecta y genera una máscara. Las personas son un esqueleto paramétrico (`IsoPeople.human`: cadera, rodilla, hombro, codo, armas y cascos por tipo) con poses por nombre de fotograma (`idle`, `w0..w3`, `a0..a2`, `t00..t31`).
2. **Catálogo** (`iso_catalog.gd`): qué se hornea (nombre, constructor, giro, sombra, máscara) y el tamaño del lienzo. Las unidades se hornean en 5 direcciones (d = 1..5 con d = ángulo lógico / 45°, yaw = 90° − 45°·d); las otras tres son espejos horizontales (`IsoView.MIRROR`). Grupos `pv_<tipo>` hornean sólo una vista previa.
3. **Baker** (`iso_bake.gd`): renderiza con cámara ortográfica a 30° de elevación y 45° de giro (la casilla sale como rombo 2:1), un pase de color, uno de máscara de equipo y otro de sombra (suelo blanco con la luz de arriba-izquierda).
4. **Post** (`iso_post.py`): baja a la mitad con alfa premultiplicado, recorta y guarda el punto de anclaje (`origins.json` se acumula entre tandas). 5. **Atlas** (`iso_atlas.py`): empaqueta con MaxRects en hojas de 4096 px (RGBA + máscara R8) y genera los iconos de menú de 96×96 (`icons.png`).

```
# hornear (por tandas), procesar y empaquetar; después importar
$GODOT --path . res://tools/iso/iso_bake.tscn --rendering-driver opengl3 --resolution 800x600 -- out=/tmp/iso_raw only=casa,castillo,piquero
python3 tools/iso/iso_post.py /tmp/iso_raw /tmp/iso_sprites
python3 tools/iso/iso_atlas.py /tmp/iso_sprites art/iso
$GODOT --headless --path . --import      # reescribe project.godot: descartar ese cambio con git checkout -- project.godot
# revisar: tools/iso_town.tscn (ciudad de prueba: mode=blds|units|enemy|walls|all) y tools/iso_parade.tscn (desfile de sprites por dirección y fotograma)
```

### Arquitectura por civilización (y cómo añadir una)

Cada civilización de `Civs.IDS` tiene **sus propios edificios, murallas y puerta**, con su estética (castellanos: sillería y teja con arcos de herradura; francos: pizarra gris-azulada y torres cónicas; ingleses: ladrillo, entramado Tudor y keep normando; teutones: ladrillo oscuro, frontones escalonados y teja verde; vikingos: madera, techos de turba, cabezas de dragón y empalizada; bizantinos: cúpulas, bandas de piedra y ladrillo; sarracenos: cúpulas de cebolla turquesa, celosías y minaretes; mongoles: yurtas, pabellones lacados y muros de tapia). El juego dibuja a cada jugador con los sprites de su civilización (`IsoView.civ_of`); si una civilización no tiene paquete de sprites usa `IsoArt.DEFAULT_CIV` (castellanos), así que el juego no se rompe mientras su arte está en camino.

- Código: `tools/iso/civ/<id>.gd` (un módulo por civilización, mismo contrato en todos) sobre el kit común `tools/iso/iso_arch.gd` (materiales, arcos, torres, murallas, cúpulas, patios de cuartel/arquería/establo/taller/puerto/herrería…). `tools/iso/iso_civs.gd` es el registro; `tools/iso/civ_check.gd` valida los módulos (todos los edificios se construyen y caben en su huella).
- Sprites: se llaman `<civ>__<tipo>` (`puerto` en 4 orientaciones `<civ>__puerto_0..3`; murallas `<civ>__muralla_poste`, `<civ>__muralla_a0..7`, `<civ>__puerta_x/z`). Los edificios iguales para todos (mina) siguen en el atlas global.
- Paquetes: `iso_atlas.py` escribe un paquete por civilización (`civ_<id>.json` + `atlas_<id>_N.png` + `mask_<id>_N.png`) además del global; el juego **sólo carga los de las civilizaciones que juegan la partida** (`IsoArt.ensure_civ`). `civ_<id>_meta.json` lleva los puntos de humo de cada edificio (marcadores `A.smoke_src` / `A.chimney` → `tools/iso/civ_meta.gd`).
- Iconos de menú: `ic_<civ>__<tipo>` (el HUD usa el de la civilización del jugador).

**Añadir una civilización nueva:**
1. Darla de alta en `Civs.IDS` / `Civs` (datos de juego: nombre, bonos, unidad única…).
2. Copiar `tools/iso/civ/_plantilla.gd` a `tools/iso/civ/<id>.gd` y darle su paleta y su forma a cada edificio (la plantilla ya construye los 13 tipos y las murallas: se puede hornear tal cual y mejorar edificio a edificio).
3. `godot --headless --path . --script res://tools/iso/civ_check.gd -- civ=<id>` (¿se construye todo y cabe en la huella?).
4. `tools/iso/civ_preview.sh <id>` (hornea sólo esa civilización en /tmp y deja una hoja de contacto `/tmp/civ_sheet_<id>.png`; ~40 s; con nombres: `tools/iso/civ_preview.sh <id> <id>__casa,<id>__castillo` rehace sólo esos) y `python3 tools/iso/civ_compare.py /tmp/civ_spr /tmp/cmp.png <id>,castellanos` para compararla con otra.
5. `tools/iso/civ_build.sh <id>` (hornea, funde en la carpeta de trabajo `SPR=/tmp/iso_all`, reescribe los paquetes de `art/iso`, genera el humo e importa). Ver el resultado en partida con `tools/iso_town.tscn -- civ=<id> civ2=<otra> mode=blds|walls`.

Reglas del modelado de edificios: la cámara ve las caras +z y +x; el sol viene de arriba-izquierda; la huella de N casillas mide N unidades; el color del jugador es cualquier material liso con r = g = b (nunca otros grises neutros); puerta en la cara +z.

Detalles del motor: las capas de suelo se dibujan en coordenadas lógicas bajo `Iso.XF`; los sprites viven en un `IsoView` con orden por y; las sombras son hijos con `z_index` fijo; los recursos no se ven hasta que su casilla está explorada. Selección y órdenes se resuelven en el plano isométrico (`pick_unit`, `pick_building`, `screen_to_iso`). El minimapa es un rombo 2:1.

**Icono de la app.** Se dibujó por código (castillo de sillares al atardecer, luz cálida a la izquierda y sombras azules, ventanas encendidas, estandarte del jugador; sin archivos de arte externos) y quedó guardado como imágenes. Son `icon.png` (512), `art/icon/ic_main_192.png` (clásico, esquinas redondeadas) y las capas adaptativas `ic_fg_432.png` / `ic_bg_432.png` / `ic_mono_432.png`; el castillo cabe en el círculo central de 264 px que Android garantiza visible con cualquier máscara. `export_presets.cfg` las usa como `launcher_icons/*` y `art/icon/*` no entra en el paquete del juego.

## Licencias

Godot Engine: MIT. El código de este proyecto lo escribió Claude (Anthropic) a petición del autor; no incluye assets de terceros.
