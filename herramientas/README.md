# Herramientas

Esta carpeta no es un bloque del reto: contiene el generador de la documentación.

## Generar la documentación en Word y PDF

[`memoria/generar.sh`](memoria/generar.sh) junta los README de todos los bloques en `docs/Documentacion-Reto1-Almi-Chain.docx` y `.pdf`:

```bash
bash herramientas/memoria/generar.sh
```

Necesita pandoc 3, `python3-docx`, Pillow, `mmdc` (la CLI de Mermaid) y LibreOffice. Los enlaces a archivos del repositorio salen como su ruta, las figuras se numeran solas y los diagramas Mermaid se convierten en imágenes.

El orden de los capítulos y los anexos está en [`memoria/juntar.py`](memoria/juntar.py).
