# GitHub Actions por SHA, la CI de higiene y Renovate

## Por qué fijar las actions por SHA

`uses: actions/checkout@v7` apunta a una **etiqueta**, y una etiqueta se puede mover: quien controle el repo de la action (o robe su cuenta) puede hacer que `v7` apunte a otro código, y tu CI lo ejecutará con tu token. Ya vimos una etiqueta movida en gitleaks (nota `mise.md`).

`uses: actions/checkout@3d3c42e5… # v7.0.1` apunta a un **commit**: su SHA es el hash del contenido y no se puede reescribir. El comentario dice qué versión es, para personas y para Renovate.

## El workflow `hygiene.yml`

| Pieza | Por qué |
| --- | --- |
| `on: pull_request` y `push` a `main` | Comprueba cada PR y lo que llega a `main`. Nunca `pull_request_target`, que ejecuta con secretos el código de una rama ajena |
| `permissions: contents: read` | El `GITHUB_TOKEN` solo puede leer el repo |
| `runs-on: ubuntu-24.04` | Versión fija de runner, no `ubuntu-latest`, que cambia sola |
| `timeout-minutes: 10` | Un job colgado no consume horas |
| `concurrency` | En un PR, un push nuevo cancela la ejecución anterior; en `main`, no se cancela |
| checkout con `persist-credentials: false` | No deja el token guardado en `.git/config` para los pasos siguientes |
| checkout con `fetch-depth: 0` | Trae todo el historial. Con el valor por defecto (1 commit), `gitleaks-history` daría un falso verde |
| `jdx/mise-action` con `version` y `sha256` | Instala mise 2026.10.7 y compara el binario con el hash fijado. Con `sha256`, la action **solo** compara ese hash; la verificación del `SHASUMS256.txt` firmado con minisign solo se hace cuando no se le pasa hash (`verifyDownloadedMiseAsset` en su código). Después ejecuta `mise install --locked` (lo añade sola al ver `mise.lock`) |
| Paso «Check that mise exports [env]» | Falla si `PIP_UPLOADED_PRIOR_TO` no llega. La documentación de mise-action dice que exporta `[env]` (`env: true`), pero la CI lo **comprueba** en vez de fiarse |
| `pre-commit run --all-files` | Los mismos hooks que en tu portátil, con `end-of-file-fixer` completo (en la CI no hay `SKIP`) |
| zizmor online | Auditorías con la API de GitHub: «impostor commits» (un SHA que no pertenece al repo de la action, sino a un fork) y actions con vulnerabilidades conocidas. Usa el token de solo lectura |

El `sha256` del binario de mise viene de dos fuentes independientes que coinciden: el `SHASUMS256.txt` de la release (que lista el binario suelto con su hash) y el binario que ya estaba instalado en la VM de desarrollo, que se instaló por otro camino, fuera de este repo.

La caché de mise-action está activada: guarda las herramientas instaladas, entre ellas el gitleaks compilado. Una caché restaurada no se vuelve a verificar contra `mise.lock` (`--locked` no reinstala lo que ya existe). El riesgo es bajo: la caché de `main` solo la escribe `main` y la de un PR se queda en su rama. Compensa frente a compilar gitleaks en cada ejecución.

Comprobado en local: actionlint (con shellcheck) y zizmor, también en modo `pedantic`, no encuentran nada en el workflow. Una copia con `actions/checkout@v7` hace saltar a zizmor con `unpinned-uses` (gravedad alta).

## Renovate

Una app de GitHub que abre PRs cuando sale una versión nueva de algo fijado: las actions (por SHA, con el comentario de versión), `mise.toml` y `mise.lock`, `package.json` y `pnpm-lock.yaml`, y las `additional_dependencies` de pre-commit.

`renovate.json`:

- **`config:best-practices`:** entre otras cosas, fija por digest las actions y las imágenes.
- **`:enablePreCommit`:** el gestor de pre-commit viene desactivado por defecto. Solo actualiza las `additional_dependencies` de hooks con `language: python` explícito (comprobado en su código fuente), y por eso lo llevan los 8 hooks.
- **`minimumReleaseAge: "3 days"`:** no abre PR hasta que la versión tenga 3 días. Es la misma regla que aplicamos a mano. `internalChecksFilter: "strict"` y `dependencyDashboard: true` ya son los valores por defecto; están escritos para que se vean.
- **`schedule`:** los sábados por la mañana (UTC), para agrupar el trabajo en el fin de semana. `lockFileMaintenance` lleva el mismo calendario, porque `config:best-practices` le pone el suyo (los lunes de madrugada) y tendría prioridad.
- **Grupo pnpm:** pnpm está fijado en `mise.toml` (paquete `pnpm/pnpm` vía aqua) y en `packageManager` (paquete `pnpm` de npm). Van en un solo PR para que no se separen.
- **Node:** solo versiones pares, que hoy son las que pasan a LTS. Los PR de una versión mayor nueva llevan la nota «Do not merge before this version is LTS (Node 26: 2026-10-28)», porque una par no es LTS desde el primer día; los parches de la 24 no la llevan.
  - **Revisar antes de abril de 2027:** según el calendario oficial (`nodejs/Release`), la 27 sale el 22-abr-2027 con soporte hasta 2030. Node cambia de modelo de versiones y la regla de «solo pares» puede dejar de servir.
- **gitleaks:** el PR solo se abre cuando lo apruebas en el panel de dependencias. Renovate cambiaría `version` pero no el `Version=` de los `ldflags`, y además hay que repetir la comprobación de la etiqueta frente a proxy.golang.org.
- **mise en el workflow:** Renovate conoce `jdx/mise-action` (lo vi en su código: lee `version` como la dependencia `jdx/mise` y `sha256` como su digest) y propone subir los dos juntos. También va con aprobación en el panel, para que la CI no se adelante a la mise de la VM de desarrollo: se aprueba cuando se suba allí.
  - La `version` lleva la «v» (`v2026.10.7`) porque Renovate busca la release por esa etiqueta exacta, y en `jdx/mise` todas empiezan por «v»: con `2026.10.7`, `releases/tags/2026.10.7` daba 404. mise-action quita la «v» por su cuenta (`cleanVersion`).

**Alertas de seguridad:** Renovate abre PRs de seguridad sin esperar al calendario, sin los 3 días y sin pedir la aprobación del panel, ni siquiera para gitleaks. Necesitan las alertas de Dependabot activadas en el repo. Ojo: pnpm sí sigue aplicando sus 3 días (`minimumReleaseAge` estricto), así que un parche de npm de menos de 3 días hará fallar la CI hasta que cumpla. Ver «Saltarse los 3 días».

**Lo que Renovate no hace bien solo:**

- `mise.lock` lo actualiza con `mise lock`, pero lo trata como «ejecución insegura» y lo intenta en el modo seguro de mise. Si no puede, el PR llegará con el lock sin actualizar y la CI fallará en `mise install --locked`. Es el fallo correcto: se arregla con `mise lock` en local, en la rama del PR.

## Saltarse los 3 días para un parche de seguridad urgente

Si una vulnerabilidad grave se arregla en una versión de menos de 3 días y no se puede esperar, la excepción se hace en `pnpm-workspace.yaml`, **solo para esa versión y de forma temporal**:

```yaml
minimumReleaseAgeExclude:
  # TEMPORARY: CVE-AAAA-NNNNN fixed in 1.2.3, published 2026-MM-DD.
  # Remove on 2026-MM-DD (3 days after publication).
  - paquete@1.2.3
```

- **Solo la versión exacta (`paquete@1.2.3`), no el paquete entero:** pnpm 12 admite excluir versiones concretas, así que una 1.2.4 publicada mañana no se cuela por la misma puerta.
- **Con comentario:** el motivo (la CVE) y la fecha en que se quita, que es cuando la versión ya cumple los 3 días y la excepción sobra.
- **En un PR propio, revisado como cualquier cambio de la regla 11:** `pnpm-workspace.yaml` decide qué código se instala.
- **Se quita en la fecha anotada**, con otro PR.

Lo mismo vale para pip (`PIP_UPLOADED_PRIOR_TO` en `mise.toml`) y para las herramientas de mise, pero en esos casos fijamos versiones a mano: basta con fijar la versión del parche y explicar la excepción en el PR.

## Permisos de la app de Renovate y por qué es seguro

Según su documentación («Security and permissions»), la app de Mend Renovate pide:

- **Lectura:** metadatos, alertas de Dependabot y administración (para leer las protecciones de rama).
- **Lectura y escritura:** código (para crear sus ramas), checks, estados de commit, issues (el panel de dependencias), pull requests y **workflows**. GitHub exige este último permiso para tocar `.github/workflows/`, que es donde están los SHA de las actions.

Por qué sigue siendo seguro:

- **Ruleset de `main` sin nadie en la lista de bypass, ni Renovate ni el mantenedor.** Exige PR, el check `hygiene` en verde, solo squash y nada de force-push. Renovate solo puede escribir en sus ramas `renovate/*`.
- **Automerge apagado:** `config:best-practices` no lo activa y no lo configuramos. Cada PR lo fusiona el mantenedor.
- **`pull_request` y no `pull_request_target`:** las ramas de Renovate no reciben secretos, y el `GITHUB_TOKEN` es de solo lectura.
- **El hueco que queda:** en un `pull_request`, la CI ejecuta la versión del workflow que trae la propia rama. Un Renovate comprometido podría debilitar `hygiene` en su PR y pasar el check. La defensa es la regla 11: cualquier cambio en `.github/**` se revisa aparte antes de fusionar.

## Preguntas de entrevista

- ¿Por qué fijar una action por SHA si ya tiene versión? Porque una etiqueta se puede mover y un SHA no. ¿Qué es un «impostor commit»? Un SHA que GitHub resuelve dentro del repo de la action, pero que en realidad viene de un fork; zizmor online lo detecta.
- ¿Para qué sirve `persist-credentials: false`? Para que el token no quede guardado en `.git/config`, al alcance de los pasos siguientes.
- Renovate tiene permiso de escritura en el código: ¿cómo evitas que meta algo en `main`? Con un ruleset sin bypass, el automerge apagado y la revisión de cualquier cambio en los workflows.
