# Modelo de amenazas con STRIDE (y C4 para dibujarlo)

## Qué es

Un modelo de amenazas responde a cuatro preguntas (las de Adam Shostack): ¿qué estamos construyendo?, ¿qué puede salir mal?, ¿qué hacemos al respecto?, ¿lo hemos hecho bien? En PatchConi son tres ficheros:

- [`docs/architecture.md`](../../architecture.md): qué construimos, en dos diagramas C4.
- [`docs/threat-model.md`](../../threat-model.md): qué puede salir mal y qué hacemos, en una tabla.
- El registro de revisiones del final, que se actualiza al cerrar cada fase: ¿lo hemos hecho bien?

No es una auditoría ni una lista de vulnerabilidades. Es un documento de diseño: se escribe antes del código, para que las decisiones de seguridad se tomen a propósito y no por accidente.

## C4 en cuatro líneas

C4 dibuja un sistema a cuatro zooms: **contexto** (el sistema como una caja, con personas y sistemas externos), **contenedores** (las piezas que se ejecutan por separado: SPA, API, base de datos, agente), componentes y código. Usamos los dos primeros: bastan para ver por dónde entra y sale cada dato. Mermaid tiene un tipo `C4Context`, pero su documentación lo marca como experimental, así que dibujamos con `flowchart` y la notación de C4 (tipo entre corchetes, flechas en el sentido en que se abre la conexión).

## Fronteras de confianza

Una frontera de confianza es el sitio donde un dato pasa de alguien en quien confías menos a alguien en quien confías más. Ahí es donde hay que validar, autenticar y limitar. En PatchConi hay cinco: host → API, navegador → web/API, API → PostgreSQL, API → webhooks y build → datos de ciclo de vida. La más importante es la primera, porque al otro lado hay cientos de máquinas y cualquiera puede estar comprometida.

## STRIDE

Seis categorías, una por letra, cada una lo contrario de una propiedad de seguridad:

| Letra | Amenaza | Propiedad que rompe | Ejemplo en PatchConi |
| --- | --- | --- | --- |
| S | Spoofing (suplantación) | Autenticación | Usar el token robado de un host desde otra máquina (T-02) |
| T | Tampering (manipulación) | Integridad | Un host comprometido que dice estar al día (T-01) |
| R | Repudiation (repudio) | No repudio, trazabilidad | Un admin limpia una alerta y nadie sabe quién fue (T-11) |
| I | Information disclosure (divulgación) | Confidencialidad | El panel expuesto a Internet: un mapa de hosts vulnerables (T-08) |
| D | Denial of service | Disponibilidad | Perder la clave HMAC: todos los tokens dejan de valer (T-13b) |
| E | Elevation of privilege | Autorización | Un nombre de paquete con un `<script>` que se ejecuta con la sesión del admin (T-05) |

«Ligero» significa que no hacemos el árbol completo de cada amenaza ni puntuamos con DREAD o CVSS: recorremos cada frontera con las seis letras y apuntamos lo que importa. Cada amenaza lleva **una** categoría, la del objetivo del atacante. Por eso T-05 es E y no T: el XSS es el medio, lo que gana el atacante es actuar con la sesión de otro.

## Cómo se lee la tabla

Cada fila tiene un ID estable (T-NN, nunca se reutiliza), la categoría, la amenaza, la mitigación con un enlace al documento que la define y un estado:

- **By design:** la regla está decidida y escrita; si aún no está construida, se nombra la fase.
- **Planned (phase N):** se sabe qué hacer, los detalles se deciden en esa fase.
- **Accepted risk:** no lo mitigamos, y lo explicamos.
- **Issue #N:** no hay decisión. La issue guarda la pregunta. Es el criterio de salida de la fase 1: ninguna pregunta abierta sin issue.

El modelo no copia las reglas: enlaza al ADR, al protocolo o al modelo de dominio. Si copiara, con el tiempo habría dos versiones distintas de la misma regla.

## Por qué un riesgo aceptado no es un fallo

T-01: un host comprometido puede mentir sobre sus paquetes. Ningún agente que se autodeclara puede evitarlo, porque la prueba y el mentiroso son la misma máquina. Ponerlo como «mitigado» sería mentir en el propio modelo. Lo honesto es aceptarlo, explicar el límite (el panel muestra lo que los hosts *dicen*) y acotar el daño: un host que miente solo cambia sus propios datos (T-04, T-23), nunca los de otros hosts ni el servidor.

Lo mismo con T-02: un clon que conserva `/etc/machine-id` y el directorio de estado es indistinguible del original. Distinguirlo exigiría un secreto que no se pueda copiar: una clave que no se pueda exportar, como una guardada en un TPM. mTLS por sí solo no basta, porque un clon del disco copia también la clave privada del certificado; mTLS con la clave en un TPM, sí. Eso queda para la v2.

## Cómo defenderlo en una entrevista

- **«¿Cómo hiciste el modelo de amenazas?»** Dibujé el contexto y los contenedores con C4, marqué cinco fronteras de confianza y recorrí cada una con STRIDE. Cada amenaza enlaza a la decisión que la mitiga o a una issue abierta, y el modelo se revisa al cerrar cada fase.
- **«¿Y si el host miente?»** No se puede evitar desde el propio host; es un riesgo aceptado y documentado. Lo que sí garantizo es que un host comprometido no puede tocar nada más que sus datos: el host sale del token y no del cuerpo, los avisos son por host y el texto del informe nunca se interpreta.
- **«¿Por qué HMAC y no bcrypt para los tokens?»** bcrypt y Argon2 son lentos a propósito para proteger contraseñas de poca entropía. Un token aleatorio largo no se puede adivinar, así que basta un hash rápido; la clave del servidor añade que, sin ella, la copia de la base de datos no sirve ni para comprobar tokens. A cambio, esa clave es un secreto más: si se pierde, todos los agentes dejan de funcionar (T-13b). Si compensa o no está abierto en una issue.
- **«¿Qué es lo más peligroso de tu producto?»** El binario del agente, porque se ejecuta en todos los hosts: una release maliciosa llega a toda la flota. Hoy las releases del agente solo llevan checksums, que detectan una descarga corrupta pero no una release maliciosa; firmarlas está en la issue #37. Mientras tanto, el agente sin root limita el daño (T-18, T-20). Y el panel en sí, porque es una lista de qué máquinas atacar (T-08): solo la ruta del agente se expone a las redes de los hosts.
- **«¿Cómo evitas el SSRF de los webhooks?»** La URL viene de la configuración, como la política, nunca de la UI: cambiarla exige ser operador. Además, sin redirecciones, con timeouts y con el egress limitado por NetworkPolicy.
