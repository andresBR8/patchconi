# mise: versiones de herramientas fijadas por repo

## Qué problema resuelve

Sin una herramienta así, cada máquina tiene su propia versión de Node, Go o pnpm, y «en mi máquina funciona» deja de ser una frase hecha. mise lee `mise.toml` en la raíz del repo e instala y activa exactamente esas versiones. Las usan tu terminal, la CI (con `jdx/mise-action`) y Renovate, que propone las subidas.

## Las piezas

- **`mise.toml`:** qué herramientas y en qué versión **exacta** (`node = "24.22.0"`, no `"24"`). Una versión exacta no se mueve sola; solo cambia con un commit revisado.
- **`mise.lock`:** para cada herramienta, la versión resuelta, la URL de descarga y el **checksum** de cada plataforma (`linux-x64`, `linux-arm64`, `macos-x64`, `macos-arm64`). `mise install --locked` instala exactamente eso y falla si algo no cuadra. `lockfile_platforms` en `mise.toml` hace que cada actualización conserve las cuatro plataformas.
- **Backends:** de dónde sale cada herramienta.
  - `core:` (node, go): los plugins integrados de mise, que descargan de nodejs.org y dl.google.com y verifican checksums.
  - `aqua:` (pnpm, actionlint, zizmor, pre-commit): binarios de las releases de GitHub, con checksums y, si la release la publica, verificación de procedencia (cosign, SLSA, attestations).
  - `go:` (gitleaks): compila con `go install` desde el código que guarda proxy.golang.org, verificado contra sum.golang.org. `install_env` fija `GOPROXY`, `GOSUMDB` y vacía `GONOPROXY`, `GONOSUMDB`, `GOPRIVATE` y `GOINSECURE`. Como `mise.lock` no guarda checksum para estas herramientas, la garantía tiene que vivir en el repo y no depender del entorno de cada máquina: un `GOSUMDB=off` global la anularía en silencio.
- **pre-commit** es un zipapp de Python (`.pyz`): usa el `python3` del sistema, que no está fijado. En su primera ejecución se descomprime en `~/.cache/pre-commit-zipapp`. Desde el sandbox de Claude Code solo funciona después de que lo hayas ejecutado una vez en tu terminal.
- **`[env]`:** variables que mise exporta en tu shell (con mise activado) y en cada comando que pasa por un shim. Hoy solo `PIP_UPLOADED_PRIOR_TO = "P3D"`, para que pip aplique la regla de los 3 días (ver `pre-commit-gitleaks-zizmor.md`). Al ser parte de `mise.toml`, cambiarla también exige `mise trust`.
- **Shims:** pequeños ejecutables en `~/.local/share/mise/shims` que redirigen `node`, `pnpm`… a la versión que pide el `mise.toml` de la carpeta actual.

## Modo paranoid

Está activado en la configuración global de mise de la VM de desarrollo (`paranoid = true`), no en el repo: es un ajuste que un repo no puede cambiar.

- Ningún `mise.toml` de proyecto se carga hasta que ejecutas `mise trust`. La confianza va ligada al **hash** del fichero: cualquier cambio lo vuelve a marcar como no confiable.
- **`mise.lock` no es configuración:** un cambio en el lock no pide `mise trust`. Por eso se revisa por la regla 11 de `CLAUDE.md`.
- En cada instalación vuelve a verificar la procedencia (SLSA, cosign, GitHub attestations) en lugar de fiarse de lo que quedó apuntado en el lock: paranoid activa `locked_verify_provenance` (documentación de mise, «Paranoid mode → Provenance re-verification»). No vuelve a comprobar una herramienta ya instalada.

Flujo en este repo: Claude escribe `mise.toml` → tú lo revisas → `mise trust` → `mise lock` → revisas `mise.lock` → `mise install --locked`.

## La regla de los 3 días

Fijamos solo versiones publicadas hace al menos 3 días, porque la mayoría de las versiones comprometidas se detectan y se retiran en horas. mise tiene su propio `minimum_release_age`, pero **no filtra versiones exactas ni bloqueadas en el lock**, así que en este repo no aportaría nada. La regla la aplicamos al fijar a mano y la aplica Renovate (`minimumReleaseAge`).

## Caso real: gitleaks 8.30.1 y la etiqueta movida

Al fijar gitleaks, el proxy de Go decía que `v8.30.1` era el commit `8d1f98c` (21-feb), pero la etiqueta de GitHub apuntaba a `83d9cd6` (12-mar).

- `83d9cd6` es hijo de `8d1f98c` y solo cambia `.goreleaser.yml`. El código Go es idéntico.
- Los binarios de la release se publicaron el 21-mar, sin firma ni procedencia.
- Comparar el checksum con el `checksums.txt` de la misma release no demuestra nada: quien mueve una etiqueta puede cambiar también los binarios y el fichero de checksums.

**Decisión:** compilar desde el código con el backend `go:`. proxy.golang.org guarda para siempre el código de cada versión, y sum.golang.org lo publica en un registro de transparencia que no se puede reescribir. La etiqueta de compilación `gore2regex` y los `ldflags` reproducen la build oficial. El precio es que la primera instalación compila (alrededor de un minuto).

## Preguntas de entrevista

- ¿Por qué versiones exactas y un lockfile, si ya fijas la versión en `mise.toml`? La versión dice *qué* instalar; el checksum del lock garantiza que lo descargado es el mismo artefacto en todas las máquinas.
- ¿Por qué no basta con comparar el checksum con el `checksums.txt` de la release? Porque los dos vienen de la misma fuente: si esa fuente está comprometida, los dos mienten a la vez. Hace falta una fuente independiente, como sum.golang.org.
- ¿Qué protege el modo paranoid y qué no? Protege contra un `mise.toml` cambiado sin que lo veas; no protege el lock ni sandboxea lo que apruebas.
