# Reinos

Estrategia en tiempo real para Android, estilo Age of Empires, **100 % en español, sin internet y sin coste**.
Hecho con Godot 4.4.1 (gratuito). Todo el arte y los sonidos se generan por código: no hay imágenes dibujadas a mano ni música. (Las hojas de unidades se «hornean» una vez con `tools/bake_units.gd` a `art/units/*.png` para que el juego arranque rápido; ver «Arte».)

- 1 jugador contra 1–3 IAs (aliadas entre sí por defecto, o todos contra todos).
- Mapa plano de 128×128, 192×192 o 256×256 casillas con continentes, islas y mar, cordilleras infranqueables y climas (nieve, templado, desierto).
- Aspecto: terreno dibujado por shader (agua con olas y espuma, relieve, montañas), ciclo día/noche, nubes, lluvia ocasional, árboles por bioma con volumen (copas sombreadas por normales con luz del noroeste, 7 robles y 4 pinos distintos, rocas talladas en planos, pepitas de oro con brillo; build-26), montañas con relieve de laderas y nieve solo en las cumbres, poblados a escala del mapa (el centro urbano es un ayuntamiento con campanario, no un castillo). Las personas son figuras articuladas con animación de caminar y de oficio (talar, picar, cultivar, construir, golpear, apuntar) y tres capas para teñir el uniforme con el color del equipo.
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
| Aspecto con volumen (build-26) | **Puesto a ojo, comparado solo con capturas; nadie lo ha visto en un móvil.** Árboles, rocas y filones se pintan ahora con `scripts/art_volume.gd` (esferas y conos en un z-buffer, luz del noroeste igual que el relieve del terreno, hendiduras más oscuras, sombra suave al sureste): 7 robles (color, tamaño y posición distintos en la casilla, para romper la cuadrícula del bosque) y 4 pinos en lugar de 3 y 3, rocas en facetas con grietas y pepitas de oro con brillo especular. Las montañas del shader (`shaders/terrain.gdshader`) eran un camuflaje blanco y negro sin relieve; ahora son roca parda con pendientes iluminadas y nieve solo en las cumbres más altas. Coste medido en el PC de pruebas: el arte tarda ~30-40 ms más al arrancar (≈ 620-670 ms frente a 590-630); el atlas de recursos pasa de 18 a 24 casillas de 64×64. **No he podido medir el coste del shader de montaña**: el limitador de fotogramas del juego da 66 ms en todas las pruebas, con el shader viejo y con el nuevo. La simulación no cambia (sin tests nuevos de reglas); las capturas se hacen con `tools/look_shot.tscn`. Lo que **no** es: pintura a mano como las ilustraciones de referencia; los edificios, las unidades y el suelo llano no se han tocado, y las montañas siguen siendo ruido iluminado, no picos modelados. |
| Prototipo isométrico (sin publicar) | **Es un experimento aparte: el juego publicado sigue siendo cenital y no cambia.** `tools/iso/` hornea modelos 3D hechos por código (casa, centro urbano, torre redonda y cuadrada, atalaya, tramo de muralla, castillo, trabuquete, catapulta, 7 robles con 3 de otoño, 2 pinos, roca, oro, aldeano y espadachín en 2 equipos) a sprites 2D en proyección 2:1 de 8 direcciones (`iso_bake.tscn` → `iso_post.py`; 204 sprites, ~2.3 MB). Cada modelo estático lleva además una **sombra horneada** (segundo pase con otra luz, que cae hacia abajo a la derecha). `iso_proto.tscn` los coloca sobre el mapa real de `Sim` con un terreno isométrico (`terrain_iso.gdshader`: hierba con trazos y caminos empedrados por máscara) y los ordena por profundidad; `scene=ref` monta un asedio a una fortaleza con la composición de una captura de Age of Empires II dada como referencia; las unidades van a 0.65 de escala para tener la proporción respecto a la casilla de ese juego. **Variante "ladrillo"** (`style=lego` en el baker y en `iso_proto`; sprites a `/tmp/iso_sprites_lego`, ~1,6 MB): texturas de ladrillo planas, plástico brillante, tacos en almenas y suelo (`lego` en `terrain_iso.gdshader`: color plano por casilla, costa y agua en bloques, caminos lisos) y personas de bloques genéricas; es una alternativa de estilo, no la sustituye. Comprobado solo en capturas en PC: **sin medida de rendimiento en móvil, sin toques isométricos y sin animaciones de ataque o trabajo**. El resultado se ve "de plástico" (superficies lisas, almenas cúbicas, árboles y personas de baja poligonación); para acercarse más hacen falta modelos de artista (packs CC0). Faltan ~10 de 16 edificios, las unidades únicas, puertas, barcos, caballos y el resto de máquinas. Pasarlo al juego exige rehacer cámara, dibujo, selección táctil, niebla, minimapa y terreno, sin tocar la simulación. |
| Civilizaciones (build-20) | **Equilibrio medido solo entre IAs, nunca jugado por una persona ni en un móvil.** Torneo IA contra IA (`tools/civ_arena.sh`, dificultad Normal, mapa 128, semillas 3, 8 y 13, todas las parejas en los dos asientos): con los números iniciales el reparto de victorias iba del **30 % (Ingleses) al 83 % (Francos)**, y Mongoles (71 %) y Bizantinos (70 %) también sobraban; tras recortar a esas tres y reforzar a las cinco restantes (168 partidas) quedó en **40 % (Mongoles) – 63 % (Bizantinos)**, con un error de ±7,6 puntos por civilización (42 partidas cada una): solo se puede decir que no hay ya un claro ganador ni un claro perdedor entre IAs. Después se hizo un último retoque (Mongoles: 4 mangudai por habilidad en vez de 3; Bizantinos: edades un 5 % más baratas en vez de un 8 %) **que no llegó a medirse**. La IA solo usa bien lo que sabe usar: el *Espejismo* de los Sarracenos (ver a todo el enemigo) y apuntar el fuego a mano no se aprovechan igual que lo hará una persona, así que el número de las IAs no los refleja. La IA no usa habilidades en Fácil. Las unidades únicas están puestas a ojo con el mismo esquema de contrarios (`Defs.BONUS` y el campo `as`). Comprobado por pruebas automáticas: `tools/civ_test.gd` (reglas, las 8 habilidades, niebla, guardar/cargar, determinismo) y `tools/ui_test10.gd` (menú, botón de habilidad, apuntar, Castillo). |
| Error corregido en la build-16 | Hasta la build-15 el cuartel solo entrenaba piqueros, la arquería solo arqueros y el establo solo jinetes: las listas de entrenamiento no incluían espadachín, ballestero, explorador ni caballero (existían en `Defs.UNITS`, pero no se podían fabricar, y la IA tampoco). Lo que esta documentación decía de ellos y de la elección de contrarios por la IA no se cumplía en el juego. Ahora `tools/age2_test.gd` comprueba que cada unidad se entrena en el edificio que dice su ficha y viceversa. |
| Icono nuevo (build-17/18) | Probado solo en imagen: a 48, 64, 96, 144 y 512 px y con máscaras circular, squircle y esquinas redondeadas simuladas. **No visto en un lanzador de Android real** (cada fabricante recorta a su manera). Hay también una capa monocroma propia (`ic_mono_432.png`, silueta del castillo) para «iconos temáticos» de Android 13+; sin ella el APK llevaba la silueta de Godot. Si el lanzador la usa o no, no se ha comprobado. «Moderno y realista» es un criterio subjetivo: si no te convence, el estilo se cambia en `tools/gen_icon.gd`. |
| Rendimiento del arte nuevo | Las figuras nuevas son más detalladas que las anteriores. En el PC de pruebas (sin GPU) un fotograma con muchas unidades cuesta ~10-15 % más que antes. Las texturas de unidades ocupan unos **57 MB** como máximo con las 3 edades (se cargan al hacer falta; antes de la 3ª edad eran ~39 MB). Sin medir en móvil. |

## Seguridad

Qué se ha hecho y qué NO se puede prometer («100 % segura» no existe):

- **Permisos del APK:** solo `VIBRATE` e `INTERNET`. Internet se usa únicamente para el aviso de versión nueva (se desactiva en el menú, «Actualizaciones: No») y no envía ningún dato tuyo. No pide ubicación, contactos, cámara, micrófono ni almacenamiento. El flujo de GitHub **falla** si el APK pide cualquier otro permiso o es depurable.
- **Datos:** solo `ajustes.cfg` (perfil, auto-pausa, avisos) y `partida.sav`/`partida.json` (tu partida guardada, comprimida) en el almacenamiento privado de la app. No hay cuentas, ni publicidad, ni estadísticas. El juego no ejecuta nada que venga de fuera.
- **Firma:** el APK es *release* (no depurable) y va firmado con una clave privada que **solo existe en los secretos de GitHub** (`ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`). Su huella SHA-256 está en `.github/signing-cert.sha256` y en las notas de cada release; el flujo se niega a publicar si la huella no coincide.
- **Actualizaciones:** el juego consulta (HTTPS) la última release; si hay una nueva, avisa en el menú. Al tocar el aviso abre en el navegador una dirección fija del código. La instala Android, que **solo acepta un APK firmado con la misma clave** que el instalado: uno manipulado no puede sustituirlo. Android no permite instalar sin que toques «Instalar»; esto no se puede automatizar más sin permisos peores.
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
  game.gd       cámara, entrada táctil, bucle; renderer.gd / art.gd / painter.gd dibujan
  civs.gd       las 8 civilizaciones: bonificaciones, unidad única y habilidad (todo es dato; Sim lo lee una sola vez)
  art_units.gd  figuras de personas (esqueleto, herramientas, cascos); art_mounts.gd caballos, ariete, catapulta y trabuquete; art_ships.gd barcos;
                art_civ_units.gd las 8 unidades únicas
  art_buildings.gd edificios por capas (base, equipo)
  art_volume.gd sombreado con volumen de árboles, rocas y oro (z-buffer de esferas/conos + luz por normales + oclusión de hendiduras)
  hud.gd        interfaz táctil; ui_kit.gd botones; menu.gd menú
  settings.gd   perfiles de batería y calidad (se guardan en user://ajustes.cfg)
  save_game.gd  guardar/cargar partida (Sim + IA + niebla + cámara) en user://partida.sav
data/es.json    todos los textos en español (para traducir: otro JSON y cambiar Lang.FILE)
audio/*.wav     sonidos generados por tools/gen_audio.py
art/units/      hojas de unidades horneadas por tools/bake_units.gd (3 capas: fondo, equipo, primer plano)
art/icon/       iconos de lanzador de Android (clásico 192 y capas adaptativas 432), generados por tools/gen_icon.gd
icon.png        icono del proyecto (512), generado por tools/gen_icon.gd
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

# aviso de actualización (necesita el servidor de pruebas en marcha)
python3 tools/mock_release_server.py 18765 &
$GODOT --headless --path . --script res://tools/updater_test.gd -- port=18765

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

Las figuras y edificios se dibujan por código (`art_units.gd`, `art_mounts.gd`, `art_ships.gd`, `art_buildings.gd`) con un rasterizador propio (`painter.gd`). Para no pagar ~3 s de arranque, las hojas de unidades están horneadas en `art/units/*.png`; si no existen se generan al vuelo (más lento). **Si cambias el dibujo de una unidad, vuelve a hornear y a importar:**

```
$GODOT --headless --path . --script res://tools/bake_units.gd
$GODOT --headless --path . --import
# ver cada unidad: tools/dump_units.gd → /tmp/units_<tipo>.png; captura en juego: tools/units_shot.tscn
```

**Realismo de las figuras (build-19).** Las personas pasan de «muñecos de bloques» a figuras con proporción humana: hombros caídos, torso en hexágono (no rectángulo), extremidades afusadas con codo/rodilla/bota/mano (`limb`, `boot`, `hand`, `arm_seg`), túnica con falda y cinturón, cabeza afusada, y un pase de luz global por figura (`_finish`: luz cálida arriba-izquierda, sombra fría abajo-derecha) en vez de sombreado por pieza. Los caballos tienen cuello y cabeza afusados, vientre, hombro y anca marcados; el caballero lleva yelmo con cruz y remaches. Contornos más suaves y colores de equipo algo menos saturados (`team_mod` ×0,9 de saturación, ×1,12 de brillo) para que el uniforme no parezca de plástico. **Límite conocido:** en juego las figuras se ven a ~0,3-0,4× de su tamaño horneado, así que el detalle fino (dedos, remaches, pliegues) casi no se aprecia; lo que sí se nota es silueta, masa, postura y luz. La mejora es moderada y no está vista en un móvil real. Barcos y máquinas de asedio no cambian (salvo los caballos de la caballería).

**Unidades únicas (build-20).** Las 8 se dibujan en `art_civ_units.gd` con las mismas herramientas (esqueleto, cascos, armas y monturas de `art_units.gd` y `art_mounts.gd`); el arquero de arco largo reutiliza el arquero con un arco más grande (`bow(..., k)`). Están horneadas en `art/units/*.png` como las demás. Mismo límite de siempre: en juego se ven a ~0,35× y lo que se distingue es silueta, casco, arma y color (la catafracta va en blanco con lanza larga, el berserker pelirrojo con hacha grande), no el detalle.

**Icono de la app.** Se dibuja también por código (`tools/gen_icon.gd`: castillo de sillares al atardecer, luz cálida a la izquierda y sombras azules, ventanas encendidas, estandarte del jugador; todo con `painter.gd`, sin archivos de arte externos). Genera `icon.png` (512), `art/icon/ic_main_192.png` (clásico, esquinas redondeadas) y las capas adaptativas `ic_fg_432.png` / `ic_bg_432.png` / `ic_mono_432.png`; el castillo cabe en el círculo central de 264 px que Android garantiza visible con cualquier máscara. `export_presets.cfg` las usa como `launcher_icons/*` y `art/icon/*` no entra en el paquete del juego. Para regenerarlo y ver una hoja de comprobación (tamaños 144→48 y máscaras circular/squircle/redondeada): `$GODOT --headless --path . --script res://tools/gen_icon.gd -- preview=/tmp/hoja.png` y después `--import`.

Los árboles, rocas y filones (`art.gd` + `art_volume.gd`) tampoco se hornean: se pintan al arrancar en un atlas de 24 casillas de 64×64 (~30-40 ms más que con los sprites planos de antes). Tras añadir una clase nueva con `class_name` hay que reimportar el proyecto (`$GODOT --headless --path . --import`) o los scripts sueltos no la encuentran.

Los edificios no se hornean a archivo: se pintan al arrancar (`art_buildings.gd`, ~0,4 s en el PC de pruebas, sin cambio respecto a antes) y quedan como texturas; para verlos sueltos y ampliados: `PRE=x $GODOT --headless --path . --script res://tools/dump_bld.gd -- casa centro zoom=2.4` → `/tmp/bld_sheet_x.png`.

## Licencias

Godot Engine: MIT. El código de este proyecto lo escribió Claude (Anthropic) a petición del autor; no incluye assets de terceros.
