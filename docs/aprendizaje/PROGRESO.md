# Progreso

Una línea por paso terminado: `AAAA-MM-DD · fase · qué se hizo · siguiente paso`.

2026-10-17 · 0 · Repo creado y configuración de Claude Code (bootstrap) · Fase 0: primera sesión de Claude Code (comprobar sandbox y plan)
2026-10-17 · 0 · Sandbox comprobado, plan de la fase 0 aprobado y paso 1 (guardrails): regla 11, punto 0 del reviewer, denegación de Edit en la configuración de usuario · Paso 2: toolchain con mise y workspace de pnpm
2026-10-17 · 0 · Paso 2 (toolchain): mise.toml y mise.lock con 4 plataformas, gitleaks compilado desde el proxy de Go por la etiqueta movida, workspace de pnpm endurecido y .editorconfig · Paso 3: pre-commit con gitleaks, actionlint y zizmor (aplicar PRE_COMMIT_HOME y GOCACHE en settings.local.json)
2026-10-17 · 0 · Paso 3 (pre-commit): hooks de pre-commit-hooks desde PyPI con dependencias fijadas, gitleaks staged + historial, actionlint con shellcheck fijado, zizmor offline, sin falsos verdes en merge-conflict y large-files, PIP_UPLOADED_PRIOR_TO=P3D en mise.toml · Paso 4: CI de higiene y Renovate (checkout con fetch-depth: 0 para gitleaks-history; comprobar que mise-action exporta [env]; Renovate necesita language: python en additional_dependencies)
