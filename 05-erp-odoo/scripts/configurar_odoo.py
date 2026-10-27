#!/usr/bin/env python3
"""
Almi-Chain · Configuración de Odoo 18 por XML-RPC (pasos 6.6 a 6.11 de la guía)

Hace lo mismo que los pasos a mano de la guía, para poder rehacer la configuración
en minutos si hay que reinstalar Odoo:
  - Instala las aplicaciones (Facturación, TPV, CRM, Empleados, Marketing, Inventario
    y Reglas de automatización)
  - Datos de la empresa
  - Usuarios con mínimo privilegio (Gerente, Camarero Barra 1 y 2) y 4 empleados
  - IVA 10 % incluido, 8 productos con stock inicial y 3 clientes
  - Los dos TPV (Barra 1 y Barra 2) con efectivo, tarjeta, cabecera/pie e impresión automática
  - Servidor de correo de Gmail (sin contraseña: se pone a mano desde Odoo)
  - La regla de automatización de factura automática (el envío por correo lo hace Odoo)

Las contraseñas NO están en el script: se leen de variables de entorno.
  export ODOO_URL=https://192.168.10.30
  export ODOO_ADMIN_LOGIN=...  ODOO_ADMIN_PASS=...
  export ODOO_GERENTE_PASS=... ODOO_BARRA1_PASS=... ODOO_BARRA2_PASS=...
  python3 configurar_odoo.py

Se puede ejecutar varias veces: si algo ya existe, lo actualiza en vez de duplicarlo.
"""
import base64
import io
import os
import ssl
import sys
import xmlrpc.client

URL = os.environ.get("ODOO_URL", "https://192.168.10.30")
DB = os.environ.get("ODOO_DB", "almichain")
LOGIN = os.environ["ODOO_ADMIN_LOGIN"]
PASSWORD = os.environ["ODOO_ADMIN_PASS"]
# El certificado propio de nginx (paso 6.4). Si no se indica, se usa el del sistema.
CA = os.environ.get("ODOO_CA", "")

ctx = ssl.create_default_context(cafile=CA) if CA else ssl.create_default_context()
common = xmlrpc.client.ServerProxy(f"{URL}/xmlrpc/2/common", context=ctx)
uid = common.authenticate(DB, LOGIN, PASSWORD, {})
if not uid:
    sys.exit("No se ha podido iniciar sesión en Odoo: revisa usuario y contraseña")
models = xmlrpc.client.ServerProxy(f"{URL}/xmlrpc/2/object", context=ctx, allow_none=True)


def call(model, method, *args, **kw):
    try:
        return models.execute_kw(DB, uid, PASSWORD, model, method, list(args), kw)
    except xmlrpc.client.Fault as e:
        # Algunos métodos de Odoo (botones) no devuelven nada: XML-RPC no sabe enviar
        # "None", pero la acción ya se ha hecho y guardado.
        if "cannot marshal None" in e.faultString:
            return None
        raise


def ref(xmlid):
    """Devuelve el id de un registro a partir de su id externo (módulo.nombre)."""
    module, name = xmlid.split(".")
    r = call("ir.model.data", "search_read", [["module", "=", module], ["name", "=", name]],
             fields=["res_id"], limit=1)
    if not r:
        raise ValueError(f"No existe {xmlid}")
    return r[0]["res_id"]


def upsert(model, domain, values):
    """Crea el registro o lo actualiza si ya existe."""
    ids = call(model, "search", domain, limit=1, context={"active_test": False})
    if ids:
        call(model, "write", ids, values)
        return ids[0]
    return call(model, "create", values)


def paso(texto):
    print(f"==> {texto}", flush=True)


# ---------------------------------------------------------------- 6.6 Aplicaciones
paso("Instalando aplicaciones")
APPS = ["account", "point_of_sale", "crm", "hr", "mass_mailing", "stock", "base_automation"]
pendientes = call("ir.module.module", "search", [["name", "in", APPS], ["state", "!=", "installed"]])
if pendientes:
    call("ir.module.module", "button_immediate_install", pendientes)
for m in call("ir.module.module", "search_read", [["name", "in", APPS]], fields=["name", "shortdesc", "state"]):
    print(f"    {m['shortdesc']:<35} {m['state']}")

# ---------------------------------------------------------------- 6.7 Empresa
paso("Datos de la empresa")
spain = ref("base.es")
bizkaia = call("res.country.state", "search", [["country_id", "=", spain], ["code", "=", "BI"]], limit=1)
call("res.company", "write", [1], {
    "name": "Almi Bites Restaurantes",
    "street": "Calle Licenciado Poza 31",
    "city": "Bilbao",
    "zip": "48011",
    "country_id": spain,
    "state_id": bizkaia[0] if bizkaia else False,
    "email": "almichain.reto@gmail.com",
    "phone": "+34 944 000 000",
    "website": "https://almichain2.duckdns.org",
    "company_registry": "Ficticia · Reto 1 ASIR",
    "currency_id": ref("base.EUR"),
})

# Logotipo (sale en el TPV, los tickets y las facturas)
logo = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "config", "logo-almichain.png")
if os.path.exists(logo):
    with open(logo, "rb") as f:
        call("res.company", "write", [1], {"logo": base64.b64encode(f.read()).decode()})

# Los PDF (facturas) los genera wkhtmltopdf DENTRO del contenedor: tiene que pedir los estilos
# a Odoo directamente y no a https://192.168.10.30 (certificado propio, se queda esperando)
upsert("ir.config_parameter", [["key", "=", "report.url"]], {"key": "report.url", "value": "http://127.0.0.1:8069"})
# Dirección pública fija: Odoo la usa en los enlaces de los correos. Sin "freeze", el primer
# administrador que entre por otra dirección (p. ej. https://localhost:8443) la cambiaría.
upsert("ir.config_parameter", [["key", "=", "web.base.url"]], {"key": "web.base.url", "value": URL})
upsert("ir.config_parameter", [["key", "=", "web.base.url.freeze"]], {"key": "web.base.url.freeze", "value": "True"})

# ---------------------------------------------------------------- 6.7 Usuarios
paso("Usuarios con mínimo privilegio")
grupos_gerente = [
    "base.group_user",
    "account.group_account_invoice",          # Facturación: Facturación
    "point_of_sale.group_pos_manager",        # Punto de venta: Administrador
    "sales_team.group_sale_manager",          # CRM: Administrador
    "hr.group_hr_manager",                    # Empleados: Administrador
    "stock.group_stock_manager",              # Inventario: Administrador
    "mass_mailing.group_mass_mailing_user",   # Marketing por correo: Usuario
]
grupos_barra = ["base.group_user", "point_of_sale.group_pos_user"]  # Punto de venta: Usuario

usuarios = {}
for clave, nombre, login, grupos in [
    ("GERENTE", "Gerente", "gerente@almichain.local", grupos_gerente),
    ("BARRA1", "Camarero Barra 1", "barra1@almichain.local", grupos_barra),
    ("BARRA2", "Camarero Barra 2", "barra2@almichain.local", grupos_barra),
]:
    uid_u = upsert("res.users", [["login", "=", login]], {
        "name": nombre,
        "login": login,
        "email": login,
        "lang": "es_ES",
        "tz": "Europe/Madrid",
        "groups_id": [(6, 0, [ref(g) for g in grupos])],
    })
    partner = call("res.users", "read", [uid_u], fields=["partner_id"])[0]["partner_id"][0]
    call("res.partner", "write", [partner], {"email": login})
    pwd = os.environ.get(f"ODOO_{clave}_PASS")
    if pwd:
        call("res.users", "write", [uid_u], {"password": pwd})
    usuarios[clave] = uid_u
    print(f"    {nombre:<20} {login}")

# ---------------------------------------------------------------- 6.7 Empleados
paso("Departamentos, puestos y empleados")
dep = {n: upsert("hr.department", [["name", "=", n]], {"name": n}) for n in ["Dirección", "Sala", "Cocina"]}
# Al crear un usuario, Odoo crea solo su ficha de empleado: se reutiliza esa ficha
EMPLEADOS = [
    ("Gorka Larrea Ibarra", "Gerente", "Dirección", usuarios["GERENTE"]),
    ("Nerea Olabarria Sanz", "Camarera", "Sala", usuarios["BARRA1"]),
    ("Asier Landa Mendieta", "Camarero", "Sala", usuarios["BARRA2"]),
    ("Miren Agirre Elorza", "Cocinera", "Cocina", False),
]
for nombre, puesto, d, user in EMPLEADOS:
    job = upsert("hr.job", [["name", "=", puesto]], {"name": puesto, "department_id": dep[d]})
    buscar = [["user_id", "=", user]] if user else [["name", "=", nombre]]
    upsert("hr.employee", buscar, {
        "name": nombre, "job_id": job, "job_title": puesto,
        "department_id": dep[d], "user_id": user,
    })
    print(f"    {nombre:<22} {puesto:<10} {d}")

# ---------------------------------------------------------------- 6.8 IVA 10 %
paso("IVA del 10 % (hostelería), precio con IVA incluido")
iva10_existe = call("account.tax", "search", [["name", "=", "IVA 10% hostelería"], ["type_tax_use", "=", "sale"]], limit=1)
if iva10_existe:
    # Ya creado: no se toca (Odoo no deja cambiar un impuesto usado en un TPV abierto)
    iva10 = iva10_existe[0]
else:
    iva10 = call("account.tax", "create", {
        "name": "IVA 10% hostelería",
        "description": "IVA 10%",
        "amount": 10.0,
        "amount_type": "percent",
        "type_tax_use": "sale",
        "price_include_override": "tax_included",
        "company_id": 1,
    })
    # Usa las mismas cuentas y grupo que el IVA 10 % del plan contable español
    base10 = call("account.tax", "search_read",
                  [["amount", "=", 10], ["type_tax_use", "=", "sale"], ["id", "!=", iva10], ["company_id", "=", 1]],
                  fields=["tax_group_id", "invoice_repartition_line_ids", "refund_repartition_line_ids", "name"], limit=1)
    if base10:
        vals = {"tax_group_id": base10[0]["tax_group_id"][0]}
        for campo_rep in ("invoice_repartition_line_ids", "refund_repartition_line_ids"):
            lineas = call("account.tax.repartition.line", "read", base10[0][campo_rep],
                          fields=["repartition_type", "factor_percent", "account_id", "tag_ids"])
            vals[campo_rep] = [(5, 0, 0)] + [(0, 0, {
                "repartition_type": l["repartition_type"],
                "factor_percent": l["factor_percent"],
                "account_id": l["account_id"][0] if l["account_id"] else False,
                "tag_ids": [(6, 0, l["tag_ids"])],
            }) for l in lineas]
        call("account.tax", "write", [iva10], vals)

# ---------------------------------------------------------------- 6.8 Productos
paso("Categorías del TPV y productos")
cat = {n: upsert("pos.category", [["name", "=", n]], {"name": n}) for n in ["Bebidas", "Platos"]}


def icono(texto, color):
    """Imagen sencilla del producto para que el TPV quede visual (si hay Pillow)."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return False
    img = Image.new("RGB", (256, 256), color)
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
    except OSError:
        f = ImageFont.load_default()
    palabras, lineas, actual = texto.split(), [], ""
    for p in palabras:
        if d.textlength((actual + " " + p).strip(), font=f) > 220:
            lineas.append(actual)
            actual = p
        else:
            actual = (actual + " " + p).strip()
    lineas.append(actual)
    y = 128 - len(lineas) * 22
    for l in lineas:
        d.text((128 - d.textlength(l, font=f) / 2, y), l, font=f, fill="white")
        y += 44
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


PRODUCTOS = [
    ("Agua mineral", 1.80, "Bebidas", "#2e86c1"),
    ("Refresco de cola", 2.50, "Bebidas", "#922b21"),
    ("Caña de cerveza", 2.20, "Bebidas", "#d4ac0d"),
    ("Café con leche", 1.70, "Bebidas", "#6e4b3a"),
    ("Croquetas caseras", 7.50, "Platos", "#ca6f1e"),
    ("Hamburguesa Almi", 12.50, "Platos", "#a04000"),
    ("Bacalao al pil-pil", 16.90, "Platos", "#5d6d7e"),
    ("Tarta de queso", 5.20, "Platos", "#b7950b"),
]
productos = {}
for nombre, precio, c, color in PRODUCTOS:
    vals = {
        "name": nombre, "list_price": precio, "type": "consu", "is_storable": True,
        "taxes_id": [(6, 0, [iva10])], "available_in_pos": True,
        "pos_categ_ids": [(6, 0, [cat[c]])], "sale_ok": True,
    }
    img = icono(nombre, color)
    if img:
        vals["image_1920"] = img
    productos[nombre] = upsert("product.template", [["name", "=", nombre]], vals)
    print(f"    {nombre:<20} {precio:>6.2f} €  {c}")

paso("Stock inicial: 50 unidades de cada producto")
stock_loc = call("stock.warehouse", "search_read", [["company_id", "=", 1]], fields=["lot_stock_id"], limit=1)[0]["lot_stock_id"][0]
for nombre, tmpl in productos.items():
    prod = call("product.product", "search", [["product_tmpl_id", "=", tmpl]], limit=1)[0]
    qty = call("product.product", "read", [prod], fields=["qty_available"])[0]["qty_available"]
    if qty == 0:
        q = call("stock.quant", "create", {"product_id": prod, "location_id": stock_loc, "inventory_quantity": 50})
        call("stock.quant", "action_apply_inventory", [q])

# ---------------------------------------------------------------- 6.8 Clientes
paso("Clientes")
CLIENTES = [
    ("Ane Etxeberria", "ane.etxeberria@example.com", "Bilbao"),
    ("Jon Arrieta", "jon.arrieta@example.com", "Getxo"),
    ("Lucía Martín", "lucia.martin@example.com", "Barakaldo"),
]
for nombre, email, ciudad in CLIENTES:
    upsert("res.partner", [["name", "=", nombre]], {
        "name": nombre, "email": email, "city": ciudad, "country_id": spain, "customer_rank": 1,
    })
    print(f"    {nombre:<16} {email}")

# ---------------------------------------------------------------- 6.9 TPV
paso("Puntos de venta Barra 1 y Barra 2")
diario_banco = call("account.journal", "search", [["type", "=", "bank"], ["company_id", "=", 1]], limit=1)[0]
call("account.journal", "write", [diario_banco], {"name": "Banco"})
tarjeta = upsert("pos.payment.method", [["journal_id", "=", diario_banco]], {"name": "Tarjeta", "journal_id": diario_banco})
# Odoo no deja compartir el pago en efectivo entre dos TPV: cada barra tiene su caja
caja1 = call("account.journal", "search", [["type", "=", "cash"], ["company_id", "=", 1]], order="id", limit=1)[0]
call("account.journal", "write", [caja1], {"name": "Efectivo Barra 1"})
caja2 = upsert("account.journal", [["code", "=", "CSH2"]], {"name": "Efectivo Barra 2", "type": "cash", "code": "CSH2"})
efectivo1 = upsert("pos.payment.method", [["journal_id", "=", caja1]], {"name": "Efectivo Barra 1", "journal_id": caja1})
efectivo2 = upsert("pos.payment.method", [["journal_id", "=", caja2]], {"name": "Efectivo Barra 2", "journal_id": caja2})
diario_facturas = call("account.journal", "search", [["type", "=", "sale"], ["company_id", "=", 1]], limit=1)
comun = {
    "is_header_or_footer": True,
    "receipt_header": "Almi Bites · Grupo Almi-Chain\nNIF B00000000 (ficticio)\nCalle Licenciado Poza 31 · 48011 Bilbao",
    "receipt_footer": "Gracias por su visita\nwww.almichain2.duckdns.org",
    "iface_print_auto": True,
    "iface_print_skip_screen": True,
    "invoice_journal_id": diario_facturas[0],
    "limit_categories": True,
    "iface_available_categ_ids": [(6, 0, list(cat.values()))],
}
existentes = call("pos.config", "search", [], order="id")
barra1 = existentes[0] if existentes else call("pos.config", "create", {"name": "Barra 1"})
call("pos.config", "write", [barra1], dict(comun, name="Barra 1", payment_method_ids=[(6, 0, [efectivo1, tarjeta])]))
barra2 = upsert("pos.config", [["name", "=", "Barra 2"]], dict(comun, name="Barra 2", payment_method_ids=[(6, 0, [efectivo2, tarjeta])]))
for c in call("pos.config", "read", [barra1, barra2], fields=["name"]):
    print(f"    {c['name']:<8} {URL}/pos/ui?config_id={c['id']}")

# ---------------------------------------------------------------- 6.10 Correo saliente
paso("Servidor de correo saliente (Gmail)")
upsert("ir.mail_server", [["name", "=", "Gmail"]], {
    "name": "Gmail", "smtp_host": "smtp.gmail.com", "smtp_port": 587,
    "smtp_encryption": "starttls", "smtp_authentication": "login",
    "smtp_user": "almichain.reto@gmail.com",
    # La contraseña de aplicación se escribe a mano en Odoo (guardada en KeePassXC)
})

# ---------------------------------------------------------------- 6.11 Automatización
paso("Reglas de automatización")


def campo(model, name):
    return call("ir.model.fields", "search", [["model", "=", model], ["name", "=", name]], limit=1)[0]


def valor_seleccion(model, field, value):
    return call("ir.model.fields.selection", "search",
                [["field_id", "=", campo(model, field)], ["value", "=", value]], limit=1)[0]


m_pos = call("ir.model", "search", [["model", "=", "pos.order"]])[0]
m_move = call("ir.model", "search", [["model", "=", "account.move"]])[0]

accion1 = upsert("ir.actions.server", [["name", "=", "TPV - Crear y publicar factura"]], {
    "name": "TPV - Crear y publicar factura",
    "model_id": m_pos, "state": "code", "usage": "base_automation",
    "code": "for order in records:\n"
            "    if order.partner_id and not order.account_move:\n"
            "        order.action_pos_order_invoice()\n",
})
upsert("base.automation", [["name", "=", "TPV - Facturar pedidos con cliente"]], {
    "name": "TPV - Facturar pedidos con cliente",
    "model_id": m_pos,
    "trigger": "on_state_set",
    "trigger_field_ids": [(6, 0, [campo("pos.order", "state")])],
    "trg_selection_field_id": valor_seleccion("pos.order", "state", "paid"),
    "filter_domain": "[('partner_id', '!=', False), ('to_invoice', '=', False), ('account_move', '=', False)]",
    "action_server_ids": [(6, 0, [accion1])],
    "active": True,
})

# Regla 2 (envío por correo): NO hace falta en Odoo 18. Al facturar un pedido del TPV,
# Odoo ya envía la factura en PDF al correo del cliente con la plantilla "Factura".
# La probamos y el cliente recibía dos correos (uno sin PDF), así que no se crea.
# Si existía de una ejecución anterior, se archiva.
vieja = call("base.automation", "search", [["name", "=", "Facturas TPV - Enviar al cliente"]])
if vieja:
    call("base.automation", "write", vieja, {"active": False})

for r in call("base.automation", "search_read", [], fields=["name", "model_name", "trigger", "active"]):
    print(f"    {r['name']:<40} {r['model_name']:<12} {r['trigger']}")

paso("Configuración terminada")
