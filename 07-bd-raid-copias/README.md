# 7. Base de datos, RAID y copias de seguridad

## Objetivo

Diseñar e implantar la base de datos de un local de Almi-Chain (clientes, reservas, mesas, comandas, carta, ingredientes, proveedores, personal y facturas) en un servidor **MariaDB** cuyos datos están en un **RAID 1**, con usuarios de mínimo privilegio, **copias automáticas** a otro servidor y **pruebas de restauración** y de **fallo de disco**.

Tareas del tablero: B01 a B12.

## Requisitos

| Elemento | Valor |
|---|---|
| VM | ALMI-BD · 2 GB de RAM · 2 núcleos · disco de sistema de 15 GB + **dos discos de 10 GB** para el RAID · Red NAT ALMICHAIN |
| Sistema | Ubuntu Server 24.04 LTS · IP 192.168.10.20/24 |
| Software | MariaDB 10.11, mdadm, rsync, cron |
| Usuario de administración | `almiadmin` (contraseña en KeePassXC) |

## Arquitectura

```mermaid
flowchart LR
  subgraph BD["ALMI-BD 192.168.10.20"]
    SDA[("sda 15 GB<br/>sistema")]
    SDB[("sdb 10 GB")] --> MD["md0 · RAID 1<br/>ext4"]
    SDC[("sdc 10 GB")] --> MD
    MD -- "/var/lib/mysql" --> MDB["MariaDB 10.11<br/>solo 127.0.0.1:3306"]
    MDB -- "02:00 mariadb-dump<br/>(usuario copias)" --> LOC["/var/backups/mariadb<br/>7 diarias + 4 semanales"]
    MD -. "disco roto" .-> AV["aviso-raid.sh<br/>registro y aviso"]
    REM["/srv/copias-remotas/odoo<br/>copias que llegan de Odoo"]
  end
  LOC -- "02:00 rsync por SSH 22<br/>rrsync: solo escribir" --> OD["ALMI-ODOO<br/>/srv/copias-remotas/bd"]
  OD -. "02:30 copias de Odoo<br/>rsync por SSH 22" .-> REM
```

## Modelo de datos

Modelo del equipo hecho en dbdiagram.io: [`../diagramas/modelo-er-equipo.pdf`](../diagramas/modelo-er-equipo.pdf). Es un **modelo relacional** (tablas, columnas y claves). El **modelo entidad/relación conceptual** está en [`../diagramas/modelo-er-conceptual.mmd`](../diagramas/modelo-er-conceptual.mmd) (fuente, se edita como texto) y su imagen: las tres tablas intermedias (`detalle_comanda`, `plato_ingrediente` y `suministro`) aparecen como relaciones N:M con sus atributos. Está hecho a partir del esquema; el equipo lo revisa y, si el profesor lo pide en notación de Chen (rombos), lo pasa a draw.io.

![Modelo entidad/relación conceptual (notación de pata de gallo: | uno, o cero, pata varios)](../diagramas/modelo-er-conceptual.png)

![Modelo relacional del equipo](../diagramas/modelo-er-equipo.png)

13 tablas y una vista:

| Tabla | Clave primaria | Claves ajenas | Notas |
|---|---|---|---|
| cliente | id_cliente | — | email único |
| mesa | id_mesa | — | número único; zona sala/terraza/barra |
| empleado | id_empleado | — | puesto, sueldo > 0 |
| categoria | id_categoria | — | nombre único |
| plato | id_plato | id_categoria | precio > 0 |
| ingrediente | id_ingrediente | — | stock ≥ 0 |
| proveedor | id_proveedor | — | |
| reserva | id_reserva | id_cliente, id_mesa | una mesa no se reserva dos veces a la misma hora |
| comanda | id_comanda | id_mesa, id_empleado, id_cliente (opcional) | estado abierta/servida/pagada/anulada |
| detalle_comanda | (id_comanda, id_plato) | id_comanda, id_plato | N:M comanda-plato; guarda el precio del momento |
| plato_ingrediente | (id_plato, id_ingrediente) | id_plato, id_ingrediente | N:M, la receta |
| suministro | (id_proveedor, id_ingrediente) | id_proveedor, id_ingrediente | N:M, precio de compra |
| factura | id_factura | id_comanda (única) | 1:1 con la comanda |
| **v_importe_comanda** (vista) | | | importe de cada comanda |

**Normalización**: todas las columnas son atómicas (1FN); las tablas con clave compuesta (detalle_comanda, plato_ingrediente, suministro) solo tienen atributos que dependen de la clave entera (2FN); no hay dependencias entre atributos que no son clave, por ejemplo el nombre de la categoría está en `categoria` y no repetido en `plato` (3FN). El importe de la comanda no se guarda: se calcula con la vista, para que no pueda quedar desactualizado.

Archivos SQL en [`sql/`](sql/):

| Archivo | Qué hace |
|---|---|
| [`01-esquema.sql`](sql/01-esquema.sql) | Base `almichain` en utf8mb4, 13 tablas InnoDB con claves, restricciones CHECK, índices y la vista |
| [`02-datos.sql`](sql/02-datos.sql) | Datos de ejemplo ficticios |
| [`03-usuarios.sql`](sql/03-usuarios.sql) | Los 3 usuarios (las contraseñas se pasan al ejecutarlo, no están en el archivo) |
| [`04-consultas.sql`](sql/04-consultas.sql) | 9 consultas de prueba |
| [`05-recuentos.sql`](sql/05-recuentos.sql) | Recuento de filas para comparar antes y después de restaurar |

## Instalación y configuración paso a paso

### 1. VM con tres discos (B04)

Instalación base de Ubuntu Server igual que ALMI-ODOO (bloque 05, paso 1) con IP **192.168.10.20** y nombre `almi-bd`, **salvo el cortafuegos**: este servidor no tiene web, así que solo se abre el SSH y solo desde las VLAN 10 y 99:

```bash
sudo ufw default deny incoming && sudo ufw default allow outgoing
for red in 192.168.10.0/24 192.168.99.0/24; do sudo ufw allow from $red to any port 22 proto tcp; done
sudo ufw enable
```

Con la VM apagada: **Configuración → Almacenamiento → Controlador SATA → Añadir disco duro → Crear** → `ALMI-BD-raid1`, VDI, 10 GB. Repetir con `ALMI-BD-raid2`.

### 2. MariaDB segura (B06)

```bash
sudo apt install -y mariadb-server
sudo mariadb-secure-installation
```

Se quitan los usuarios anónimos, la base `test` y el acceso remoto de root; root solo entra por el socket local (`unix_socket`). MariaDB escucha solo en `127.0.0.1`.

![MariaDB sin usuarios anónimos ni base test, escuchando solo en 127.0.0.1](capturas/01-mariadb-segura.png)

### 3. RAID 1 (B05)

Se hace **después** de instalar MariaDB, porque lo que se pone encima del RAID es su carpeta de datos (`/var/lib/mysql`). Los pasos están también en el script [`scripts/crear-raid.sh`](scripts/crear-raid.sh), que comprueba que los discos están vacíos antes de tocar nada y que la copia es idéntica antes de vaciar la carpeta original:

```bash
sudo apt install -y mdadm
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc
cat /proc/mdstat                       # esperar a [UU] y 100 %
sudo mkfs.ext4 -L datos-bd /dev/md0
sudo systemctl stop mariadb
sudo mount /dev/md0 /mnt && sudo rsync -aAX /var/lib/mysql/ /mnt/ && sudo rm -rf /mnt/lost+found
sudo diff -r --brief /var/lib/mysql/ /mnt/ && sudo umount /mnt   # sin salida = copia idéntica
sudo find /var/lib/mysql -mindepth 1 -delete                       # vaciar el original
echo "UUID=$(sudo blkid -s UUID -o value /dev/md0) /var/lib/mysql ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo mkdir -p /etc/systemd/system/mariadb.service.d
printf '[Unit]\nRequiresMountsFor=/var/lib/mysql\n' | sudo tee /etc/systemd/system/mariadb.service.d/raid.conf
sudo systemctl daemon-reload
sudo mount /var/lib/mysql && sudo chown mysql:mysql /var/lib/mysql
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
sudo systemctl start mariadb
```

- `nofail`: si el RAID fallara del todo, el servidor arranca igualmente y se puede reparar por SSH.
- `RequiresMountsFor`: pero **MariaDB no arranca** si el RAID no está montado. Por eso se vacía la carpeta original: si quedaran los datos viejos debajo del montaje, MariaDB arrancaría con ellos sin avisar y el restaurante trabajaría sobre datos antiguos.

**Aviso si falla un disco**: `mdadm` vigila el RAID (servicio `mdmonitor`) y, cuando un disco falla, llama al programa de la línea `PROGRAM` de `/etc/mdadm/mdadm.conf`. El script crea `/usr/local/sbin/aviso-raid.sh` (y reinicia `mdmonitor` para que lo use), que lo apunta en `/var/log/aviso-raid.log`, en el registro del sistema (`journalctl -t aviso-raid`) y en la pantalla de quien esté conectado, como mucho un minuto después del fallo (`mdmonitor` revisa el RAID cada 60 segundos). Sin esto, un disco roto podría pasar semanas sin que nadie se enterara y el RAID dejaría de proteger. El disco del sistema (el de 15 GB) **no** está en el RAID: si falla, se reinstala el servidor y se recupera la base desde el RAID o desde la copia en ALMI-ODOO.

> En la VM exportada (.ova) el RAID se crea solo la primera vez que arranca, con el servicio `almi-crear-raid`, porque los dos discos se entregan vacíos. El registro queda en `/var/log/almi-crear-raid.log`.

### 4. Esquema, datos y usuarios (B07)

```bash
cd ~/sql
sudo mariadb < 01-esquema.sql
sudo mariadb < 02-datos.sql
sudo ~/scripts/crear-usuarios-bd.sh 03-usuarios.sql
```

[`scripts/crear-usuarios-bd.sh`](scripts/crear-usuarios-bd.sh) pide las tres contraseñas sin enseñarlas (mínimo 12 caracteres) y se las pasa a MariaDB por la entrada estándar, así no quedan en el historial de bash ni se ven con `ps`. [`03-usuarios.sql`](sql/03-usuarios.sql) se para antes de tocar nada si falta alguna contraseña, usa `QUOTE()` (una comilla en la contraseña no rompe nada) y `CREATE OR REPLACE USER` (sirve también para cambiarlas). El script deja la contraseña de `copias` en `/root/.my.cnf` (600) para las copias automáticas.

![Esquema y datos cargados: 13 tablas y la vista](capturas/02-esquema-cargado.png)

![Estructura de comanda y factura con sus claves](capturas/03-estructura-comanda-factura.png)

| Usuario | Permisos | Para qué |
|---|---|---|
| `app_almichain` | SELECT, INSERT, UPDATE, DELETE en `almichain.*` | La aplicación: trabaja con los datos, no puede cambiar la estructura |
| `consulta` | SELECT, SHOW VIEW en `almichain.*` | Informes de gerencia: solo lectura |
| `copias` | SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, EVENT en `almichain.*` y SELECT en `mysql.proc` | Lo mínimo que necesita `mariadb-dump` (con `--routines`). No puede leer las demás bases ni `mysql.global_priv`, donde están los hashes de las contraseñas |

Todos solo desde `localhost`.

![Usuarios y sus privilegios (servidor de pruebas, antes de limitar copias a almichain.*; el estado actual está en la captura 19)](capturas/04-usuarios-privilegios.png)

### 5. Consultas (B07)

Las 9 consultas de [`04-consultas.sql`](sql/04-consultas.sql), ejecutadas con el usuario de solo lectura `consulta`:

![Consultas 1 a 3: carta, reservas del día e importe de cada comanda](capturas/05-consultas-1-a-3.png)

![Consultas 4 a 6: facturación por día y método de pago, platos más vendidos y ventas por camarero](capturas/06-consultas-4-a-6.png)

![Consultas 7 a 9: coste de la receta, ingredientes con poco stock y comandas sin cobrar](capturas/07-consultas-7-a-9.png)

El usuario `consulta` no puede borrar ni modificar:

![consulta no puede hacer DELETE ni DROP: ERROR 1142](capturas/08-consulta-no-puede-borrar.png)

### 6. Plan de copias (B08)

| Qué | Cómo | Cuándo | Retención | Dónde |
|---|---|---|---|---|
| Base `almichain` (MariaDB) | `mariadb-dump --single-transaction` comprimido + huella SHA-256 | Diaria, 02:00 | 7 diarias + 4 semanales (domingo) | ALMI-BD `/var/backups/mariadb` y **copia en ALMI-ODOO** |
| Base y adjuntos de Odoo | `pg_dump -Fc` + `tar` del filestore + huellas | Diaria, 02:30 | 7 días | ALMI-ODOO `/var/backups/odoo` y **copia en ALMI-BD** |
| Configuración y scripts | Repositorio Git | En cada cambio | Historial completo | GitHub |

**Regla 3-2-1**: 3 copias (datos en el RAID + copia local + copia en el otro servidor), en 2 soportes distintos (dos máquinas) y 1 fuera del local (el repositorio para la configuración; para los datos, se recomienda al restaurante un disco externo semanal o un almacenamiento en la nube cifrado).

### 7. Copias cruzadas automáticas (B09)

En **los dos** servidores:

- Usuario `copias` sin contraseña (`passwd -l`) que solo recibe archivos en `/srv/copias-remotas/` (permisos 700).
- Clave SSH `/root/.ssh/copias_ed25519` para enviar. En el `authorized_keys` del otro servidor la clave va limitada a la IP de origen, sin terminal y **solo para escribir en su carpeta** con `rrsync` (viene con rsync en Ubuntu 24.04):

  ```
  command="/usr/bin/rrsync -wo -no-del /srv/copias-remotas/bd/",from="192.168.10.20",restrict ssh-ed25519 …
  ```

  Así, aunque alguien se hiciera con un servidor, desde él **no puede borrar ni leer las copias** que hay en el otro, ni ejecutar órdenes allí. Probado con un sshd local: la copia normal funciona; `ssh … 'ls /'`, `rsync --delete`, leer y `../` se rechazan (transcripción en el informe de auditoría).
- El que recibe las copias es quien borra las viejas: en el cron de root, `find /srv/copias-remotas -type f -mtime +30 -delete` (30 días).
- La primera vez que un servidor envía, guarda la clave de host del otro (`StrictHostKeyChecking=accept-new`); si después cambiara, `ssh` se niega a conectar.
- Contraseña del usuario `copias` de MariaDB en `/root/.my.cnf` (permisos 600).

Script [`scripts/copia-bd.sh`](scripts/copia-bd.sh) en `/usr/local/bin/`, en el cron de root a las 02:00:

![Copia hecha, comprobada, enviada y programada en cron (servidor de pruebas, antes de restringir la clave con rrsync: el `ls` remoto que se ve ahora se rechaza; ver las capturas 24 y 25)](capturas/09-copia-automatica.png)

## Pruebas de restauración (B10)

Se simula un desastre: se borra la base de datos entera y se recupera de la copia.

![1. Recuento antes, copia nueva y huella correcta](capturas/10-restauracion-1-antes.png)

![2. Se borra la base de datos](capturas/11-restauracion-2-borrado.png)

![3. Restauración en menos de un segundo, datos idénticos y los usuarios siguen funcionando](capturas/12-restauracion-3-recuperada.png)

**Tiempo de recuperación (RTO)**: menos de 1 segundo con esta cantidad de datos. **Pérdida máxima de datos (RPO)**: 24 horas (copia diaria).

## La VM exportada y la prueba de fallo de disco (B11)

Hecho arrancando los discos de `ALMI-BD.ova` (el de sistema y los dos de 10 GB) **en QEMU**, no en VirtualBox, con [`herramientas/probar-vm/pruebas-bd.sh`](../herramientas/probar-vm/pruebas-bd.sh). Cada captura tiene al lado su transcripción `.txt` con las órdenes y la salida real.

**Primer arranque.** `almi-crear-raid` crea el RAID 1 con los dos discos vacíos, copia encima los datos de MariaDB, comprueba la copia, **vacía la carpeta original** (debajo del montaje quedan 0 archivos) y deja MariaDB dependiendo del montaje. Después, `almi-primer-arranque-bd` crea los tres usuarios con contraseñas nuevas, solo para esta VM, y pone el cortafuegos.

![Primer arranque: RAID 1 en UU montado en /var/lib/mysql, MariaDB requiere el montaje, carpeta original vacía, aviso configurado](capturas/18-vm-primer-arranque-raid.png)

![Usuarios con contraseñas nuevas: copias solo sobre almichain y mysql.proc, secretos solo para root, consulta no puede borrar, cortafuegos solo SSH desde las VLAN 10 y 99, claves SSH propias](capturas/19-vm-usuarios-secretos-cortafuegos.png)

**Prueba A, un disco se rompe con el servidor en marcha.** Se marca `sdc` como roto: el RAID pasa a `[U_]` y la base de datos **sigue funcionando y se puede escribir**. Antes de un minuto llega el **aviso** (registro y mensaje en pantalla).

```bash
sudo mdadm /dev/md0 --fail /dev/sdc
cat /proc/mdstat
sudo mariadb -e "INSERT INTO almichain.cliente (nombre, apellidos, telefono) VALUES ('Prueba', 'RAID', '699999999');"
sudo tail /var/log/aviso-raid.log
```

![Disco sdc roto: U_, MariaDB sigue escribiendo y llega el aviso](capturas/20-vm-raid-fallo-y-aviso.png)

**Cambio del disco y reconstrucción**: se quita del RAID y se vuelve a añadir; mdadm copia los datos del disco bueno al otro.

```bash
sudo mdadm /dev/md0 --remove /dev/sdc
sudo mdadm /dev/md0 --add /dev/sdc
watch cat /proc/mdstat
```

![Reconstrucción hasta UU, 0 discos fallidos y el dato escrito con un solo disco sigue ahí](capturas/21-vm-raid-reconstruccion.png)

**Prueba B, arrancar sin un disco.** Con la VM apagada se quita el segundo disco y se arranca: el RAID arranca **degradado** con un solo disco, se monta y MariaDB funciona con los datos. Ubuntu no siempre lo arranca solo cuando falta un disco (se quedaba `inactive`); por eso hay un servicio, `almi-raid-degradado`, que espera 20 s y, si sigue inactivo, lo arranca con el disco que haya, monta los datos y arranca MariaDB.

![Arranque con un solo disco: md0 degradado, datos montados y MariaDB funcionando](capturas/22-vm-raid-sin-un-disco.png)

Después se apaga, se pone un **disco nuevo y vacío** y se añade al RAID:

```bash
sudo mdadm /dev/md0 --add /dev/sdc
```

![Disco nuevo añadido: reconstrucción hasta UU y los datos siguen](capturas/23-vm-raid-disco-nuevo.png)

En VirtualBox es igual: VM apagada → **Configuración → Almacenamiento** → quitar `ALMI-BD-raid2` → arrancar y comprobar → apagar, **Añadir disco duro → Crear** uno nuevo de 10 GB → arrancar y `sudo mdadm /dev/md0 --add /dev/sdc`.

**Copias cruzadas entre las dos VM** (con ALMI-ODOO y ALMI-BD encendidas a la vez en la misma red): cada una envía su copia a la otra y la clave de copias solo puede escribir.

![En ALMI-BD llegan las copias de Odoo](capturas/24-vm-copias-recibidas-de-odoo.png)

![ALMI-BD hace su copia y la envía a ALMI-ODOO](capturas/25-vm-copia-a-almi-odoo.png)

## Seguridad aplicada

- MariaDB solo escucha en 127.0.0.1; root solo por socket local; sin usuarios anónimos ni base `test`.
- Tres usuarios con el mínimo privilegio necesario; ninguno con permisos globales de escritura.
- Contraseñas fuera del repositorio (variables al cargar `03-usuarios.sql`, `/root/.my.cnf` con permisos 600).
- Copias con permisos 700, huella SHA-256 y enviadas con una clave SSH que solo sirve desde la IP del otro servidor, sin terminal y solo para escribir en la carpeta de copias (`rrsync -wo -no-del`).
- MariaDB no arranca si el RAID no está montado: nunca trabaja con datos viejos por error.
- Cortafuegos ufw: solo SSH (22) desde la VLAN 10 (gestión) y la 99 (administración).
- Secretos propios en cada VM importada: claves de host SSH y contraseñas de los 3 usuarios de MariaDB se generan en el primer arranque (ver [docs/maquinas-virtuales.md](../docs/maquinas-virtuales.md)).
- RAID 1: si falla un disco, la base de datos sigue funcionando.

## Pruebas

| Nº | Qué se prueba | Cómo | Resultado esperado | Resultado obtenido | Captura |
|---|---|---|---|---|---|
| 1 | MariaDB segura | `SELECT User, Host FROM mysql.user` | Sin anónimos ni root remoto | Sin anónimos; todos los usuarios en localhost (root, mysql, mariadb.sys y los 3 de la aplicación) | [01](capturas/01-mariadb-segura.png) |
| 2 | Solo escucha en local | `ss -ltnp \| grep 3306` | 127.0.0.1:3306 | 127.0.0.1:3306 | [01](capturas/01-mariadb-segura.png) |
| 3 | Esquema completo | `SHOW FULL TABLES` | 13 tablas y 1 vista | 13 BASE TABLE y 1 VIEW | [02](capturas/02-esquema-cargado.png) |
| 4 | Mínimo privilegio | `SHOW GRANTS` de los 3 usuarios | Como en la tabla de usuarios | Correcto en la VM ([19](capturas/19-vm-usuarios-secretos-cortafuegos.png)). La captura 04 es anterior: ahí `copias` todavía tenía `SELECT` en `*.*` | [04](capturas/04-usuarios-privilegios.png) [19](capturas/19-vm-usuarios-secretos-cortafuegos.png) |
| 5 | Consultas | `04-consultas.sql` como `consulta` | 9 resultados correctos | 9 resultados | [05](capturas/05-consultas-1-a-3.png) [06](capturas/06-consultas-4-a-6.png) [07](capturas/07-consultas-7-a-9.png) |
| 6 | Solo lectura | `DELETE` y `DROP` como `consulta` | ERROR 1142 | ERROR 1142 en los dos | [08](capturas/08-consulta-no-puede-borrar.png) |
| 7 | Copia automática | `copia-bd.sh` y `crontab -l` | Copia local, huella, copia en ALMI-ODOO y cron a las 02:00 | Correcto en el servidor de pruebas (la «otra máquina» era el mismo servidor); entre dos VM, prueba 15 | [09](capturas/09-copia-automatica.png) |
| 8 | Restauración | Borrar la base y restaurar | `diff` sin diferencias | "RESTAURACION CORRECTA: datos identicos" | [10](capturas/10-restauracion-1-antes.png) [11](capturas/11-restauracion-2-borrado.png) [12](capturas/12-restauracion-3-recuperada.png) |
| 9 | Fallo de un disco del RAID | `mdadm --fail` y escribir en la base | `[U_]` y la base sigue funcionando | `[U_]`; INSERT correcto | [20](capturas/20-vm-raid-fallo-y-aviso.png) |
| 10 | Aviso del fallo | Esperar tras el `--fail` | Aviso en el registro y en pantalla en menos de un minuto | "Fail /dev/sdc" en `/var/log/aviso-raid.log`, en el registro del sistema y en pantalla | [20](capturas/20-vm-raid-fallo-y-aviso.png) |
| 11 | Reconstrucción | `mdadm --remove` y `--add` | Vuelve a `[UU]` | `[UU]`, 0 fallidos, el dato sigue | [21](capturas/21-vm-raid-reconstruccion.png) |
| 12 | Arrancar sin un disco (prueba B) | Apagar, quitar el segundo disco y arrancar | RAID degradado, datos montados y MariaDB funcionando | `[U_]`, montado, MariaDB activa y se puede escribir; lo arrancó `almi-raid-degradado` | [22](capturas/22-vm-raid-sin-un-disco.png) |
| 13 | Disco nuevo | Apagar, poner un disco vacío y `mdadm --add` | Vuelve a `[UU]` con todos los datos | `[UU]` y están los dos clientes de prueba | [23](capturas/23-vm-raid-disco-nuevo.png) |
| 14 | MariaDB no usa datos viejos | Carpeta original bajo el montaje | Vacía; MariaDB depende del montaje | 0 archivos; `RequiresMountsFor=/var/lib/mysql` | [18](capturas/18-vm-primer-arranque-raid.png) |
| 15 | Copias cruzadas entre las dos VM | `copia-bd.sh` en ALMI-BD y `copia-odoo.sh` en ALMI-ODOO | Cada copia llega a la otra máquina | Ver capturas | [24](capturas/24-vm-copias-recibidas-de-odoo.png) [25](capturas/25-vm-copia-a-almi-odoo.png) |

Las pruebas 1 a 8 se hicieron en el servidor de pruebas (ver el origen de las evidencias en el README principal); las 9 a 15, con la VM exportada arrancada en QEMU. En VirtualBox están pendientes de repetir en clase.

## Problemas encontrados y solución

| Problema | Causa | Solución |
|---|---|---|
| El diagrama del equipo y la guía tenían modelos distintos | La guía proponía 15 tablas; el equipo diseñó el suyo | Se implementa el modelo del equipo (13 tablas) |
| Los datos de MariaDB tienen que estar en el RAID desde el principio | Si se instala MariaDB antes del RAID, los datos quedan en el disco de sistema | Se copian con `rsync -aAX` con el servicio parado y se monta el RAID en `/var/lib/mysql` |
| El servicio que crea el RAID en el primer arranque se quedaba "activating" para siempre | Hacía `systemctl start mariadb` desde un servicio que está ordenado *antes* de mariadb: cada uno esperaba al otro | `systemctl start --no-block mariadb` |
| `mariadb-dump` necesita contraseña en cron | cron no puede escribirla | `/root/.my.cnf` con permisos 600 y el usuario `copias` de solo lectura |

## Fuentes

- Documentación de MariaDB: mariadb-dump, CREATE USER y GRANT — https://mariadb.com/kb/
- `man mdadm` y wiki de RAID de Linux — https://raid.wiki.kernel.org/
- Guías paso a paso del equipo, parte 8
