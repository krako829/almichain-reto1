#!/usr/bin/env python3
"""Almi-Chain · Convierte una transcripción de terminal en una imagen PNG con aspecto de ventana.

  pintar-terminal.py transcripcion.txt captura.png "título de la ventana" usuario@host

La transcripción la genera consola.py (transcribir): son las órdenes y su salida REAL tal cual.
Esta herramienta solo la dibuja; no cambia ni añade texto. Por eso cada captura de terminal
del repositorio tiene al lado su .txt con el mismo nombre: se puede comprobar qué pone.
Necesita Python Playwright con Chromium y las fuentes DejaVu.
"""
import html, re, sys
from playwright.sync_api import sync_playwright

txt, png, titulo, uh = sys.argv[1:5]
usuario, host = uh.split('@')
prompt = (f'<span class="u">{html.escape(usuario)}@{html.escape(host)}</span>:'
          f'<span class="d">~</span>$ ')
cuerpo = []
for linea in open(txt, encoding='utf-8').read().rstrip('\n').split('\n'):
    if linea.startswith('$ '):
        cuerpo.append(prompt + html.escape(linea[2:]))
    else:
        cuerpo.append(html.escape(linea))
cuerpo.append(prompt + '<span class="c"> </span>')
pagina = f'''<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;background:#fff}}
#v{{display:inline-block;min-width:860px;max-width:1180px;margin:10px;border-radius:9px;overflow:hidden;
   box-shadow:0 2px 10px rgba(0,0,0,.35);background:#2b2b2b}}
.t{{background:#3c3c3c;color:#e8e8e8;font:13px "DejaVu Sans";padding:8px 12px;text-align:center;position:relative}}
.t i{{position:absolute;left:12px;top:9px}} .t i b{{display:inline-block;width:12px;height:12px;border-radius:6px;margin-right:6px;background:#5e5e5e}}
pre{{margin:0;padding:10px 14px 14px;color:#f0f0f0;font:13.5px/1.35 "DejaVu Sans Mono";white-space:pre-wrap;word-break:break-all}}
.u{{color:#8ae234;font-weight:bold}} .d{{color:#729fcf;font-weight:bold}} .c{{background:#f0f0f0}}
</style></head><body><div id="v"><div class="t"><i><b></b><b></b><b></b></i>{html.escape(titulo)}</div>
<pre>{chr(10).join(cuerpo)}</pre></div></body></html>'''
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={'width': 1220, 'height': 400}, device_scale_factor=1)
    pg.set_content(pagina)
    pg.locator('#v').screenshot(path=png)
    b.close()
print(png)
