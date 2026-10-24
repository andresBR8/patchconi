# pre-commit, gitleaks y zizmor

## Qué es pre-commit

Un gestor de *hooks* de git. `.pre-commit-config.yaml` dice qué comprobaciones se ejecutan; `pre-commit install` crea `.git/hooks/pre-commit`, y desde entonces cada `git commit` las ejecuta sobre los ficheros preparados. `pre-commit run --all-files` las ejecuta sobre todos los ficheros versionados: es lo que hacen la skill `verify` y la CI.

`pre-commit install` escribe en el hook la ruta del Python del zipapp de pre-commit. **Al subir de versión pre-commit hay que repetir `pre-commit install`.**

## Los hooks de este repo

| Hook | Qué comprueba | De dónde sale |
| --- | --- | --- |
| editorconfig-checker | Lo que dice `.editorconfig`: espacios al final, salto de línea final, LF y utf-8. Avisa, no arregla. En `.editorconfig-checker.json` están desactivados el tamaño de sangría y sus exclusiones por defecto, que sin avisar se saltaban `pnpm-lock.yaml`, `go.sum` o `*.svg` | editorconfig-checker (mise, `go:`) |
| check-yaml | Sintaxis YAML. yq lee todos los documentos, así que `pnpm-lock.yaml` (dos documentos) pasa sin flags. **No detecta claves duplicadas** | yq (mise, `aqua:` con cosign) |
| check-json | Sintaxis JSON y claves duplicadas | `scripts/hooks/check-json.py` (solo la librería estándar) |
| check-toml | Sintaxis TOML 1.0, también claves duplicadas | `scripts/hooks/check-toml.sh` con tomljson (mise, `go:`) |
| check-merge-conflict | Marcas de conflicto, siempre (no solo durante un merge) | `language: pygrep`, patrones de pre-commit-hooks 6.0.0 |
| check-large-files | Ficheros de más de 500 KB, todos los que pasa pre-commit (no solo los recién añadidos) | `scripts/hooks/check-large-files.sh` |
| detect-private-key | Cabeceras de clave privada, aunque falte el resto de la clave (gitleaks solo ve claves completas) | `language: pygrep`, patrones de pre-commit-hooks 6.0.0 |
| shellcheck | Los scripts de `scripts/`, que se ejecutan en cada commit | shellcheck (mise) |
| gitleaks-staged | Secretos en lo que vas a confirmar | gitleaks (mise) |
| gitleaks-history | Secretos en todo el historial de git | gitleaks (mise) |
| actionlint | Errores en los workflows de GitHub Actions. Revisa los scripts `run:` con el shellcheck fijado en mise; pyflakes desactivado | actionlint + shellcheck (mise) |
| zizmor | Problemas de seguridad en los workflows y en el propio `.pre-commit-config.yaml` | zizmor (mise) |

## Falsos verdes: hooks pensados para el índice

Varios hooks están pensados para mirar solo lo que entra en un commit. Con `pre-commit run --all-files` (`verify` y la CI) no hay nada preparado, y dicen «Passed» sin haber revisado nada:

- **gitleaks oficial** (`--staged`): solo mira lo preparado.
- **check-added-large-files** de pre-commit-hooks: solo miraba los ficheros *añadidos* al índice (por eso usábamos `--enforce-all`). Nuestro script mira todos los ficheros que le pasa pre-commit.
- **check-merge-conflict** de pre-commit-hooks: fuera de un merge devolvía 0 sin leer nada (por eso usábamos `--assume-in-merge`). El hook pygrep siempre mira.

La forma de detectarlos es leer el código del hook, o probar con un fichero que debería fallar. Con los hooks de la #9 (24-oct-2026) se probó así cada uno, en un repo temporal: YAML y JSON rotos, JSON y TOML con claves repetidas, una marca de conflicto, una cabecera de clave privada, un fichero de 600 KB, un fichero sin salto final, otro con espacios al final y un script con un fallo de shellcheck. Todos fallaron salvo un caso: **yq aceptó un YAML con una clave repetida**. Por eso JSON va con el script de Python, y en YAML queda como riesgo conocido (actionlint sí las detecta en los workflows).

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

Todos los hooks van como `repo: local`. Con `language: system`, pre-commit ejecuta el binario que ya instaló mise; con `language: pygrep`, usa una búsqueda por expresión regular que trae el propio pre-commit. Ningún hook instala nada al ejecutarse y hay una sola fuente de versiones (`mise.toml` y `mise.lock`). Con los hooks remotos oficiales, pre-commit compilaría Go o bajaría otros binarios por su cuenta.

## Por qué ya no usamos pre-commit-hooks desde PyPI (ADR 0020)

Hasta la #9, los 8 hooks de higiene venían de pre-commit-hooks 6.0.0, instalado con pip desde PyPI. Eso dejaba otro registro de paquetes en la cadena (pip, PyPI y un setuptools sin fijar) y obligaba a saltarse `end-of-file-fixer` en el sandbox. El ADR 0020 los sustituye y fija un **orden de preferencia** para el origen de cada herramienta:

1. aqua con firma o procedencia que mise verifique (yq con cosign; pnpm, actionlint y zizmor con attestations de GitHub);
2. `go:` desde el código, verificado con sum.golang.org (gitleaks, editorconfig-checker, tomljson);
3. aqua solo con checksums, cuando no hay otra cosa (pre-commit, shellcheck).

El ADR tiene la tabla completa, con Node.js y Go.

Una nota de por qué entonces se usaba PyPI y no el repo de git de pre-commit-hooks, porque sigue valiendo para cualquier hook remoto: el sandbox de Claude Code pasa a git la configuración de su proxy en `GIT_CONFIG_PARAMETERS`, y pre-commit lanza git con un entorno filtrado que la descarta (`no_git_env`), así que no puede clonar repos de hooks a través del proxy.

## Riesgos que quedan

- **yq acepta claves duplicadas en YAML.** actionlint las detecta en los workflows; en el resto de ficheros YAML (`.pre-commit-config.yaml`, `pnpm-workspace.yaml`…) no se comprueban. Riesgo aceptado por ahora ([issue #17](https://github.com/andresBR8/patchconi/issues/17)); se revisa al elegir el validador del paso 5.
- **Ya nada arregla ficheros.** Si editorconfig-checker falla, se arregla a mano.
- **El `bash` y el `python3` del sistema no están fijados.** Los usan pre-commit y los scripts de `scripts/hooks/`. `check-json.py` solo usa la librería estándar y se ejecuta con `python3 -I`, así que ningún módulo del repo puede hacerse pasar por `json`.
- **El límite de 500 KB y `pnpm-lock.yaml`:** cuando las apps tengan dependencias, el lockfile pasará de 500 KB. Hay que revisarlo en la fase 2.
- **`PIP_UPLOADED_PRIOR_TO` sigue en `mise.toml`** como red de seguridad: hoy ningún hook instala paquetes de Python, pero si alguien añade uno, pip aplicará la regla de los 3 días. La CI sigue comprobando que mise exporta el `[env]`.
- **actionlint y las herramientas del PATH:** actionlint usa shellcheck y pyflakes si los encuentra. shellcheck está fijado en mise (los runners de GitHub traen el suyo, sin fijar) y pyflakes está desactivado (`-pyflakes=`), así que el resultado es el mismo en todas las máquinas.
- **El orden del PATH importa.** Un `pre-commit` instalado fuera de mise (por ejemplo, con pipx en `~/.local/bin`) puede ir antes que el de mise. Por eso `verify` llama a `mise exec -- pre-commit run --all-files`. Dentro de `mise exec`, `~/.local/bin` sigue yendo primero en el PATH: si ahí hubiera otro `yq` o `shellcheck`, los hooks `system` lo usarían.

## Particularidades del sandbox de Claude Code

- `PRE_COMMIT_HOME` apunta a una ruta del directorio temporal del sandbox (en `.claude/settings.local.json`): pre-commit necesita escribir su caché, y `~/.cache` está cerrado para Claude.
- **Claude Code no puede commitear con cambios sin preparar dentro de `.claude/`.** Antes de los hooks, pre-commit guarda en un parche los cambios sin preparar y deja esos ficheros como en el índice (`git checkout -- .`); al terminar, aplica el parche otra vez. En el sandbox `.claude/` es de solo lectura, así que ese `checkout` falla: el commit no se hace y el árbol queda a medias (pasó el 24-oct-2026 con `.claude/skills/verify/SKILL.md`). Se recupera aplicando el parche que pre-commit deja en `PRE_COMMIT_HOME` (`git apply`, sin el fichero de `.claude/`). Regla: cualquier cambio en `.claude/` va, preparado, en el siguiente commit.
- Hasta la #9, `end-of-file-fixer` abría cada fichero en modo lectura-escritura y el sandbox monta `.claude/` en solo lectura, así que había que saltarlo con `SKIP`. Los hooks nuevos solo leen: ya no hace falta.

## Preguntas de entrevista

- ¿Por qué el hook oficial de gitleaks da un falso verde en la CI? Porque `--staged` solo mira lo preparado para commit, y en `pre-commit run --all-files` no hay nada preparado.
- ¿Qué diferencia hay entre fijar un hook por SHA de git y por versión de PyPI? El SHA fija el contenido exacto. La versión de PyPI fija unos ficheros que no se pueden reemplazar, pero sí ampliar con ficheros nuevos. Por eso acabamos sin ninguno de los dos: binarios fijados con mise.
- ¿Por qué editorconfig-checker y tomljson se compilan desde el código y yq no? yq firma sus checksums con cosign y mise lo verifica. Los otros dos solo publican un fichero de checksums de la misma release, que no prueba nada si la release está comprometida; compilarlos con `go:` los verifica contra sum.golang.org.
- ¿Cómo sabes que un hook no da un falso verde? Probándolo con un fichero que debería fallar. Así descubrimos que yq acepta claves duplicadas.
- ¿Por qué `language: system` para gitleaks y no el hook oficial? Para que la versión salga de `mise.toml` y no de un segundo sitio que mantener.
