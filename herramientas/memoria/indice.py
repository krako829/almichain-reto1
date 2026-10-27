#!/usr/bin/env python3
# Almi-Chain · LibreOffice (escuchando en el puerto 2002): actualiza el índice y guarda en Word y PDF
#   python3 indice.py entrada.docx salida.docx salida.pdf
# LibreOffice: actualizar el índice (números de página) y guardar en Word y PDF
import uno, sys
from com.sun.star.beans import PropertyValue
def pv(n,v): p=PropertyValue(); p.Name=n; p.Value=v; return p
ctx = uno.getComponentContext()
smgr = ctx.ServiceManager
res = smgr.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", ctx)
c = res.resolve("uno:socket,host=localhost,port=2002;urp;StarOffice.ComponentContext")
desk = c.ServiceManager.createInstanceWithContext("com.sun.star.frame.Desktop", c)
doc = desk.loadComponentFromURL("file://"+sys.argv[1], "_blank", 0, (pv("Hidden",True),))
# La portada sin número de página: su primer párrafo usa el estilo de página "First Page"
# (sin pie) y el índice empieza en una página nueva con el estilo normal
texto = doc.getText(); cur = texto.createTextCursor(); cur.gotoStart(False)
cur.setPropertyValue("PageDescName", "First Page")
idx = doc.getDocumentIndexes()
if idx.getCount():
    ancla = idx.getByIndex(0).getAnchor()
    c2 = texto.createTextCursorByRange(ancla.getStart())
    c2.setPropertyValue("PageDescName", "Default Page Style")
for i in range(idx.getCount()): idx.getByIndex(i).Title = "Índice"
for i in range(idx.getCount()): idx.getByIndex(i).update()
doc.refresh()
for i in range(idx.getCount()): idx.getByIndex(i).update()
doc.storeToURL("file://"+sys.argv[2], (pv("FilterName","MS Word 2007 XML"),))
doc.storeToURL("file://"+sys.argv[3], (pv("FilterName","writer_pdf_Export"),))
doc.close(True); print('toc ok')
