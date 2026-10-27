#!/usr/bin/env python3
"""Almi-Chain · Junta los README del repositorio en un solo Markdown para la memoria.

  python3 juntar.py <carpeta de trabajo>      (lo llama generar.sh)

- Junta los README en el orden de la memoria y, al final, los anexos.
- Convierte los diagramas Mermaid en imágenes (mmdc, la CLI de Mermaid).
- Pone las rutas de las imágenes absolutas, numera las figuras ("Figura N.") y les da tamaño.
- Los enlaces a archivos del repositorio se convierten en texto con su ruta (el repositorio es
  privado: un enlace a GitHub no le serviría al lector de la memoria). Los enlaces web se quedan.
- En los anexos baja un nivel los títulos, para que cuelguen del capítulo "Anexos".
"""
import hashlib, os, re, subprocess, sys
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
W = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else 'trabajo')
os.makedirs(f'{W}/mmd', exist_ok=True)

CAPITULOS = [
    ('README.md', 'Introducción'),
    ('00-gestion/README.md', None),
    ('01-windows-gerente-tpv/README.md', None),
    ('02-linux-recreativa/README.md', None),
    ('03-arcade-stick/README.md', None),
    ('04-red/README.md', None),
    ('05-erp-odoo/README.md', None),
    ('06-web-aws/README.md', None),
    ('07-bd-raid-copias/README.md', None),
    ('presupuesto/README.md', None),
    ('docs/conclusiones.md', None),
]
ANEXOS = [
    ('docs/maquinas-virtuales.md', 'Anexo A. Máquinas virtuales exportadas'),
    ('04-red/routers/configuracion-routers.md', 'Anexo B. Routers reales y repetidor WDS'),
    ('06-web-aws/docs/02-guia-despliegue.md', 'Anexo C. Web: guía de despliegue'),
    ('06-web-aws/docs/03-explicacion-codigo.md', 'Anexo D. Web: explicación del código'),
    ('herramientas/README.md', 'Anexo E. Herramientas: cómo se hicieron las VM, las pruebas y las capturas'),
]
figura = 0


def mermaid_png(codigo):
    h = hashlib.sha1(codigo.encode()).hexdigest()[:12]
    png = f'{W}/mmd/{h}.png'
    if not os.path.exists(png):
        open(f'{W}/mmd/{h}.mmd', 'w').write(codigo)
        # Ancho grande y escala 2: las etiquetas largas no se cortan y se leen al imprimir
        subprocess.run(['mmdc', '-i', f'{W}/mmd/{h}.mmd', '-o', png, '-w', '1800', '-s', '2',
                        '-b', 'white', '-t', 'neutral'], check=True, stdout=subprocess.DEVNULL)
    return png


def recortar(png):
    """Quita el blanco de alrededor (el modelo de datos tiene mucho) y devuelve la ruta."""
    im = Image.open(png).convert('RGB')
    fondo = Image.new('RGB', im.size, (255, 255, 255))
    from PIL import ImageChops
    caja = ImageChops.difference(im, fondo).getbbox()
    if not caja or caja == (0, 0) + im.size:
        return png
    salida = f'{W}/recorte-{os.path.basename(png)}'
    im.crop((max(caja[0] - 10, 0), max(caja[1] - 10, 0), min(caja[2] + 10, im.width), min(caja[3] + 10, im.height))).save(salida)
    return salida


def procesar(ruta, titulo, anexo=False):
    global figura
    base = os.path.dirname(ruta)
    md = open(f'{REPO}/{ruta}', encoding='utf-8').read()
    if titulo:
        md = re.sub(r'^# .*$', f'# {titulo}', md, count=1, flags=re.M)
    if anexo:  # todos los títulos un nivel más abajo; el H1 pasa a H2 del capítulo "Anexos"
        md = re.sub(r'^(#{1,5}) ', lambda m: '#' + m.group(1) + ' ', md, flags=re.M)

    def figura_de(m):
        """Imágenes y diagramas Mermaid en una sola pasada, para numerarlos en orden."""
        global figura
        figura += 1
        if m.group(1):  # bloque ```mermaid
            return f'\n![Figura {figura}. Diagrama]({mermaid_png(m.group(1))}){{width=16cm}}\n'
        alt, src = m.group(2), m.group(3)
        if not src.startswith('/'):
            src = os.path.normpath(f'{REPO}/{base}/{src}')
        ancho = '5.2cm' if 'ticket' in src else '16cm'
        if 'modelo-er' in src:
            src = recortar(src)
        texto = f'Figura {figura}. {alt}' if alt else f'Figura {figura}.'
        return f'![{texto}]({src}){{width={ancho}}}'
    md = re.sub(r'```mermaid\n(.*?)```|!\[([^\]]*)\]\(([^)]+)\)', figura_de, md, flags=re.S)

    def enlace(m):
        texto, href = m.group(1), m.group(2)
        if re.match(r'^(https?:|mailto:)', href):
            return m.group(0)
        if href.startswith('#'):
            return texto
        destino = os.path.normpath(os.path.join(base, href.split('#')[0])) if href.split('#')[0] else base
        destino = destino.replace('\\', '/')
        if destino in ('.', ''):
            destino = 'raíz del repositorio'
        limpio = texto.strip('`')
        # Si el texto ya es la ruta (o el nombre del archivo), no se repite
        if limpio.rstrip('/') in (destino, os.path.basename(destino)) or destino.endswith(limpio.rstrip('/')):
            return f'`{destino}`'
        return f'{texto} (`{destino}`)'
    md = re.sub(r'(?<!!)\[([^\]]+)\]\(([^)]+)\)', enlace, md)
    # Las rutas de Windows en código pierden la barra invertida en Word si van fuera de `...`
    return md


partes = [procesar(p, t) for p, t in CAPITULOS if os.path.exists(f'{REPO}/{p}')]
partes.append('# Anexos\n\nDocumentos que amplían algún capítulo. Están también en el repositorio, en la ruta que se indica en cada uno.\n')
partes += [procesar(p, t, anexo=True) for p, t in ANEXOS if os.path.exists(f'{REPO}/{p}')]
open(f'{W}/documentacion.md', 'w', encoding='utf-8').write('\n\n'.join(partes))
print(f'Markdown listo: {sum(len(x) for x in partes)} caracteres, {figura} figuras')
