#!/usr/bin/env python3
"""Almi-Chain · Monta docs/manual.md (el manual paso a paso) a partir de los README de cada bloque.

De cada README coge solo las secciones que sirven como manual (objetivo, requisitos, pasos,
comprobaciones de restauración o fallo y solución de problemas) y deja fuera las tablas de estado,
la seguridad resumida y las fuentes. Las rutas de imágenes y enlaces se corrigen para docs/.

  python3 herramientas/memoria/manual.py
"""
import os, re

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
VIDEO = 'https://drive.google.com/file/d/1sB5696oLMcich_KJwhIkgUCDqDXQG4Dg/view'

# (carpeta, título del capítulo, [(sección del README, título en el manual o None), ...])
BLOQUES = [
    ('01-windows-gerente-tpv', 'Puestos Windows: gerente con arranque dual y TPV', [
        ('Objetivo', None), ('Requisitos', None),
        ('Instalación hecha en clase: ALMI-DUAL y ALMI-TPV', 'Instalación paso a paso'),
        ('Instalación y configuración paso a paso', 'Configuración completa con los scripts'),
        ('Problemas previstos y solución', 'Solución de problemas'),
    ]),
    ('02-linux-recreativa', 'Máquina recreativa con MAME', [
        ('Objetivo', None), ('Requisitos', None), ('Arquitectura', 'Cómo funciona'),
        ('Instalación y configuración paso a paso', 'Instalación paso a paso'),
        ('Problemas encontrados y solución', 'Solución de problemas'),
    ]),
    ('03-arcade-stick', 'Arcade stick con Arduino', [
        ('Objetivo', None), ('Requisitos', None), ('Arquitectura y cableado', 'Cableado'),
        ('Programas', None), ('Instalación paso a paso', None),
        ('VIDEO', 'El arcade stick funcionando'),
        ('Problemas previstos y solución', 'Solución de problemas'),
    ]),
    ('04-red', 'Red del restaurante', [
        ('Objetivo', None), ('Línea WAN', None),
        ('Red final en Packet Tracer', 'Red en Packet Tracer'),
        ('Routers reales', 'Routers reales y repetidor WDS'),
    ]),
    ('05-erp-odoo', 'ERP Odoo con TPV', [
        ('Objetivo', None),
        ('Instalación hecha en clase', 'Instalación paso a paso'),
        ('5. Aplicaciones, empresa, usuarios, productos, TPV y regla', 'Configuración de Odoo: aplicaciones, usuarios, productos y TPV'),
        ('6. Prueba de principio a fin', 'Prueba: venta en el TPV y factura automática'),
        ('7. Copia de seguridad de Odoo', 'Copia de seguridad de Odoo'),
        ('9. Disco redundante del servidor', 'Disco redundante del servidor (RAID 1)'),
    ]),
    ('06-web-aws', 'Web del restaurante en AWS', [
        ('Objetivo', None), ('Requisitos', None), ('Arquitectura', 'Cómo funciona'),
        ('Archivos', None), ('Despliegue paso a paso', None),
        ('Problemas previstos y solución', 'Solución de problemas'),
    ]),
    ('07-bd-raid-copias', 'Base de datos con RAID 1 y copias', [
        ('Objetivo', None), ('Requisitos', None), ('Arquitectura', 'Cómo funciona'),
        ('Modelo de datos', None),
        ('Instalación y configuración paso a paso', 'Instalación paso a paso'),
        ('Pruebas de restauración', 'Restaurar una copia'),
        ('Prueba de fallo de disco', 'Qué hacer si falla un disco'),
        ('Problemas encontrados y solución', 'Solución de problemas'),
    ]),
    ('08-copias-so', 'Copias de seguridad de los sistemas operativos', [
        ('Objetivo', None), ('Arquitectura', 'Cómo funciona'), ('Plan de copias', None),
        ('Disco redundante (RAID 1)', None), ('Acceso SSH sin contraseña', None),
        ('Copia local', None), ('Copia remota en AWS', None), ('Automatización', None),
        ('Pruebas de restauración', 'Restaurar una copia'),
    ]),
]


def secciones(md):
    """Devuelve {(nivel, título): texto} de las secciones ## y ### (sin contar las de los bloques de código)."""
    lineas, res, actual, en_codigo = md.split('\n'), [], None, False
    for l in lineas:
        if l.startswith('```'):
            en_codigo = not en_codigo
        m = None if en_codigo else re.match(r'^(#{2,3}) (.*)$', l)
        if m:
            actual = [len(m.group(1)), m.group(2).strip(), []]
            res.append(actual)
        elif actual:
            actual[2].append(l)
    return res


def buscar(secs, nombre):
    """Texto de la sección cuyo título empieza por `nombre`, con sus subsecciones (si es ##)."""
    for i, (n, t, _) in enumerate(secs):
        if t.startswith(nombre):
            partes = ['\n'.join(secs[i][2])]
            for n2, t2, c2 in secs[i + 1:]:
                if n2 <= n:
                    break
                partes.append(f'{"#" * (n2 + 1)} {t2}\n' + '\n'.join(c2))
            return '\n'.join(partes)
    raise SystemExit(f'No encuentro la sección «{nombre}»')


def rutas(texto, carpeta):
    """Corrige los enlaces e imágenes relativos para que funcionen desde docs/."""
    def fix(m):
        destino = m.group(2)
        if re.match(r'^(https?:|#|mailto:)', destino):
            return m.group(0)
        nueva = os.path.relpath(os.path.normpath(os.path.join(REPO, carpeta, destino)), os.path.join(REPO, 'docs'))
        return f'{m.group(1)}({nueva})'
    return re.sub(r'(!?\[[^\]]*\])\(([^)\s]+)\)', fix, texto)


def limpiar_titulo(t):
    return re.sub(r'\s*\((?:[A-Z]\d{2}[^)]*)\)', '', t).strip()


INTRO = open(os.path.join(REPO, 'docs', 'manual-intro.md'), encoding='utf-8').read().strip()
salida = [INTRO]
for n, (carpeta, titulo, partes) in enumerate(BLOQUES, start=3):
    md = open(os.path.join(REPO, carpeta, 'README.md'), encoding='utf-8').read()
    secs = secciones(md)
    trozos = [f'# {n}. {titulo}']
    for nombre, nuevo in partes:
        if nombre == 'VIDEO':
            cuerpo = (f'Vídeo de la prueba del arcade stick conectado a la recreativa y jugando en MAME: '
                      f'[abrir el vídeo en Google Drive]({VIDEO}). Para verlo desde el papel, escanear el código QR.\n\n'
                      f'![Código QR del vídeo del arcade stick funcionando](../03-arcade-stick/capturas/qr-video-stick.png)')
            trozos.append(f'## {nuevo}\n\n{cuerpo}')
            continue
        cuerpo = buscar(secs, nombre)
        cuerpo = re.sub(r'^(#{3,4}) (.*)$', lambda m: f'{m.group(1)} {limpiar_titulo(m.group(2))}', cuerpo, flags=re.M)
        trozos.append(f'## {nuevo or limpiar_titulo(nombre)}\n' + rutas(cuerpo, carpeta).strip('\n'))
    salida.append('\n\n'.join(trozos))
salida.append(open(os.path.join(REPO, 'docs', 'manual-final.md'), encoding='utf-8').read().strip())
texto = '\n\n'.join(salida) + '\n'

# La red final del reto es 192.168.0.0/24 en adaptador puente (capítulo 2): los README todavía
# conservan la red del principio en algunos sitios
SUSTITUCIONES = [
    ('ODOO_URL=https://192.168.10.30 ODOO_CA=/etc/ssl/almichain/odoo.crt', 'ODOO_URL=http://192.168.0.53:8069'),
    ('https://192.168.10.30', 'http://192.168.0.53:8069'),
    ('http://192.168.10.30', 'http://192.168.0.53'),
    ('192.168.10.30', '192.168.0.53'),
    ('192.168.10.20', '192.168.0.54'),
    ('for red in 192.168.10.0/24 192.168.99.0/24;', 'for red in 192.168.0.0/24;'),
    ('solo desde las VLAN 10 y 99', 'solo desde la red del reto'),
    ('Red NAT ALMICHAIN (DHCP)', 'Adaptador puente (192.168.0.0/24)'),
    ('· Red NAT ALMICHAIN', '· Adaptador puente'),
    ('Red NAT ALMICHAIN.', 'Adaptador puente.'),
    ('hacer el **plan de direccionamiento con VLAN**', 'hacer el **plan de direccionamiento**'),
    ('o mover ahí los volúmenes de Docker, con Odoo parado', 'o mover ahí los datos de PostgreSQL, con Odoo parado'),
    (' (ver )', ''),
    ('Se ha elegido **Odoo 18 Community**, instalado con **Docker** en la VM **ALMI-ODOO** y publicado solo por **HTTPS** con nginx.',
     'Se ha elegido **Odoo Community**, instalado en la VM **ALMI-ODOO** (`odooserver`, 192.168.0.53) con PostgreSQL 16 y accesible en el puerto **8069**.'),
    (' El envío real por Gmail está pendiente: falta poner la contraseña de aplicación de la cuenta del equipo (apartado 6, prueba 5).', ''),
]
for a, b in SUSTITUCIONES:
    texto = texto.replace(a, b)
texto = re.sub(r'Las VM de este bloque van en \*\*adaptador puente\*\*[^\n]*\n', '', texto)
texto = re.sub(r'\n{3,}', '\n\n', texto)
open(os.path.join(REPO, 'docs', 'manual.md'), 'w', encoding='utf-8').write(texto)
print('docs/manual.md listo')
