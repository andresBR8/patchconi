# pre-commit, gitleaks y zizmor

## Qué es pre-commit

Un gestor de *hooks* de git. `.pre-commit-config.yaml` dice qué comprobaciones se ejecutan; `pre-commit install` crea `.git/hooks/pre-commit`, y desde entonces cada `git commit` las ejecuta sobre los ficheros preparados. `pre-commit run --all-files` las ejecuta sobre todos los ficheros versionados: es lo que hacen la skill `verify` y la CI.

`pre-commit install` escribe en el hook la ruta del Python del zipapp de pre-commit. **Al subir de versión pre-commit hay que repetir `pre-commit install`.**

## Los hooks de este repo

| Hook | Qué comprueba | De dónde sale |
| --- | --- | --- |
| trailing-whitespace, end-of-file-fixer | Espacios al final de línea y salto de línea final (los arreglan) | pre-commit-hooks 6.0.0 (PyPI) |
| check-yaml, check-json, check-toml | Que la sintaxis sea válida. `check-yaml` admite varios documentos, porque pnpm 12 escribe así `pnpm-lock.yaml` | pre-commit-hooks |
| check-merge-conflict | Marcas de conflicto. Con `--assume-in-merge`, porque sin él solo mira algo durante un merge | pre-commit-hooks |
| check-added-large-files | Ficheros de más de 500 KB. Con `--enforce-all`, porque sin él solo mira los ficheros recién añadidos al índice | pre-commit-hooks |
| detect-private-key | Claves privadas | pre-commit-hooks |
| gitleaks-staged | Secretos en lo que vas a confirmar | gitleaks (mise) |
| gitleaks-history | Secretos en todo el historial de git | gitleaks (mise) |
| actionlint | Errores en los workflows de GitHub Actions. Revisa los scripts `run:` con el shellcheck fijado en mise; pyflakes desactivado | actionlint + shellcheck (mise) |
| zizmor | Problemas de seguridad en los workflows y en el propio `.pre-commit-config.yaml` | zizmor (mise) |

## Falsos verdes: hooks pensados para el índice

Varios hooks están pensados para mirar solo lo que entra en un commit. Con `pre-commit run --all-files` (`verify` y la CI) no hay nada preparado, y dicen «Passed» sin haber revisado nada:

- **gitleaks oficial** (`--staged`): solo mira lo preparado.
- **check-added-large-files:** solo mira los ficheros *añadidos* al índice. Arreglo: `--enforce-all`. En un commit, pre-commit solo le pasa los ficheros preparados, así que no se vuelve lento.
- **check-merge-conflict:** fuera de un merge devuelve 0 sin leer nada. Arreglo: `--assume-in-merge`.

La forma de detectarlos es leer el código del hook, o probar con un fichero que debería fallar.

### gitleaks: dos hooks

El hook oficial ejecuta `gitleaks git --pre-commit --staged`. Por eso hay dos:

- `gitleaks-staged`: lo que entra en cada commit.
- `gitleaks-history`: todo el historial (`always_run: true`). Hoy tarda unos 0,1 s.

Prueba negativa (17-oct-2026, en un clon temporal): un token falso con formato de token de GitHub. `gitleaks-staged` falló con el fichero preparado; `gitleaks-history` pasó antes del commit y falló después. La salida no muestra el secreto (`--redact`).

**Cómo salir si un secreto llega al historial:** `gitleaks-history` hará fallar *todos* los commits a partir de entonces. Es lo que queremos, pero hay que saber cómo salir:

1. Revocar el secreto en su servicio. Es lo primero, porque ya es público si se hizo push.
2. Reescribir el historial, o, si es un falso positivo, añadir su huella a `.gitleaksignore`.

En la CI, el checkout necesita `fetch-depth: 0` (paso 4): con el valor por defecto solo hay un commit y `gitleaks-history` no ve el resto.

## zizmor

Analiza la seguridad de GitHub Actions (permisos, inyección de expresiones, acciones sin fijar…) y también audita `.pre-commit-config.yaml`. En local va con `--offline`: sin red ni token. En la CI (paso 4) va también en modo online, que añade auditorías con la API de GitHub, como comprobar que cada SHA fijado pertenece de verdad al repo de la acción.

## Hooks locales: binarios de mise

gitleaks, actionlint y zizmor van como `repo: local` con `language: system`: pre-commit ejecuta el binario que ya instaló mise. Así hay una sola fuente de versiones (`mise.toml` y `mise.lock`). Con los hooks remotos oficiales, pre-commit compilaría Go o bajaría otros binarios por su cuenta.

## pre-commit-hooks desde PyPI, no desde git

Lo normal es `repo: https://github.com/pre-commit/pre-commit-hooks` con `rev:` fijado por SHA. No sirve aquí por dos motivos:

1. **El sandbox de Claude Code.** El sandbox pasa a git la configuración de su proxy en la variable `GIT_CONFIG_PARAMETERS`, y pre-commit lanza git con un entorno filtrado que la descarta (`no_git_env`). El `git fetch` del repo de hooks no pasa por el proxy y falla. Comprobado a mano: el mismo `fetch` funciona con la variable y falla sin ella.
2. **setuptools.** Desde git, pip tiene que **construir** el paquete, y para eso descarga setuptools.

Así que los 8 hooks van como `repo: local` + `language: python`, con `additional_dependencies: ["pre-commit-hooks==6.0.0", "ruamel.yaml==0.19.1"]`:

- `entry`, `types` y `stages` están copiados del `.pre-commit-hooks.yaml` del commit `3e8a8703` (etiqueta v6.0.0).
- `ruamel.yaml` es la única dependencia que pip instala de verdad con Python 3.12. `tomli` solo hace falta con Python < 3.11, y desde 0.19 `ruamel.yaml.clib` es un extra opcional.
- Los 8 hooks llevan **la misma** lista: pre-commit crea un entorno por cada combinación de dependencias, y un hook sin ella tendría otro entorno con `ruamel.yaml` sin fijar.
- Los dos paquetes se instalan desde **wheels** ya construidos. `pip download --only-binary=:all:` resuelve solo a `pre_commit_hooks-6.0.0-py2.py3-none-any.whl` y `ruamel_yaml-0.19.1-py3-none-any.whl`.
- **Para el paso 4 (Renovate):** su gestor `pre-commit` solo actualiza `additional_dependencies` de Python si el hook declara `language: python` (comprobado en su código fuente, `extract.ts`). Por eso va explícito en cada hook.

## Riesgos que quedan

- **PyPI permite añadir ficheros a una versión ya publicada.** No deja reemplazar un fichero existente, pero el mantenedor (o quien robe su cuenta) puede subir, por ejemplo, un wheel nuevo para otra plataforma dentro de la 6.0.0, y pip podría preferirlo. pre-commit no permite fijar dependencias por hash (`--require-hashes`).
- **El paquete placeholder y setuptools.** Para los hooks Python `local`, pre-commit siempre crea un paquete vacío (`pre-commit-placeholder-package`) y lo instala con `pip install .`, así que pip **construye** ese paquete y descarga setuptools en su última versión. Pasa una vez, al crear el entorno, no en cada commit.
  - **Mitigación:** `PIP_UPLOADED_PRIOR_TO = "P3D"` en el `[env]` de `mise.toml`. pip solo acepta paquetes subidos hace al menos 3 días, también en la construcción aislada.
  - **Comprobado:** con el binario real de pre-commit y `PIP_UPLOADED_PRIOR_TO=P100D` en la orden, el placeholder salió construido con setuptools 83.0.0 en lugar de 84.0.0. Los shims de mise entregan `P3D` y tu shell con mise activado también.
  - **Lo que no cubre:**
    - La versión de setuptools sigue **sin fijar**; solo cumple la regla de los 3 días.
    - `.git/hooks/pre-commit` llama directamente al Python de pre-commit, sin pasar por un shim. Si el entorno se crea en un `git commit` lanzado desde un shell sin mise activado (por ejemplo, la interfaz de git de un editor), pip no ve la variable y la regla se pierde en silencio. La CI tiene que exportarla (paso 4: comprobar que `jdx/mise-action` exporta el `[env]` o ponerla en el `env` del workflow).
- **El `python3` del sistema no está fijado.** En la VM de desarrollo es 3.12. En un Mac con el Python 3.9 de las herramientas de línea de comandos de Xcode, pip instalaría además `tomli` sin fijar.
- **actionlint y las herramientas del PATH:** actionlint usa shellcheck y pyflakes si los encuentra. shellcheck está fijado en mise (los runners de GitHub traen el suyo, sin fijar) y pyflakes está desactivado (`-pyflakes=`), así que el resultado es el mismo en todas las máquinas.
- **Mejora futura:** sustituir estos hooks de Python por binarios fijados con mise, con checksums en `mise.lock`. Por ejemplo, `editorconfig-checker` para espacios y saltos de línea, y `taplo` para TOML. Eso elimina Python, pip y setuptools de la cadena.

## Particularidades del sandbox de Claude Code

- `PRE_COMMIT_HOME` apunta a una ruta del directorio temporal del sandbox (en `.claude/settings.local.json`): pre-commit necesita escribir su caché, y `~/.cache` está cerrado para Claude.
- `end-of-file-fixer` abre **cada** fichero en modo lectura-escritura aunque no tenga que cambiarlo, y el sandbox monta `.claude/` en solo lectura. En el sandbox fallaría siempre, así que `.claude/settings.local.json` define `SKIP=end-of-file-fixer`. Cubre `verify` y los `git commit` de Claude. Tu terminal y la CI lo ejecutan completo.

## Preguntas de entrevista

- ¿Por qué el hook oficial de gitleaks da un falso verde en la CI? Porque `--staged` solo mira lo preparado para commit, y en `pre-commit run --all-files` no hay nada preparado.
- ¿Qué diferencia hay entre fijar un hook por SHA de git y por versión de PyPI? El SHA fija el contenido exacto. La versión de PyPI fija unos ficheros que no se pueden reemplazar, pero sí ampliar con ficheros nuevos.
- ¿Por qué `language: system` para gitleaks y no el hook oficial? Para que la versión salga de `mise.toml` y no de un segundo sitio que mantener.
