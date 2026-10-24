# Personas, casos de uso y criterios de aceptación

## Qué problema resuelve

Sin escribir para quién es el producto, se diseña para uno mismo. PatchConi nace del homelab del mantenedor, pero es un producto público: si solo funcionara con mis VMs, sin proxy y en español, no serviría a nadie más. Las personas, los casos de uso y los criterios de aceptación obligan a pensar en otros antes de escribir código.

## Las piezas

- **Persona:** un usuario ficticio pero concreto (nombre, tamaño de flota, restricciones). En `docs/product/vision.md` hay tres: Sam (sysadmin en una empresa pequeña, detrás de un proxy), Alex (homelab, máquinas que se apagan) y Robin (revisor de solo lectura). Cada una tira del diseño en una dirección: Sam pide proxy, CA propia y evidencias; Alex pide que apagar una máquina no sea una alarma; Robin pide historial y un rol que no pueda cambiar nada.
- **Caso de uso (UC):** algo que una persona quiere conseguir, en una frase y sin hablar de pantallas ni de tecnología. «Ver qué hosts incumplen la política y por qué», no «una tabla con filtros».
- **Criterio de aceptación (AC):** una condición comprobable que dice cuándo una funcionalidad está terminada. Tiene que poder convertirse en una prueba: «un token revocado recibe `401` en el siguiente informe» se prueba; «los tokens son seguros» no.
- **No-objetivos:** lo que el producto no hará nunca (instalar parches, conexiones entrantes). Escribirlo evita discutirlo en cada fase.
- **Roadmap:** lo que no entra en la v0.1.0 va a `docs/product/roadmap.md` o a una issue, nunca al alcance. Así el MVP no crece solo.

## Cómo se usan en este repo

- Cada AC tiene un identificador (`AC-2.3`) para citarlo en pruebas, PRs e issues.
- En la fase 4 los AC de ingesta se convierten en pruebas de la API; en la fase 6 la demo de Playwright recorre los UC principales.
- La matriz de soporte tiene tres niveles: «supported» (debería funcionar), «tested in CI» (probado en cada PR) y «best effort» (versiones sin soporte del fabricante: el agente al menos informa del SO, para que el host salga «out of policy» y no «no data»). Empezamos con una distribución por familia en la CI (Ubuntu 24.04, Debian 13, Rocky 10) y el resto sube de nivel sin código nuevo.
- La política (`docs/product/policy.md`) define los estados. Cada umbral por defecto lleva su razonamiento o una referencia comprobable (CIS 7.3, PCI DSS 6.3.3, CISA BOD 26-04), no un número inventado.

## Posicionamiento: por qué «solo lectura» no basta

Patchman ya es de solo lectura y PatchMon ya tiene agentes que inician la conexión. Decir «somos de solo lectura» no distingue a PatchConi. Lo que lo distingue está en `vision.md` («What PatchConi is not, and how it fits»):

- mide el cumplimiento de un SLA (cuánto tiempo lleva pendiente cada cosa frente a una política declarada);
- la verdad la da el gestor de paquetes del host, no una resolución en el servidor;
- el «solo lectura» se puede comprobar (`--dry-run`, sin root, servidor sin credenciales, artefactos firmados);
- se opera como software cloud native (política como código, Prometheus, OpenAPI).

PatchConi no parchea: se integra con quien parchea (Ansible, AWX) y verifica que el parcheo ocurrió.

## Errores típicos

- Personas que son uno mismo con otro nombre.
- Criterios que no se pueden probar («rápido», «fácil», «seguro»).
- Meter en el MVP cada idea buena en vez de mandarla al roadmap.
- Umbrales copiados de una norma sin entender a quién se aplica: la de CISA es para agencias federales de EE. UU. y distingue por riesgo; nosotros aún no conocemos el riesgo de cada CVE, por eso usamos un umbral intermedio.

## Preguntas de entrevista

1. **¿Por qué tres personas y no una?** Porque cada una impone requisitos distintos (proxy y evidencias, máquinas apagadas, solo lectura) que un diseño para una sola no cubriría.
2. **¿Qué diferencia hay entre un caso de uso y un criterio de aceptación?** El caso de uso dice qué quiere conseguir alguien; el criterio dice cómo comprobamos que el producto lo consigue. El primero guía el diseño y el segundo, las pruebas.
3. **¿Desde cuándo cuenta el reloj de la política?** Si el gestor da la fecha del aviso (dnf updateinfo), desde la más antigua entre esa fecha y la primera vez que el servidor vio la actualización. Si no la da (apt), desde la primera vez que se vio, medida con el reloj del servidor, que no depende de los relojes de los hosts. Para que un host con meses sin parchear no pase 14 días «en plazo» solo por darse de alta, lo que ya estaba pendiente en su primer informe fiable (con metadatos recientes) se marca como «pending before enrollment, real age unknown», y el panel y el detalle lo muestran.
