# pnpm y la cadena de suministro

## El riesgo

Una dependencia npm puede traer cientos de dependencias transitivas. Hay dos ataques clásicos:

1. **Versión maliciosa recién publicada:** alguien roba el token de un mantenedor y publica una versión con malware. Suele detectarse y retirarse en horas.
2. **Scripts de instalación:** `preinstall`, `install` y `postinstall` se ejecutan en tu máquina durante `pnpm install`, con tus permisos. Es la vía favorita del malware de npm.

## Lo que configura `pnpm-workspace.yaml`

En pnpm 12 la configuración vive en `pnpm-workspace.yaml`; `.npmrc` solo guarda autenticación y registro.

| Ajuste | Valor | Qué hace |
| --- | --- | --- |
| `minimumReleaseAge` | `4320` (minutos, 3 días) | No instala versiones publicadas hace menos de 3 días, tampoco las transitivas. Al fijarlo explícitamente se activa `minimumReleaseAgeStrict` (su valor por defecto es `true` cuando `minimumReleaseAge` está configurado; documentación de pnpm, «Settings → minimumReleaseAgeStrict»): si ninguna versión cumple, falla en lugar de coger una más nueva. `pnpm config get minimumReleaseAgeStrict` devuelve `undefined` porque no está escrito, no porque esté apagado |
| `strictDepBuilds` | `true` | Si una dependencia trae scripts de instalación sin revisar, `pnpm install` falla |
| `allowBuilds` | `{}` | Lista de paquetes a los que se permite ejecutar scripts. Vacía; cada entrada futura lleva un comentario con el motivo (regla 7 de `CLAUDE.md`) |
| `trustPolicy` | `no-downgrade` | Falla si un paquete tiene menos pruebas de confianza que sus versiones anteriores (por ejemplo, antes se publicaba con trusted publishing y ahora no): señal típica de una cuenta secuestrada |
| `blockExoticSubdeps` | `true` | Solo las dependencias directas pueden venir de git o de URLs de tarballs; las transitivas, solo del registro |
| `updateNotifier` | `false` | Quita el aviso de «hay un pnpm nuevo», que sugiere instalarlo con un `curl \| sh` y saltarse mise y `mise.lock`. pnpm solo se actualiza por PRs de Renovate |

## Las versiones de pnpm y Node

- **pnpm** lo fija mise (`mise.toml`), y además `package.json` lo declara en `packageManager: "pnpm@12.13.0"`. Las dos versiones deben coincidir (ver «El lockfile», más abajo). Renovate las actualiza juntas (paso 4 de la fase 0).
- **Node:** `engines.node: "^24.22.0"` documenta la versión mínima. Antes de la fase 2 se sube a Node 26 LTS.

## El lockfile

`pnpm-lock.yaml` fija la versión exacta y el hash de integridad de cada paquete. En CI se instala con `pnpm install --frozen-lockfile`, que falla si el lock no cuadra con `package.json`. Un cambio en el lock puede cambiar qué código se descarga, así que entra en la regla 11.

El fichero tiene **dos documentos YAML**, separados por `---`:

1. **pnpm fijándose a sí mismo** (`packageManagerDependencies`): por el campo `packageManager`, pnpm 12 bloquea `pnpm@12.13.0` y sus 14 binarios `@pnpm/exe.*` del registro npm, cada uno con su hash de integridad.
2. **El lock normal del proyecto:** hoy vacío (`importers: .: {}`), porque aún no hay dependencias.

Eso significa que hay **dos cadenas de confianza para el mismo pnpm**:

- **mise (aqua):** binario de las releases de GitHub, con checksum en `mise.lock` y GitHub attestations. Es el que ejecutan los shims.
- **npm:** paquete `pnpm` y binarios `@pnpm/exe.*`, con integridad en `pnpm-lock.yaml`. Es el que descargaría pnpm por su cuenta si la versión de `packageManager` no coincidiera con la que está ejecutando.

Mientras las dos versiones coincidan, solo se usa la de mise. Si se separaran, pnpm saldría a npm por su cuenta. Por eso Renovate las sube en el mismo PR.

## Preguntas de entrevista

- ¿Por qué esperar 3 días antes de instalar una versión nueva? Porque la mayoría de las versiones comprometidas se retiran en horas. El retraso cuesta poco y deja que otros las detecten primero.
- ¿Qué es un `postinstall` y por qué bloquearlo por defecto? Es un script que el paquete ejecuta al instalarse, con tus permisos. Bloquearlo por defecto obliga a decidir paquete a paquete.
- ¿Qué ataque frena `trustPolicy: no-downgrade`? El de una cuenta de mantenedor robada que publica sin la procedencia que tenían las versiones legítimas.
