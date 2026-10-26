# Anexo. Máquinas virtuales exportadas

Las tres máquinas Linux del reto están exportadas en formato **OVA** (Open Virtualization Format) para importarlas en VirtualBox ya configuradas. Se descargan de la sección **Releases** del repositorio (`almichain-reto1` → *Releases* → `maquinas-virtuales`).

| Archivo | Máquina | Hardware | Red | Qué hace al importarla |
|---|---|---|---|---|
| `ALMI-ODOO.ova` | Servidor del ERP | 3 GB · 2 CPU · disco de 25 GB | IP fija 192.168.10.30 | En el **primer arranque** carga Odoo 18 y PostgreSQL 16 en Docker, restaura la base `almichain` con todos los datos del reto y aplica el cortafuegos (unos minutos). Después: `https://192.168.10.30` |
| `ALMI-BD.ova` | Servidor de base de datos | 2 GB · 2 CPU · disco de 15 GB + **2 discos de 10 GB** | IP fija 192.168.10.20 | En el **primer arranque** crea el **RAID 1** con los dos discos vacíos y mueve encima los datos de MariaDB |
| `ALMI-ARCADE.ova` | Recreativa | **1 GB · 1 CPU** · disco de 8 GB · sin swap | DHCP | Entra sola como `arcade` y abre MAME |

Los dos Windows (ALMI-GERENTE y ALMI-TPV) no se exportan: necesitan la ISO y la licencia de Windows de clase. Se preparan con los scripts de [`01-windows-gerente-tpv`](../01-windows-gerente-tpv/README.md).

## Importar

1. Crear la **Red NAT ALMICHAIN** si no existe: VirtualBox → **Archivo → Herramientas → Administrador de red → Redes NAT → Crear** → nombre `ALMICHAIN`, prefijo `192.168.10.0/24`, DHCP activado.
2. **Archivo → Importar servicio virtualizado** → elegir la `.ova` → **Siguiente**.
3. En la lista de ajustes, en **Política de dirección MAC** elegir *Generar nuevas direcciones MAC para todos los adaptadores de red* → **Terminar**.
4. Con la VM importada y apagada: **Configuración → Red → Adaptador 1 → Conectado a: Red NAT → Nombre: ALMICHAIN**. Es lo único que hay que cambiar.
5. Solo en ALMI-ARCADE: **Configuración → Pantalla → Controlador gráfico: VMSVGA** (normalmente ya viene así) y, para el stick, **USB → filtro** con el Arduino.
6. Arrancar. ALMI-ODOO y ALMI-BD tienen que estar en el **mismo PC** para que funcionen las copias cruzadas.

## Primer arranque

| Máquina | Cómo comprobar que ha terminado |
|---|---|
| ALMI-ODOO | `sudo tail /var/log/almi-primer-arranque.log` termina en `Listo: https://192.168.10.30`. `sudo docker compose --project-directory /opt/odoo ps` muestra `odoo` y `db` en marcha |
| ALMI-BD | `sudo cat /var/log/almi-crear-raid.log` termina en `RAID 1 creado`. `cat /proc/mdstat` muestra `md0 : active raid1 sdc[1] sdb[0]` |

## Usuarios

Las contraseñas no están en el repositorio: están en **KeePassXC** (`almichain.kdbx`).

| Máquina | Usuarios |
|---|---|
| Las tres | `almiadmin` (administrador, sudo) |
| ALMI-ARCADE | `arcade` (sin privilegios, entra solo) |
| Odoo (web) | administrador `almichain.reto@gmail.com`, `gerente@almichain.local`, `barra1@almichain.local`, `barra2@almichain.local` |
| MariaDB | `app_almichain`, `consulta`, `copias` (root solo por `sudo mariadb`) |

## Acceso desde el PC de clase

Con el reenvío de puertos de la red ALMICHAIN (ver [00-gestion](../00-gestion/README.md)):

```bash
ssh -p 2230 almiadmin@localhost     # ALMI-ODOO
ssh -p 2220 almiadmin@localhost     # ALMI-BD
# Odoo en el navegador del PC: https://localhost:8443
```

## Si algo no va

| Síntoma | Solución |
|---|---|
| La VM no tiene red | Comprobar que el adaptador está en *Red NAT → ALMICHAIN* y `ip -br a` dentro de la VM. La red se configura para cualquier interfaz `en*` |
| Odoo no responde tras 10 minutos | `sudo journalctl -u almi-primer-arranque` y `sudo tail -50 /var/log/almi-primer-arranque.log` |
| ALMI-BD no crea el RAID | Comprobar que tiene los dos discos de 10 GB en el controlador SATA (`lsblk`). Se puede lanzar a mano: `sudo /usr/local/sbin/almi-crear-raid.sh` |
| La recreativa se queda en negro | Controlador gráfico VMSVGA. Para entrar a administrar: Ctrl + Alt + F2 |
