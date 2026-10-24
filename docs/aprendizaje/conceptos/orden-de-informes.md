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
- El servidor decide, con un bloqueo por host, según la instancia:
  - **Instancia nueva** con la huella conocida: es una reinstalación en la misma máquina. Se aplica y pasa a ser la actual.
  - **Instancia actual** con secuencia mayor: se aplica.
  - **Instancia actual** con secuencia menor o igual (`sequence_regression`): se guarda sin aplicar. Uno suelto es un reintento tardío; dos seguidos huelen a snapshot restaurado o a directorio de estado copiado, y salta una alerta.
  - **Instancia ya vista** que ya no es la actual (`superseded_instance`): alerta inmediata. Si alguien con el token robado se inventa una instancia nueva, la suya pasa a ser la actual y el agente legítimo cae aquí. Sin esta alerta, el host real quedaría silenciado sin que nadie lo notara.
- Las instancias se guardan en su propia tabla (`agent_instance`), que dura lo mismo que el host. Si la regla «ya vista» consultara la tabla de informes, la retención de 90 días borraría la prueba, y un informe muy tardío de una instalación antigua se aplicaría como si fuera nuevo.

Es la misma idea que los números de secuencia de TCP o el `resourceVersion` de Kubernetes: un contador que pone el emisor y que solo crece, en lugar de relojes.

## Idempotencia con `report_id`

Los reintentos envían los mismos bytes, y por tanto el mismo `report_id`. El servidor guarda el SHA-256 del cuerpo. Si guardó el informe pero la respuesta se perdió, el reintento llega con el mismo hash y recibe `200` («ya lo tenía»), sin guardarse dos veces (AC-2.4). El mismo `report_id` con otro cuerpo es un fallo o una falsificación: `409`, y el agente no reintenta. Un informe nuevo recibe `201`.

Si el servidor pide esperar (`Retry-After`) más allá de la siguiente ejecución del timer, el agente no espera: el informe siguiente lo sustituye, porque no hay cola en disco.

Los reintentos (en `429`, `5xx` o sin respuesta) usan **backoff exponencial con jitter**: esperas que crecen (2 s, 4 s, 8 s…), con un valor aleatorio dentro de cada una. Sin el azar, todos los hosts que perdieron el servidor a la vez reintentarían a la vez y lo tumbarían otra vez al volver.

## La huella de la máquina

`machine_fingerprint` sale de `/etc/machine-id`, pero no se envía el ID en bruto. `systemd-id128 machine-id --app-specific=<UUID fijo>` calcula un HMAC-SHA-256 del ID de la aplicación usando el machine-id como clave. Lo comprobamos en Ubuntu 24.04 comparándolo con un cálculo en Python. Así, cada aplicación ve un ID distinto de la misma máquina, y no se pueden cruzar entre sí.

Para qué sirve: la primera huella que llega queda como la **huella conocida** del host. Un informe con otra huella, sea de la instancia que sea, viene de otra máquina con el mismo token (copiado, o de un clon con machine-id nuevo): no se aplica y salta una alerta.

Una reinstalación que crea un machine-id nuevo da una falsa alarma. El administrador la resuelve rotando el token: así borra la huella conocida, la siguiente queda como nueva, y de paso deja fuera a quien tuviera el token viejo.

Su límite: un clon de la VM que conserva el machine-id y el directorio de estado no se detecta.

## Cómo se usa en este repo

- Las reglas para el agente: `docs/product/protocol.md` (secciones «Ordering and identity» y «Responses»).
- La parte del servidor: `docs/product/domain-model.md` (invariante 1, entidad `agent_instance`, `not_applied_reason`).
