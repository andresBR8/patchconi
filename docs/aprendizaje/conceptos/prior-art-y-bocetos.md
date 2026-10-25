# Prior art y bocetos de baja fidelidad

## Por qué estudiar la competencia antes de construir

`docs/product/prior-art.md` revisa seis herramientas que ya hacen parte de lo que hace PatchConi. Se hace antes de escribir código por tres motivos:

- **Para no reinventar mal.** Otros ya tropezaron con los mismos problemas. Ejemplo: el script `apt_info.py` de Prometheus no refresca la caché de apt y publica su antigüedad; es justo la regla que salió de nuestras capturas (hallazgo 1 de `protocol.md`). Que otro proyecto llegue a lo mismo confirma la decisión.
- **Para saber en qué te diferencias de verdad.** «Solo lectura» no basta: Patchman también lo es. Lo que no aparece en ninguna fuente consultada es la edad de cada pendiente contra un plazo declarado (*pending since* y la política). Eso es lo que hay que defender en una entrevista o en un README.
- **Para decidir qué NO hacer.** PatchMon, Landscape y Katello instalan parches. Verlo escrito ayuda a explicar por qué PatchConi no: un servidor que puede cambiar todos los hosts es el objetivo más valioso de la flota.

Reglas que seguimos: solo fuentes oficiales (repositorio, documentación, web del proyecto), fecha de consulta, y si una fuente no dice algo se escribe *not stated* en vez de suponerlo. Una comparación con afirmaciones inventadas sobre otro proyecto es peor que no tenerla.

## Cómo leer una licencia como la AGPL

No es asesoramiento legal; es lo que hay que saber para no meter la pata en un proyecto Apache-2.0.

- **Permisivas (Apache-2.0, MIT).** Puedes usar, modificar y redistribuir, también en software cerrado, conservando el aviso de copyright y la licencia. Apache-2.0 añade una licencia de patentes explícita y pide indicar los cambios. Es la de PatchConi (ADR 0012).
- **Copyleft (GPL-2.0, GPL-3.0).** Si **distribuyes** el programa o un derivado, tienes que darlo con su código fuente y bajo la misma licencia. Usarlo internamente sin distribuirlo no obliga a nada.
- **AGPL-3.0 (PatchMon).** Es la GPL-3.0 más la sección 13: si **modificas** el programa y otros lo usan **por la red** (una web, una API), tienes que ofrecerles el código fuente de tu versión. Cierra el «hueco del SaaS»: con la GPL, ofrecer un servicio no es distribuir.
- **Compatibilidad, en un solo sentido.** Código Apache-2.0 puede entrar en un proyecto GPL-3.0 (el conjunto pasa a ser GPL-3.0). Al revés no: copiar código GPL o AGPL en PatchConi obligaría a licenciar el conjunto bajo GPL/AGPL. Apache-2.0 y GPL-2.0 (Landscape client, Katello) no son compatibles entre sí.
- **Ideas frente a expresión.** El copyright protege el código, los textos y las imágenes, no las ideas. «Los agentes solo abren conexiones salientes» es una idea y se puede adoptar; copiar el agente de PatchMon, su README o una captura de su panel, no. Por eso `prior-art.md` describe con palabras propias y no incluye código, textos ni capturas.
- **Cómo comprobarla.** Mira el fichero `LICENSE` del repositorio y la cabecera de los ficheros; algunos proyectos tienen excepciones (Foreman: GPL-3.0 «con algunas excepciones» en ficheros de terceros). Si un fichero no dice nada, rige la licencia del repositorio (`apt_info.py`).

## Por qué bocetos de baja fidelidad antes de la UI

`docs/product/screens.md` dibuja las cuatro pantallas con cajas de texto ASCII, sin colores ni componentes.

- **Barato de cambiar.** Mover una columna en un bloque de texto cuesta segundos; en React, con tests y estilos, cuesta horas. En la fase 1 todavía se puede cambiar de idea sin tirar trabajo.
- **Obliga a cuadrar cada dato con el modelo.** Cada valor del boceto tiene su columna en `domain-model.md`. Si un dato no existe, no se dibuja: se abre una pregunta. Así salieron cuatro huecos (URL del agente para el comando de instalación, umbral de desfase de reloj, qué informe refresca *stale*, quién borra una alerta) antes de escribir el esquema de la base de datos.
- **Se discute lo importante.** Con colores y tipografía la conversación se va a la estética. En baja fidelidad se habla de qué se ve primero, qué puede hacer un viewer y qué pasa con un host sin informes.
- **Accesibilidad desde el principio.** Decidir ya que ningún estado se distingue solo por color, que nada depende del hover y que las horas llevan su zona horaria cuesta una línea ahora y una refactorización después.
- **Se versiona y se revisa como código.** Texto en Markdown: diff legible en un PR y en el iPad, sin herramientas de diseño.
