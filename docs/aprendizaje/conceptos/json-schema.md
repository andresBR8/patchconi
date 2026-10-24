# JSON Schema y el contrato del informe

## Qué problema resuelve

El agente (Go, fase 5) y la API (TypeScript, fase 4) tienen que estar de acuerdo en qué es un informe válido. Si cada lado lo escribe a su manera (structs en Go, un validador en TypeScript), se separan sin que nada falle hasta producción. Un **JSON Schema** es un documento JSON que describe qué forma debe tener otro JSON: los dos lados validan contra el mismo fichero, `protocol/v1/report.schema.json`, y el desacuerdo sale en las pruebas.

## Las piezas

- **Draft 2020-12:** la versión de la especificación de JSON Schema. La declara `$schema`. La usa OpenAPI 3.1, así que el mismo esquema vale dentro de la OpenAPI.
- **`type`, `required`, `properties`:** el tipo, las propiedades obligatorias y la descripción de cada una.
- **`additionalProperties: false`:** rechaza cualquier propiedad que no esté descrita. Sin esto, un agente que escribe `metadata_age_secs` en vez de `metadata_age_seconds` pasaría la validación, y el servidor trataría el informe como «sin edad», en silencio.
- **`$defs` y `$ref`:** definiciones reutilizables (`#/$defs/uuid`) y referencias a ellas. Solo referencias internas (`#/...`): una `$ref` remota haría que la validación dependiera de la red y de un servidor ajeno, que podría cambiar qué es válido. Lo hemos comprobado: jv **descarga** las `$ref` remotas, así que el hook las rechaza antes de llamar a jv.
- **`oneOf`:** exactamente una de varias formas. `packages` es o bien `{status: ok, updates, held}` o bien `{status: error, error}` (AC-8.7); nunca las dos.
- **`if`/`then`/`else`:** reglas condicionales. Si `os.id` es `ubuntu`, `esm_enabled` es obligatorio; si no, está prohibido (el esquema `false` no admite ningún valor).
- **`format`:** `uuid`, `date-time`, `date`. La especificación solo lo exige como anotación; jv lo comprueba con `-f`. Por eso también hay un `pattern`: así cualquier validador lo hace cumplir igual.
- **Límites:** `maxLength`, `maxItems` y un patrón sin caracteres de control. Un host comprometido puede enviar cualquier cosa, y el esquema es la primera barrera.

## Schema-first frente a code-first (ADR 0022)

El ADR 0008 dice que la API genera su OpenAPI desde el código (code-first). Para el informe del agente hacemos lo contrario: el esquema escrito a mano es la fuente (schema-first), y la OpenAPI generada en la fase 4 tiene que usarlo. Hay tres razones:

1. El agente no puede esperar a la fase 4 para saber qué enviar.
2. Reglas como el `oneOf`, el `if/then` y los límites son difíciles de expresar con decoradores.
3. Un solo fichero para dos lenguajes.

El precio: el código de la API tiene que seguir un fichero que no genera él.

## Ejemplos que se comprueban solos

- Los ejemplos válidos salen de capturas reales (`protocol/captures/`), no de memoria (ADR 0008). Su README indica de dónde viene cada valor y cuáles son inventados.
- Cada ejemplo inválido cambia **un solo campo** de uno válido, y `expected.tsv` apunta el error exacto con el que debe fallar. Sin eso, un ejemplo con una errata de JSON también «fallaría», y la prueba pasaría por el motivo equivocado.
- El hook `check-protocol` se comprobó rompiéndolo a propósito de cuatro maneras: un válido roto, un inválido que pasa, un fallo por otro motivo y un fichero sin listar. En los cuatro casos falló.

## Versionado

`schema_version` es `mayor.menor`. Una versión menor solo añade propiedades opcionales. Como el esquema es estricto, un agente más nuevo que su servidor sería rechazado; por eso **se actualiza antes el servidor**, igual que en Kubernetes el plano de control va antes que los kubelets. Si un agente envía una versión que el servidor no conoce, recibe un error propio («actualiza el servidor») en vez de una lista de propiedades desconocidas.

## Cómo se usa en este repo

- `protocol/v1/report.schema.json`: el esquema; `protocol/v1/examples/`: los ejemplos.
- `protocol/v1/openapi.yaml`: borrador del endpoint, validado contra el esquema oficial de OpenAPI 3.1 copiado en `protocol/vendor/` con su sha256.
- `mise exec -- pre-commit run check-protocol --all-files` lo valida todo con jv (ADR 0021).
- Las reglas que el esquema no puede expresar están en `docs/product/protocol.md`.
