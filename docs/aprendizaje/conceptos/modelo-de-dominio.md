# Modelo de dominio

## Qué problema resuelve

Antes de escribir el esquema de la base de datos hay que decidir **qué cosas existen** en el producto, cómo se relacionan y qué reglas no se pueden romper nunca. Si eso se decide sobre la marcha, en la fase 4, cada funcionalidad nueva del roadmap acaba pidiendo una migración que rompe datos. El modelo está en `docs/product/domain-model.md`; esta nota explica el porqué.

## Las piezas

- **Entidad:** algo con identidad propia que se guarda (Host, Report, PendingUpdate). Dos hosts con el mismo nombre siguen siendo dos hosts, porque su `id` es distinto.
- **Relación y cardinalidad:** cuántos de cada lado. En Mermaid, `HOST ||--o{ REPORT` se lee «un host tiene cero o muchos informes; cada informe es de exactamente un host». `||` es «exactamente uno», `o{` «cero o muchos», `|{` «uno o muchos», `o|` «cero o uno».
- **Diagrama ER (entidad-relación):** el dibujo de las entidades, sus columnas y sus relaciones. Va en Mermaid porque GitHub lo dibuja dentro del Markdown y vive en el repo junto al texto.
- **Glosario:** una definición por palabra. Si la UI dice «trusted report», el código, la API y la documentación usan esa misma palabra con ese mismo significado.

## La idea central: episodios, no copias

Lo ingenuo sería guardar, en cada informe, la lista completa de paquetes pendientes. Con 200 hosts informando cada hora, 90 días y unos 20 pendientes por host salen unos 8,6 millones de filas, casi todas repetidas.

En su lugar, cada informe es **una fila** y lo pendiente se guarda como **episodios**: «el host X va atrasado con `openssl:amd64` desde tal fecha». El episodio se abre la primera vez que aparece un pendiente para ese paquete y se cierra (`resolved_at`) cuando un informe de confianza deja de listarlo. Del mismo episodio salen el «pending since», el tiempo de exposición y el historial.

- El paquete se identifica por **nombre y arquitectura**: `libc6:amd64` y `libc6:i386` son dos episodios, porque se actualizan por separado.
- Hay **dos relojes**: `pending_since` (cualquier actualización, cuenta para `other_max_age`) y `security_since` (desde que aparece una de seguridad, cuenta para `security_max_age`). Ejemplo: un paquete con un arreglo de errores pendiente desde hace 20 días recibe hoy una versión de seguridad. Con un solo reloj saldría fuera de política hoy mismo; con dos, la de seguridad tiene sus 14 días.
- La regla es **asimétrica**. Cualquier informe con el parser correcto puede **abrir** episodios: lo que dice que está pendiente es real aunque sus metadatos sean viejos (como mucho, la lista está incompleta). Solo un **informe de confianza** (parser correcto y metadatos recientes) puede **cerrarlos**: que un paquete no aparezca solo es fiable con metadatos recientes. Si se borran las listas (`/var/lib/apt/lists`), `apt` no lista nada y el host parecería parcheado sin haber instalado nada. Y si solo los informes de confianza abrieran episodios, un host con el refresco de `apt` roto durante semanas saldría «no data» con parches de seguridad pendientes a la vista.
- Al llegar el **primer informe de confianza**, los episodios que sigan abiertos sin fecha de aviso se marcan «pending before enrollment». Sus relojes no se reinician: guardan la primera vez que el servidor los vio.
- Los relojes **solo retroceden**. Si llega una candidata de seguridad con un aviso anterior al `pending_since` del episodio, `security_since` retrocede y arrastra a `pending_since`, que nunca es posterior a `security_since`.

## Por qué el aviso no es una tabla global

Sería natural tener una tabla `advisory` compartida: `RHSA-2026:1234`, fecha tal. Pero la fecha la envía el agente, y un host comprometido podría mandar una fecha falsa. Si la tabla fuera global, ese host cambiaría el «pending since» de **todos** los demás. Por eso el aviso se guarda por observación (por candidato de cada host): un host solo puede estropear sus propios datos.

## Excepciones como código

Una excepción relaja la política. El ADR 0019 dice que la web no puede relajar la política, así que las excepciones van en el mismo fichero que la política: fecha de fin obligatoria, duración máxima (90 días por defecto) y referencia al `id` del host, que nunca cambia ni se reutiliza. El nombre o una etiqueta podrían cambiar o pasar a otro host sin que nadie se diera cuenta de que la excepción se ha ido con ellos. Cada transición de estado guarda una copia de las excepciones aplicadas, para que un auditor vea qué excepción tapaba un incumplimiento aunque ya haya caducado.

## Buenas prácticas del modelo

Cada punto, con lo que se rompería sin él:

- **Informes en orden y de uno en uno por host.** Un portátil apagado envía al encenderse un informe viejo que se quedó en reintentos, justo después de uno nuevo. Sin orden, el viejo «reabriría» paquetes ya instalados. Sin bloqueo por host, dos informes simultáneos abrirían dos episodios para el mismo paquete.
- **La evaluación de la política es una función pura.** Si la ingesta, la lectura y el planificador calcularan el estado cada uno a su manera, el panel diría «out of policy» y la alerta no saltaría, o al revés. Con `now` como parámetro, además, se prueba sin esperar 14 días: se pasa una fecha.
- **El historial solo crece.** Si un episodio resuelto se reabriera, el tiempo de exposición del primero se perdería y el informe de cumplimiento de una fecha pasada cambiaría después de entregarlo al auditor.
- **Tokens con HMAC-SHA-256, no bcrypt.** bcrypt y Argon2 son lentos a propósito para que adivinar una contraseña corta cueste mucho. Un token aleatorio de 256 bits no se puede adivinar, y la lentitud solo serviría para que 200 agentes por hora cargaran la CPU del servidor. La clave del servidor hace que una copia de la base de datos sola no permita comprobar tokens. La parte pública evita recorrer la tabla, y la comparación en tiempo constante evita deducir el secreto midiendo cuánto tarda en fallar.
- **El servidor no compara versiones.** En Debian `1.0~rc1` es *menor* que `1.0`, y en RPM una época `1:` gana a cualquier versión sin época. Si el servidor ordenara versiones con su propia lógica, se equivocaría en esos casos y contradiría al gestor del host, que es la fuente de verdad.
- **Claves primarias UUIDv7 del servidor.** Si `report_id` (del agente) fuera la clave primaria, un agente malicioso podría enviar el ID de un informe de otro host y hacer que el servidor descartara ese informe como duplicado. Por eso `report_id` es único solo dentro de su host. UUIDv7 lleva la fecha al principio, así que los índices se llenan en orden y no se fragmentan como con UUIDv4.
- **`timestamptz` en UTC y prefijo `agent_`.** Un host con el reloj mal pondría fechas falsas; si no se distingue `agent_last_boot_at` de `received_at`, alguien acabaría usando el reloj del host para una regla de la política.
- **NOT NULL y CHECK.** Sin ellos, un fallo del código guardaría un episodio resuelto antes de abrirse (`resolved_at < first_seen_at`) y el tiempo de exposición saldría negativo. La base de datos es la última barrera.
- **Texto con CHECK en vez de enum.** Quitar o renombrar un valor de un enum de PostgreSQL obliga a recrear el tipo; cambiar un CHECK es una migración normal.
- **ON DELETE RESTRICT y hosts retirados.** Con `CASCADE`, borrar un host por error se llevaría su historial entero sin aviso. Con RESTRICT, la base de datos se niega.
- **jsonb solo para copias que se muestran.** Si el estado estuviera dentro de un jsonb, la vista de flota no podría usar un índice normal y las consultas serían frágiles. `reasons` y `held_packages` solo se enseñan, no se filtran.
- **Un índice por consulta principal, comprobado con EXPLAIN.** Sin el índice parcial de episodios abiertos, abrir el detalle de un host recorrería todos los episodios de 90 días de toda la flota; y nada impediría dos episodios abiertos para el mismo paquete.
- **Validación en tres capas.** El esquema de entrada rechaza un informe mal formado con un `400` claro; el dominio impide reglas imposibles; la base de datos para lo que se escape de las dos. Si solo existiera la última, el usuario vería un error 500 en vez de un mensaje útil.

## Cómo se usa en este repo

- `docs/product/domain-model.md` es la referencia: el esquema de Drizzle de la fase 3 sale de ahí, y si hay que cambiar una regla se cambia primero el documento.
- La política (`docs/product/policy.md`) define los relojes y los estados; el modelo dice dónde se guardan.
- El orden de los informes (la regla) está en el modelo; el mecanismo (por ejemplo, una secuencia del agente) se define en el protocolo del paso 5.
