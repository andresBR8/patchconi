# Plan de PatchConi

> Versión operativa del plan. La discusión completa y los porqués están en el documento «Plan maestro — Panel de parches» del chat de revisión. Cuando el plan cambie, se actualiza este fichero en el mismo paso.

## Qué es

PatchConi es un panel autoalojado de cumplimiento de parches para flotas Linux pequeñas. Un agente de solo lectura en cada host informa de sus actualizaciones pendientes, y la web muestra qué va atrasado, desde cuándo y quién incumple la política. Es un producto genérico y público: cualquiera lo instala con Docker Compose o Kubernetes. El homelab de Andrés es su primer cliente, no su dependencia.

### Principios

1. **Solo observa.** El agente nunca instala nada ni ejecuta órdenes remotas.
2. **Mínimo privilegio.** Agente sin root y token por host revocable.
3. **El host inicia la conexión** por HTTPS; el servidor nunca entra en las máquinas.
4. **Tolera equipos que se apagan.** Nada depende de tareas nocturnas.
5. **Fácil de autoalojar.** Compose en menos de 15 minutos y manifiestos de Kubernetes.
6. **Observable de serie.** Métricas Prometheus y logs JSON.

### MVP v0.1.0

| Prioridad | Funcionalidad | Qué incluye |
| --- | --- | --- |
| Imprescindible | Alta de hosts y tokens | Token mostrado una vez, guardado con hash, rotación y revocación |
| Imprescindible | Ingesta de informes | Endpoint `v1`, validación estricta, límites de tamaño y frecuencia |
| Imprescindible | Panel de flota | Hosts al día, con pendientes, fuera de política o sin informar |
| Imprescindible | Detalle e historial | Paquetes pendientes, avisos de seguridad, kernel, último reinicio |
| Imprescindible | Usuarios | Login, roles administrador y lector, primer admin al arrancar |
| Importante | Política y avisos | Umbrales configurables y webhook genérico sin duplicados |
| Importante | Métricas | `/metrics` y dashboard de Grafana en el repo |

Si el calendario aprieta, las filas «Importante» pasan a la v0.2.0.

**Fuera de la v1:** instalar parches o ejecutar órdenes remotas; Windows y macOS; SaaS multiempresa; enriquecimiento con bases de CVE (candidato a v0.2.0).

**Objetivos no funcionales** (se validan en la fase 4): 200 hosts informando cada hora con menos de 512 MB entre API y base de datos; p95 de la API por debajo de 300 ms; imágenes de menos de 200 MB; arranque en menos de 10 s; historial de 90 días configurable.

## Decisiones aceptadas

Cada una se convierte en un ADR en `docs/adr/` durante la fase 0.

| # | Decisión | Elección |
| --- | --- | --- |
| 1 | Repositorio | Monorepo con workspaces de pnpm; agente como módulo Go aparte |
| 2 | Herramientas | `mise` fija Node, pnpm, Go y linters por repo |
| 3 | Web | React + Vite, estáticos servidos por nginx sin root |
| 4 | ORM | Drizzle |
| 5 | Usuarios | Better Auth sobre PostgreSQL |
| 6 | Auth de agentes | Token por host con prefijo identificable, guardado con hash |
| 7 | Agente | Go, solo lectura, temporizador de systemd |
| 8 | Contratos | OpenAPI generada por la API y comprobada en CI; salidas reales del agente como fixtures |
| 9 | Tareas periódicas | Planificador dentro de la API con bloqueo consultivo de PostgreSQL |
| 10 | Distribución | GHCR con firma cosign, SBOM y procedencia; GoReleaser para el agente |
| 11 | Despliegue | Compose de ejemplo y base de Kustomize; Helm más adelante |
| 12 | Licencia | Apache-2.0 |
| 13 | Idioma | Producto, código y commits en inglés; `docs/aprendizaje/` en español |
| 14 | Visibilidad | Repo público desde el primer commit |
| 15 | Flujo de Git | Rama por paso y PR con CI obligatoria; squash merge |

El nombre del producto es **PatchConi**; el nombre técnico (repo, imágenes, binario) es `patchconi`.

## Frontera con la plataforma

La app publica artefactos versionados: imágenes, paquetes del agente, base de Kustomize, Compose de ejemplo y rol de Ansible genérico. La plataforma (el homelab) pone el overlay del entorno, el namespace, Argo CD, los Secrets, el túnel, la NetworkPolicy, el inventario y los tokens. Si para desplegar hay que tocar este repo, el contrato ha fallado.

- Contrato: `docs/platform-contract.md`.
- Ficha de alta para la plataforma: `docs/deployment.md` (se crea en la fase 2).

## Definición de terminado

Una fase está terminada cuando cumple los ocho puntos; si falta uno, no empieza la siguiente. `/close-phase` los recorre.

1. Todos los criterios de salida demostrados con un comando o una captura.
2. CI en verde en `main`.
3. `pre-commit run --all-files` limpio y ningún secreto en el historial.
4. Pruebas nuevas para lo nuevo; ninguna desactivada sin una issue abierta.
5. Documentación al día: README si cambia el uso, un ADR por decisión, conceptos nuevos explicados.
6. Revisión hecha por el subagente `reviewer`, por el chat de revisión y por Andrés.
7. Andrés puede explicar con sus palabras cada pieza de la fase.
8. `PROGRESO.md` actualizado y el milestone de la fase cerrado en GitHub.

## Fases

| Fase | Nombre | Fines de semana | Puerta de salida |
| --- | --- | --- | --- |
| 0 | Cimientos | 1 | Herramientas, CI de higiene y ADRs |
| 1 | Producto y diseño | 1–2 | Visión, protocolo y amenazas aprobados |
| 2 | Esqueleto andante | 2 | El esqueleto pasa toda la CI y arranca en kind |
| 3 | Datos y usuarios | 2 | Auth probada de extremo a extremo |
| 4 | Hosts e ingesta | 2 | Prueba de carga y contrato en CI |
| 5 | Agente en Go | 2–3 | Informa desde Ubuntu y Rocky sin root |
| 6 | Interfaz web | 2 | Demo completa automatizada en CI |
| 7 | Política, avisos y métricas | 1–2 | Avisos y métricas probados |
| 8 | Release v0.1.0 | 1–2 | Release firmada e instalación desde la doc |
| 9 | Alta en el homelab | — | La app corre por GitOps sin tocar este repo |

### Fase 0 · Cimientos

**Objetivo:** repo y herramientas listos, sin una línea de producto.

- Repo público, deploy key configurada solo en este repo (`core.sshCommand`) y carpeta `~/apps/patchconi`.
- Sandbox de Claude Code activo y comprobado, sin acceso a Docker.
- `CLAUDE.md`, `.claude/settings.json`, reglas, subagentes y skills (vienen del bootstrap).
- `mise` con Node LTS, pnpm, Go y linters; workspace de pnpm endurecido (scripts de dependencias bloqueados salvo lista blanca, `minimumReleaseAge` de 3 días).
- pre-commit con gitleaks, `.editorconfig`, `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md` y README esqueleto.
- Workflow de higiene (pre-commit + actionlint) con actions fijadas por SHA; Renovate; reglas de rama en `main`; milestones 0–9.
- Un ADR por cada decisión aceptada.

**Criterios de salida:** un clon limpio funciona con `mise install && pnpm install`; la CI pasa en verde; Claude Code arranca, resume el estado en 3 líneas y se ha comprobado que no puede leer `~/homelab` ni `~/.ssh` ni conectar con el socket de Docker.

### Fase 1 · Producto y diseño

- Visión, casos de uso y criterios de aceptación del MVP.
- Modelo de dominio (diagrama entidad-relación).
- Protocolo agente→servidor v1: borrador de OpenAPI y ejemplos capturados de VMs Ubuntu y Rocky.
- Definición de la política: «al día», «fuera de política» y «sin datos».
- Modelo de amenazas v1 (STRIDE ligero) y arquitectura C4 (contexto y contenedores).
- Bocetos de las cuatro pantallas principales y notas sobre PatchMon.

**Criterios de salida:** documentos aprobados; los ejemplos validan contra el esquema; ninguna pregunta abierta sin issue.

### Fase 2 · Esqueleto andante

- **Antes de empezar:** subir Node de 24 a 26 LTS (LTS desde el 28-oct-2026) en `mise.toml` y `engines.node`. La fase 0 fijó Node 24.22.0 porque la 26 aún no era LTS.
- API mínima: `/healthz`, `/readyz`, `/api/v1/version`, configuración validada, logs JSON y apagado limpio.
- Web mínima que muestra la versión de la API y el estado de la base de datos.
- Dockerfiles multietapa sin root y compatibles con sistema de ficheros de solo lectura.
- Compose con PostgreSQL, API, web y Caddy.
- CI completa: lint, pruebas, build, Trivy, SBOM y push a GHCR por digest desde `main`.
- Base de Kustomize con overlay de ejemplo, Job de migraciones y `docs/deployment.md` v0.
- Decidir cómo tratar la plantilla `.env.example`: las reglas `deny` de `.env.*` también la bloquean y no admiten excepciones con `!`.
- ADR sobre Docker en desarrollo: Claude Code no tiene acceso a Docker porque equivale a root en vm-dev; tú ejecutas `docker` y `kind`, y la CI hace el resto.

**Criterios de salida:** `docker compose up` muestra la versión y «DB ok»; imágenes en GHCR con digest; manifiestos validados y arrancados en kind dentro de la CI; Trivy sin críticas; CI de menos de 10 minutos.

### Fase 3 · Datos y usuarios

- Esquema de Drizzle y migraciones como comando aparte.
- Better Auth con email y contraseña, sesión en cookie, primer admin al arrancar.
- Roles administrador y lector; límite de intentos en el login.
- Pruebas de integración con Testcontainers.

**Criterios de salida:** login, logout y roles probados de extremo a extremo; migraciones idempotentes; estrategia expand/contract documentada; modelo de amenazas actualizado.

### Fase 4 · Hosts e ingesta

- Alta, rotación y revocación de tokens.
- Ingesta v1 con validación, tamaño máximo, límite por token e idempotencia.
- Política evaluada al recibir y al consultar.
- Agente falso para desarrollo y demos; pruebas de contrato con los ejemplos de la fase 1.
- OpenAPI en el repo, comprobada en CI.

**Criterios de salida:** la prueba de carga con k6 cumple los objetivos no funcionales; la CI falla si la OpenAPI cambia sin actualizarse.

### Fase 5 · Agente en Go

- Recolectores de `apt` y `dnf` con pruebas golden sobre salidas reales.
- Configuración, token con permisos 0600 y comandos `report`, `check` y `version`.
- Servicio y temporizador de systemd con retardo aleatorio; usuario dedicado.
- Matriz de CI por distribución y snapshot de GoReleaser (amd64, arm64, `.deb`, `.rpm`).
- Guía de instalación con tres caminos (paquete, `install.sh` con checksums y rol de Ansible genérico), ejecutada en la CI.

**Criterios de salida:** el agente informa contra Compose desde Ubuntu 24.04 y Rocky 10 sin root; lo básico de Go queda explicado en `conceptos/`.

### Fase 6 · Interfaz web

- Login, panel de flota, lista de hosts con filtros y detalle con historial.
- Alta de host con el comando de instalación y el token visible una sola vez.
- Ajustes de política y gestión de usuarios; cliente tipado desde la OpenAPI.

**Criterios de salida:** la demo completa (alta, informe, panel e incumplimiento) corre con Playwright en la CI; el README tiene capturas.

### Fase 7 · Política, avisos y observabilidad

- Motor de política con umbrales y planificador con bloqueo consultivo.
- Webhook con enfriamiento y sin duplicados.
- `/metrics` de baja cardinalidad documentado, dashboard de Grafana e ID de petición en los logs.

**Criterios de salida:** prueba de extremo a extremo con un receptor de webhooks falso; el dashboard se importa sin errores.

### Fase 8 · Release v0.1.0

- release-please: versión, CHANGELOG y release desde Conventional Commits.
- Imágenes firmadas con cosign sin claves, con SBOM y procedencia.
- Release del agente con GoReleaser y script de instalación que verifica checksums.
- Documentación de usuario y guía de desarrollo completas.

**Criterios de salida:** v0.1.0 publicada; `cosign verify` documentado y funcionando; servidor y agente instalados en una VM limpia siguiendo solo la documentación en menos de 15 minutos; un clon limpio levanta el entorno de desarrollo siguiendo la guía.

### Fase 9 · Alta en el homelab

Cuando el homelab tenga sus fases 11–12 (Argo CD, GHCR, túnel).

- Ficha de alta final en `docs/deployment.md`.
- En la sesión del homelab: namespace, `Application` de Argo CD con overlay que referencia la base en `v0.1.0`, Secrets, ruta del túnel y playbook con el rol del agente.

**Criterios de salida:** la app corre en el clúster por GitOps; las VMs del lab informan; este repo no necesitó ningún cambio.

### Después de la v0.1.0

Helm chart, OIDC/SSO, más gestores de paquetes (zypper, apk, pacman), CVE con OSV, trazas OpenTelemetry e ingesta como microservicio con cola.

## Ritual de cada paso

1. **Arranque:** leer `CLAUDE.md`, `PROGRESO.md` y la fase; resumir el estado en 3 líneas.
2. **Plan** (las sesiones empiezan en modo plan): el paso en 2–6 líneas. Si no es trivial, Andrés lo revisa con el chat.
3. **Implementación** en una rama `phase-NN/<tema>`, con commits pequeños.
4. **Verificación** con la skill `verify` antes de cada commit.
5. **Revisión independiente** con el subagente `reviewer`.
6. **Integración:** Andrés revisa, hace push, abre el PR y fusiona con la CI en verde.
7. **Cierre de fase** con `/close-phase N`.
8. **Contexto limpio:** `/clear` antes del siguiente paso.

## Calendario y riesgos

Con 8–10 h por fin de semana, la v0.1.0 está a 14–18 fines de semana: entre febrero y marzo de 2027 contando Navidad y exámenes. Revisión del plan cada 4 fines de semana.

| Riesgo | Mitigación |
| --- | --- |
| El máster se come las horas | MVP estricto; si vamos tarde, política, avisos y métricas pasan a v0.2.0 |
| Go es nuevo | Fase propia, agente pequeño, conceptos documentados, agente falso para no bloquear la API |
| La IA genera más rápido de lo que se entiende | Nada se fusiona si Andrés no puede explicarlo |
| El producto es un objetivo de ataque | Solo lectura, tokens con hash, límites y modelo de amenazas vivo |
| El homelab aún no tiene Argo CD ni túnel | La app se valida sola con Compose y kind en la CI; la fase 9 espera |
