#!/usr/bin/env python3
"""Almi-Chain · Plantilla de estilos de la memoria (fuentes, colores, tablas, márgenes A4).
  python3 estilos.py <carpeta de trabajo>  -> <carpeta>/ref.docx a partir de <carpeta>/ref-base.docx
"""
import sys
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
W = sys.argv[1]
d = Document(f'{W}/ref-base.docx')
S = {s.name: s for s in d.styles}
MARRON = RGBColor(0x4a, 0x24, 0x16); AMBAR = RGBColor(0xb0, 0x63, 0x14); TINTA = RGBColor(0x2b, 0x1a, 0x13)
def fuente(n, name, size=None, color=None, bold=None, italic=None):
    st = S[n]; f = st.font; f.name = name
    rpr = st.element.get_or_add_rPr(); rf = rpr.find(qn('w:rFonts'))
    if rf is None: rf = OxmlElement('w:rFonts'); rpr.insert(0, rf)
    for a in ('w:ascii','w:hAnsi','w:cs','w:eastAsia'): rf.set(qn(a), name)
    for a in ('w:asciiTheme','w:hAnsiTheme','w:cstheme','w:eastAsiaTheme'):
        if rf.get(qn(a)) is not None: del rf.attrib[qn(a)]
    if size: f.size = Pt(size)
    if color is not None: f.color.rgb = color
    if bold is not None: f.bold = bold
    if italic is not None: f.italic = italic
for n in ['Normal','Body Text','First Paragraph','Compact']: fuente(n, 'Liberation Sans', 10.5, TINTA)
for n,s,c in [('Heading 1',20,MARRON),('Heading 2',14.5,MARRON),('Heading 3',12,AMBAR),('Heading 4',11,AMBAR),('Title',30,MARRON),('Subtitle',15,AMBAR),('TOC Heading',20,MARRON)]:
    fuente(n, 'Liberation Sans', s, c, True, False)
S['Heading 1'].paragraph_format.page_break_before = True
S['Heading 1'].paragraph_format.space_after = Pt(10)
for n in ['Heading 2','Heading 3']:
    S[n].paragraph_format.space_before = Pt(14); S[n].paragraph_format.space_after = Pt(6)
for n in ['Body Text','First Paragraph']:
    S[n].paragraph_format.space_after = Pt(6); S[n].paragraph_format.line_spacing = 1.15
fuente('Verbatim Char', 'Liberation Mono', 8.5)
for n in ['Image Caption','Table Caption','Caption']: fuente(n, 'Liberation Sans', 9, RGBColor(0x6b,0x55,0x48), None, True)
fuente('Hyperlink', 'Liberation Sans', None, AMBAR)
fuente('Compact', 'Liberation Sans', 9.5, TINTA)
t = S['Table']; tblPr = t.element.find(qn('w:tblPr'))
if tblPr is None: tblPr = OxmlElement('w:tblPr'); t.element.append(tblPr)
old = tblPr.find(qn('w:tblBorders'))
if old is not None: tblPr.remove(old)
b = OxmlElement('w:tblBorders')
for side in ('top','left','bottom','right','insideH','insideV'):
    e = OxmlElement(f'w:{side}'); e.set(qn('w:val'),'single'); e.set(qn('w:sz'),'4'); e.set(qn('w:color'),'D9C7B4'); b.append(e)
tblPr.append(b)
cm = OxmlElement('w:tblCellMar')
for side,v in (('top',30),('bottom',30),('left',70),('right',70)):
    e = OxmlElement(f'w:{side}'); e.set(qn('w:w'),str(v)); e.set(qn('w:type'),'dxa'); cm.append(e)
tblPr.append(cm)
for c in t.element.findall(qn('w:tblStylePr')):
    if c.get(qn('w:type')) == 'firstRow':
        tcPr = c.find(qn('w:tcPr'))
        if tcPr is None: tcPr = OxmlElement('w:tcPr'); c.append(tcPr)
        sh = OxmlElement('w:shd'); sh.set(qn('w:val'),'clear'); sh.set(qn('w:color'),'auto'); sh.set(qn('w:fill'),'F3EADB'); tcPr.append(sh)
for s in d.sections:
    s.page_width, s.page_height = Cm(21), Cm(29.7)
    s.left_margin = s.right_margin = Cm(2.2); s.top_margin = Cm(2.2); s.bottom_margin = Cm(2)
d.save(f'{W}/ref.docx'); print('estilos ok')
