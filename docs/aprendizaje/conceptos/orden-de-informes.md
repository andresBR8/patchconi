# Ordenar informes sin fiarse del reloj del host

## Qué problema resuelve

Los informes pueden llegar desordenados: un reintento lento llega después del informe siguiente, o un portátil que estaba apagado envía tarde. Si el servidor aplicara un informe viejo después de uno nuevo, «reabriría» paquetes ya instalados. Hay que saber cuál es el último.

## Por qué no sirven las soluciones obvias

- **`collected_at` (la hora del host):** el reloj del host puede estar mal, y la visión lo da por hecho. Un host con la hora adelantada bloquearía todos sus informes siguientes.
- **El orden de llegada:** justo es lo que falla con un reintento lento.
- **Una cola en disco en el agente:** añade estado que se corrompe y se llena. Una ejecución produce un informe; si no se entrega, la siguiente envía el estado actual, que es lo que importa.

## La solución: instancia + secuencia

- La primera vez, el agente crea en su directorio de estado un `agent_instance_id` (UUID aleatorio). Reinstalar, o perder ese directorio, crea otro.
- En cada ejecución toma un `flock`, para que el timer y una ejecución tras instalar paquetes no se solapen. Después suma uno a `sequence`, lo **escribe en disco** y solo entonces envía. Si el envío falla, queda un hueco en la secuencia, y no pasa nada: solo importa que el número crezca.
- El servidor, con un bloqueo por host, aplica el informe si es de la instancia actual con una secuencia mayor, o si es de una instancia que nunca ha visto (una reinstalación). Un informe de una instancia ya vista pero que ya no es la actual llega tarde, de antes de la reinstalación: se guarda sin aplicar.
- Las instancias se guardan en su propia tabla (`agent_instance`), que dura lo mismo que el host. Si la regla «ya vista» consultara la tabla de informes, la retención de 90 días borraría la prueba, y un informe muy tardío de una instalación antigua se aplicaría como si fuera nuevo.

Es la misma idea que los números de secuencia de TCP o el `resourceVersion` de Kubernetes: un contador que pone el emisor y que solo crece, en lugar de relojes.

## Idempotencia con `report_id`

Los reintentos envían el mismo `report_id`. Si el servidor guardó el informe pero la respuesta se perdió, el reintento recibe `200` («ya lo tenía») en vez de un error, y no se guarda dos veces (AC-2.4). Un informe nuevo recibe `201`.

Los reintentos (en `429`, `5xx` o sin respuesta) usan **backoff exponencial con jitter**: esperas que crecen (2 s, 4 s, 8 s…), con un valor aleatorio dentro de cada una. Sin el azar, todos los hosts que perdieron el servidor a la vez reintentarían a la vez y lo tumbarían otra vez al volver.

## La huella de la máquina

`machine_fingerprint` sale de `/etc/machine-id`, pero no se envía el ID en bruto. `systemd-id128 machine-id --app-specific=<UUID fijo>` calcula un HMAC-SHA-256 del ID de la aplicación usando el machine-id como clave. Lo comprobamos en Ubuntu 24.04 comparándolo con un cálculo en Python. Así, cada aplicación ve un ID distinto de la misma máquina, y no se pueden cruzar entre sí.

Para qué sirve: si una instancia conocida aparece con otra huella, alguien ha copiado el directorio de estado, y con él el token, a otra máquina. Ese informe no se aplica y el host muestra una alerta.

Su límite: un clon de la VM que conserva el machine-id no se detecta.

## Cómo se usa en este repo

- Las reglas para el agente: `docs/product/protocol.md` (secciones «Ordering and identity» y «Responses»).
- La parte del servidor: `docs/product/domain-model.md` (invariante 1, entidad `agent_instance`, `not_applied_reason`).
