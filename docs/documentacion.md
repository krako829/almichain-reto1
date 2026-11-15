# Introducción

**Equipo:** Alberto, Oier, Julen, Gontzal y Richar · 1.º ASIR · Almi · Octubre y noviembre de 2026

Hemos montado la informática de **Almi Bites**, un restaurante de la cadena Almi-Chain: los puestos Windows, una máquina recreativa con su mando, la red del local, un ERP con TPV, la base de datos con disco redundante y copias de seguridad, y la web del restaurante en AWS. Todo se ha hecho en máquinas virtuales de VirtualBox en los PC de clase, salvo los routers, la impresora y el arcade stick, que son físicos.

El detalle de cada parte (todas las órdenes, scripts y capturas) está en el repositorio de GitHub, en la carpeta de cada bloque.

# 1. Organización del equipo

- **Tablero Kanban** con las tareas del reto y quién se encarga de cada una (`00-gestion/tablero`).
- **GitHub** para guardar el trabajo: una carpeta por bloque, con sus pasos, scripts y capturas.
- **KeePassXC** para las contraseñas (archivo `almichain.kdbx`). En el repositorio no hay ninguna contraseña.

# 2. Red del laboratorio

El router R1 se conecta a la red de clase (192.168.1.0/24) y crea la red del reto, **192.168.0.0/24**. Todas las máquinas virtuales están en **adaptador puente** dentro de esa red, con IP fija.

![Esquema de la red del reto](../diagramas/arquitectura-global.png)

| Equipo | IP |
|---|---|
| Router R1 | 192.168.0.1 (WAN 192.168.1.150) |
| Router R2 (repetidor WDS) | 192.168.0.60 |
| Servidor de copias | 192.168.0.52 |
| ALMI-GERENTE (Windows 10 + Debian 13) | 192.168.0.63 |
| ALMI-ODOO | 192.168.0.70 |
| ALMI-BD | 192.168.0.71 |
| ALMI-TPV | 192.168.0.80 |
| ALMI-ARCADE | 192.168.0.90 |
| PC de clase | 192.168.0.100 |

# 3. Puestos Windows: gerente con arranque dual y TPV

**Equipo del gerente (ALMI-DUAL):**

1. Crear la VM en VirtualBox: 3 GB de RAM, 2 CPU y disco de 60 GB.
2. Instalar Windows 10 en una partición de 40 GB y dejar 20 GB sin asignar.
3. Crear el usuario administrador `almiadmin`, la cuenta del gerente e instalar las Guest Additions.
4. Instalar Debian 13 en el espacio libre (particionado manual) y GRUB en el disco.
5. Comprobar que GRUB deja elegir entre Debian y Windows.

![Disco del gerente: Windows en 40 GB y 20 GB libres para Debian](../01-windows-gerente-tpv/capturas/paso-29-dual-win.png)

![Menú de GRUB con Debian y Windows 10](../01-windows-gerente-tpv/capturas/paso-61-dual-debian.png)

**TPV de las barras (ALMI-TPV):**

1. Instalar Windows 10 y crear `almiadmin` como administrador.
2. Crear los usuarios TPV1 y TPV2 como **usuarios estándar** (sin permisos de administrador).
3. Política de contraseñas con `net accounts`: 12 caracteres, caducan a los 90 días y bloqueo tras 5 fallos.
4. UAC al máximo, antivirus y cortafuegos activos.

![Usuarios TPV1 y TPV2; en Administradores solo están almiadmin y el Administrador desactivado](../01-windows-gerente-tpv/capturas/paso-70-tpv.png)

![Política de contraseñas aplicada](../01-windows-gerente-tpv/capturas/paso-71-tpv.png)

# 4. Máquina recreativa

1. VM con **1 núcleo, 1 GB de RAM y sin swap**.
2. Instalar Ubuntu Server en modo mínimo.
3. Crear el usuario `arcade` sin permisos de administrador, que inicia sesión solo.
4. Instalar un entorno gráfico mínimo y **MAME**, y hacer que al arrancar se abra MAME directamente.
5. Desactivar los servicios que no hacen falta y ajustar MAME para que vaya fluido.
6. Comprobar con `vmstat` que no se usa swap mientras se juega.

![Arranque directo en MAME](../02-linux-recreativa/capturas/01-arranque-mame.png)

![1 núcleo, 1 GB y swap a 0](../02-linux-recreativa/capturas/02-nucleo-memoria-swap.png)

# 5. Arcade stick con Arduino

1. Cablear el joystick (4 direcciones) y los botones a los pines del Arduino; cada botón va entre su pin y GND.
2. Cargar el programa (`03-arcade-stick/sketches`), que hace que el Arduino funcione como **mando USB**: el ordenador lo reconoce sin instalar drivers.
3. El programa incluye antirrebote y permite cambiar qué hace cada botón desde el monitor serie, sin volver a programarlo.
4. Probar el mando en la recreativa jugando en MAME.

# 6. Red del restaurante

1. **Diseño**: red separada por **VLAN** (gestión, TPV, clientes y administración) para que la Wi-Fi de los clientes no llegue a los TPV ni a los servidores.
2. **Packet Tracer**: router, switch, servidores, TPV y punto de acceso Wi-Fi con las VLAN y las reglas entre ellas.
3. **Router principal (R1)**: contraseña de administración cambiada, Wi-Fi con WPA2 y la red del reto 192.168.0.0/24 con su DHCP.
4. **Router secundario (R2)**: configurado como **repetidor WDS** de R1, sin DHCP, para ampliar la cobertura.
5. **Línea WAN**: comparación de operadores para elegir la fibra del restaurante.

# 7. ERP Odoo con TPV

1. VM con Ubuntu Server e instalación de **Docker**.
2. Odoo 18 y su base de datos PostgreSQL con `docker compose`.
3. Crear la empresa y activar las aplicaciones: Punto de venta, Facturación, Inventario, Contactos y Empleados.
4. Dar de alta empleados, productos con su stock y clientes.
5. Configurar dos TPV, **Barra 1 y Barra 2**, y los usuarios camareros con acceso solo al TPV.
6. Regla automática: al cobrar a un cliente se crea y publica su factura sola, y el stock baja.
7. Copia diaria de Odoo y prueba de restauración.

![Productos con stock](../05-erp-odoo/capturas/15-productos-stock.png)

![Ticket de la Barra 1](../05-erp-odoo/capturas/25-barra1-4-ticket.png)

![Stock después de vender](../05-erp-odoo/capturas/30-stock-despues-de-vender.png)

**Disco redundante del servidor de Odoo:** se añadieron dos discos de 25 GB y se creó un **RAID 1** con `mdadm`, montado en `/srv/raid1`.

![RAID 1 creado con los dos discos sincronizados](../05-erp-odoo/capturas/54-raid-detalle-final.png)

# 8. Base de datos

1. **Modelo entidad-relación** del restaurante y paso a tablas (13 tablas: clientes, mesas, reservas, empleados, comandas, platos, ingredientes, proveedores, facturas…).
2. Crear las tablas con su script SQL, con claves primarias y ajenas, y cargar datos de prueba.
3. Tres usuarios con **mínimo privilegio**: la aplicación (lee y escribe), consulta (solo lectura) y copias.
4. **RAID 1** con dos discos para los datos.
5. **Copia automática** diaria con `cron`, enviada también al servidor de Odoo, y prueba de restauración.

![Modelo entidad-relación del equipo](../diagramas/modelo-er-equipo.png)

![Tablas creadas](../07-bd-raid-copias/capturas/02-esquema-cargado.png)

![Fallo de un disco: el RAID sigue funcionando y avisa](../07-bd-raid-copias/capturas/20-vm-raid-fallo-y-aviso.png)

![Restauración de la copia: datos idénticos](../07-bd-raid-copias/capturas/12-restauracion-3-recuperada.png)

# 9. Copias de seguridad de los sistemas operativos

1. Servidor de copias (Ubuntu Server) con **RAID 1** de dos discos, probado quitando un disco y reconstruyéndolo.
2. Acceso por **SSH con clave**, sin contraseña, entre el servidor de copias y el equipo del gerente.
3. Copia completa de Windows y copia **incremental** de Debian con `rsync`.
4. Réplica de las copias en una **EC2 de AWS**, creada con Terraform.
5. Script automático con `cron` todas las semanas y borrado de las copias antiguas.
6. Prueba de restauración desde la copia de AWS.

![RAID del servidor de copias con un disco fallido](../08-copias-so/capturas/06-raid-fallo-disco.png)

![Copia incremental de Debian](../08-copias-so/capturas/16-copia-incremental.png)

![Restauración desde AWS](../08-copias-so/capturas/25-restauracion-desde-aws.png)

# 10. Web del restaurante en AWS

1. Web hecha con **HTML y CSS**, adaptada a móvil, con carta, menú del día, opiniones, contacto y geolocalización.
2. Infraestructura en **AWS Academy** creada con **Terraform**: instancia EC2, grupo de seguridad e IP elástica.
3. Al crearse, la instancia instala nginx, publica la web y pide el certificado **HTTPS** de Let's Encrypt para el dominio de DuckDNS.

![terraform apply](../06-web-aws/capturas/paso-05-plan-y-apply.png)

![La web publicada](../06-web-aws/capturas/paso-06-web-inicio.png)

# 11. Presupuesto

Presupuesto con IVA de los equipos del restaurante (TPV, impresoras de tickets, cajones, monitor, SAI), la red (router y switch gestionable) y el arcade stick: **2.296,74 €** de momento. El detalle, con enlaces y fechas, está en `presupuesto/README.md`.
