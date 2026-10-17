# Ejecución fuera del sandbox

## La idea en una frase

El sandbox limita lo que Claude Code **ejecuta**, no lo que **escribe** para que otro lo ejecute después.

## Las dos capas que confinan a Claude Code

**1. El sandbox de Bash (bubblewrap + seccomp).** Cada comando Bash de Claude corre dentro:

- **Ficheros:** solo puede escribir en el repo y en su `$TMPDIR`. El resto del disco es de solo lectura, y algunas rutas (`~/.ssh`, otros repositorios) ni se ven.
- **Red:** pasa por un proxy con una lista de dominios permitidos.
- **seccomp:** bloquea la creación de sockets Unix. Por eso no puede hablar con `/var/run/docker.sock`: tener acceso a Docker equivale a ser root en la VM de desarrollo.
- **Ficheros fantasma:** el sandbox monta `/dev/null` encima de rutas sensibles (`.bashrc`, `.gitconfig`, `.mcp.json`, `.claude/hooks`…) para que Claude no pueda crearlas y colar código que se ejecute más tarde. Esos montajes salen en su `git status` como ficheros sin seguimiento, y por eso `git add -A` está prohibido.

**2. Las reglas de permisos (`.claude/settings.json`).** Las herramientas Edit y Write **no** pasan por bubblewrap. Una edición fuera del proyecto ya pide confirmación por defecto; las reglas `deny` existen para que no puedas aprobarla por error, con un «sí» rápido. Por eso una lista incompleta sigue teniendo valor. Una regla `Edit(...)` cubre Edit y Write. Están denegadas:

- Carpetas de configuración, cachés y binarios: `~/.config`, `~/.local`, `~/.cache`, `~/.npm`, `~/.gnupg`, `~/.ssh`, `~/.docker`, `~/.kube`, `~/.cargo`, `~/bin`, `~/go`. `~/.cache` importa más de lo que parece: pre-commit ejecuta los hooks desde los repos que clona en `~/.cache/pre-commit`, así que manipular ese caché mete código en cada commit sin tocar el repo.
- Dotfiles que ejecuta la shell u otras herramientas: `.bashrc`, `.profile`, `.zshrc`, `.gitconfig`, `.npmrc`, `.tmux.conf`, `.vimrc`, etc.
- La configuración de Claude Code de usuario: `~/.claude.json` (servidores MCP), `~/.claude/settings*.json`, `~/.claude/CLAUDE.md`, y los hooks, agentes, comandos, skills, plugins, reglas, estilos, workflows, rutinas y tareas programadas.
- La configuración que mise y direnv buscan en carpetas padre: `~/*.toml`, `~/.mise.toml`, `~/.mise/`, `~/mise/`, `~/.tool-versions`, `~/.envrc`, `~/apps/*.toml`, `~/apps/.*`.
- Los hooks y la config de git del repo: `.git/hooks/**`, `.git/config`.

Además se niega la **lectura** de carpetas de credenciales: `~/.ssh`, `~/.kube`, `~/.docker`, `~/.aws`, `~/.azure`, `~/.config/gcloud`, `~/.terraform.d`, `~/.minikube`, `~/.ansible`, entre otras. Comprobado el 17-oct-2026: las que existen se ven vacías desde el sandbox.

Todas estas reglas viven en el repo y no en la configuración de usuario: las `deny` se suman entre ámbitos, y una regla de usuario que niegue la ruta de otro repositorio rompería las sesiones de Claude Code que trabajan en ese repositorio.

¿Por qué una lista y no `Edit(~/.*/**)`? Porque las reglas `deny` no admiten excepciones: esa regla bloquearía también `~/.claude/plans` (donde el modo plan escribe su plan) y la memoria de Claude. Una lista de rutas prohibidas nunca está completa; por eso existe la capa 3.

Comprobado el 17-oct-2026: escribir en `~/.config/patchconi-probe`, `~/.claude/hooks/x`, `~/apps/.envrc`, `.git/hooks/x` y `~/.cache/x` sale denegado, y editar dentro del repo sigue funcionando.

## El hueco: la ejecución diferida

Hay ficheros del repo que **otros** ejecutan más tarde y fuera del sandbox:

| Fichero | Quién lo ejecuta y cuándo |
| --- | --- |
| `mise.toml`, `mise.lock` | Tú, con `mise install`: descarga y ejecuta binarios |
| `package.json` (scripts, `packageManager`), `.pnpmfile.cjs`, `pnpm-workspace.yaml`, `pnpm-lock.yaml` | Tú, con `pnpm install` y `pnpm <script>`. `.pnpmfile.cjs` se ejecuta en cada `install`, `packageManager` hace que pnpm descargue esa versión de sí mismo, `allowBuilds` decide qué `postinstall` corren y el lock decide qué tarballs se descargan |
| `go.mod`, `go.sum` | Tú y la CI. Una directiva `toolchain` hace que Go descargue otro compilador |
| `.pre-commit-config.yaml` | Tú, en cada `git commit`, después de haber ejecutado `pre-commit install` (que crea el hook en `.git/hooks`). Los hooks remotos se clonan y se ejecutan desde `~/.cache/pre-commit` |
| `*.config.ts` (ESLint, Vite…) | Tú y la CI, con `pnpm lint/test/build`: son código, no datos |
| `Makefile`, `scripts/`, `.envrc` | Tú: `make`, los scripts, direnv al entrar en la carpeta |
| `.github/**` | Los runners de GitHub, con `GITHUB_TOKEN` y los secrets del repo (no la VM de desarrollo) |
| `Dockerfile*`, `compose*.y*ml` | Tú, con `docker`, que equivale a root en la VM de desarrollo |
| `deploy/**`, empaquetado del agente | Los hosts de los usuarios, como root |
| `.vscode/**`, `.devcontainer/` | VS Code |
| `CLAUDE.md`, `.claude/**`, `.mcp.json` | Cada sesión de Claude Code: cambian sus reglas, y MCP arranca procesos fuera del sandbox |

Si Claude, o una dependencia comprometida que influya en lo que escribe, mete algo malicioso en uno de estos ficheros, el sandbox no sirve de nada: el código corre fuera, con tus permisos.

## La capa 3: revisión humana

1. **Regla 11 de `CLAUDE.md`:** el criterio es «todo fichero, versionado o no, que ejecuta código o configura cómo se ejecuta fuera del sandbox». La tabla anterior son ejemplos, no la lista completa. Cada cambio en uno de ellos se lista en «Revisar antes de ejecutar», con una línea por fichero.
2. **Subagente `reviewer`:** su punto 0, obligatorio, aplica ese criterio y abre el informe con esa lista.
3. **mise en modo paranoid:** está configurado en el `config.toml` global de mise de la VM de desarrollo, fuera del repo. Un `mise.toml` cambiado deja de ser de confianza hasta que lo revisas y ejecutas `mise trust`. Un cambio en `mise.lock` **no** exige `mise trust`, porque paranoid solo vigila los ficheros de configuración (comprobado en la documentación de mise el 17-oct-2026). Por eso `mise.lock` está en la regla 11.
4. **Tú ejecutas las instalaciones** (`mise install`, `pnpm install`, `docker`), no Claude.

La regla 11 marca **prioridades** de revisión; no sustituye revisar el resto del diff. Tus `pnpm test` y la CI también ejecutan el código de producto que escribe Claude.

## Preguntas de entrevista

- ¿Por qué un sandbox para el agente de IA no basta por sí solo? Porque lo que el agente escribe lo puede ejecutar luego una persona o la CI fuera del sandbox (ejecución diferida, o «confused deputy»). La revisión humana de los ficheros ejecutables cierra ese hueco.
- ¿Por qué una regla del sandbox no protege un fichero que modifica la herramienta Edit? Porque Edit no es un comando Bash: no pasa por bubblewrap, solo por las reglas de permisos.
- Nombra tres ficheros «de configuración» que en realidad ejecutan código. `.envrc` (direnv), `.pre-commit-config.yaml` (cada commit) y `eslint.config.js` (cada lint).
- ¿Por qué el acceso al socket de Docker equivale a root? Porque `docker run -v /:/host --privileged` monta todo el disco del host dentro de un contenedor con root.
