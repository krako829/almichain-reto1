# 0. Gestión del proyecto

## Contenido

| Archivo | Qué es |
|---|---|
| [`Guias-paso-a-paso-Reto1-Almi-Chain.docx`](Guias-paso-a-paso-Reto1-Almi-Chain.docx) | Guías paso a paso de las 8 partes del reto, con las tareas G, P, A, S, R, E, W y B |
| [`tablero/`](tablero/) | Tablero tipo Trello con las 91 tareas (abrir `tablero/index.html`, instrucciones en [`tablero/LEEME.md`](tablero/LEEME.md)). Se exporta a JSON en `tablero/` al final de cada sesión |

> **La guía paso a paso es un documento de planificación** hecho antes de empezar. Las decisiones posteriores (sin doble arranque, Ubuntu en la recreativa en vez de Debian, dominio `almichain2`, modelo de datos de 13 tablas…) están en "Decisiones del equipo" y **mandan sobre la guía**. La guía numera las partes del 1 al 8 y las carpetas van del 00 al 07:
>
> | Parte de la guía | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
> |---|---|---|---|---|---|---|---|---|
> | Carpeta | 00-gestion | 01-windows-gerente-tpv | 02-linux-recreativa | 03-arcade-stick | 04-red | 05-erp-odoo | 06-web-aws | 07-bd-raid-copias |

## Estado de la gestión (27 de octubre de 2026)

| Entregable | Estado |
|---|---|
| Anexo I (contrato de trabajo en equipo) | **Pendiente**: hay un borrador en el Drive del equipo sin terminar ni firmar. No se sube al repositorio hasta quitarle los datos personales |
| Anexo II | **Pendiente** |
| Reparto de tareas en el tablero | **Pendiente**: las tareas del archivo no tienen responsable y no hay ningún `.json` exportado todavía |
| Presentación final (G15) | Pendiente (semana 4) |
| Commits de los 5 | Pendiente: hasta ahora el historial solo tiene commits de un miembro. A partir de aquí, cada uno hace sus commits con su usuario de Git y con el formato `Bloque: qué se ha hecho` |

## Equipo y plazo

- **Equipo**: Alberto, Oier, Julen, Gontzal y Richar. El reparto está en el tablero.
- **Plazo**: 4 semanas, del 16 de octubre al 13 de noviembre de 2026.

| Semana | Fechas | Objetivo |
|---|---|---|
| S1 | 16 – 23 oct | Análisis y diseño: anexos, repo, contraseñas, modelo E/R, plano de red, boceto web, ERP elegido, material del stick |
| S2 | 26 – 30 oct | Instalaciones base: VM, Odoo, servidor con RAID, web maquetada, Packet Tracer |
| S3 | 2 – 6 nov | Integración y seguridad: TPV + impresora + Odoo, factura automática, web con HTTPS, WDS, stick, copias |
| S4 | 9 – 13 nov | Pruebas y entrega: restauración, fallo de disco, benchmarks, revisión cruzada, documentación, presentación |

## Decisiones del equipo e indicaciones del profesor

Se distingue lo que **indicó el profesor** (de palabra, en clase) de lo que **decidió el equipo** después. Las decisiones del equipo que cambian algo del enunciado necesitan la **conformidad del profesor por escrito** (un correo o el acta en el Anexo II): está **pendiente** de pedirla.

| Tema | Decisión | Quién |
|---|---|---|
| Qué cuenta | La lista de tareas del enunciado (los RA no se tienen en cuenta) | Profesor |
| Equipos físicos | Solo 2 routers, 1 impresora de tickets y el arcade stick con Arduino | Profesor |
| Resto | Máquinas virtuales de VirtualBox en los PC de clase (Zorin OS, 16 GB de RAM) | Profesor |
| Red | Packet Tracer y 2 routers reales: uno da señal al otro como repetidor (WDS) | Profesor |
| ERP | Odoo | Profesor |
| Web | Geolocalización, HTTPS y dominio de DuckDNS, desplegada con Terraform en AWS Academy | Profesor |
| Base de datos | Con RAID y con pruebas | Profesor |
| Recreativa | 1 núcleo y 1 GB, sin swap, MAME | Profesor |
| Seguridad | Mínimo privilegio: cada usuario solo accede a lo suyo | Profesor |
| Licencias | Windows 10 Pro/Education con licencia; todo lo demás gratis | Profesor |
| Gerente | **Sin doble arranque**: Windows 10 Pro en la VM ALMI-GERENTE y la recreativa en una VM aparte (ALMI-ARCADE). **El enunciado pide doble arranque: falta escribir aquí el motivo y conseguir la conformidad del profesor** | Equipo |
| TPV | Una sola VM, ALMI-TPV, con los usuarios TPV1 y TPV2, que simulan los dos equipos de barra. **Falta el motivo y la conformidad del profesor** | Equipo |
| Impresora | La comparten los dos TPV en el laboratorio (solo hay una física) | Equipo |
| ERP | Que haga algo funcional de verdad (factura automática al cobrar), sin usar todas las aplicaciones | Equipo |
| Recreativa | Ubuntu 24.04 mínimo en lugar de Debian (justificado en el bloque 02) | Equipo |

## Nombres comunes

| Elemento | Nombre | Dónde |
|---|---|---|
| Equipo del gerente | ALMI-GERENTE | VirtualBox · Windows 10 Pro |
| TPV de barra | ALMI-TPV | VirtualBox · Windows 10 Pro · TPV1 y TPV2 |
| Recreativa | ALMI-ARCADE | VirtualBox · Ubuntu 24.04 mínimo + MAME |
| Servidor de base de datos | ALMI-BD | VirtualBox · Ubuntu Server 24.04 · 192.168.10.20 |
| Servidor del ERP | ALMI-ODOO | VirtualBox · Ubuntu Server 24.04 · 192.168.10.30 |
| Servidor web | almichain-web | AWS Academy · EC2 creada con Terraform |
| Dominio | almichain2.duckdns.org | DuckDNS |
| Red interna de VirtualBox | ALMICHAIN | Red NAT 192.168.10.0/24 |
| Administrador en todas las máquinas | almiadmin | Contraseña en el gestor de contraseñas |

## Red NAT ALMICHAIN

Una vez en cada PC que tenga máquinas del reto:

1. VirtualBox → **Archivo → Herramientas → Administrador de red** → pestaña **Redes NAT** → **Crear**.
2. Nombre `ALMICHAIN`, prefijo `192.168.10.0/24`, **Habilitar DHCP** → **Aplicar**.
   Después, acotar el DHCP para que no reparta las IP fijas de los servidores (.20 y .30). En una terminal del PC:

   ```bash
   VBoxManage dhcpserver modify --network=ALMICHAIN --lower-ip=192.168.10.100 --upper-ip=192.168.10.199
   VBoxManage list dhcpservers        # comprobar el rango
   ```
3. En cada VM: **Configuración → Red → Adaptador 1 → Red NAT → ALMICHAIN**.
4. Para administrar desde el PC, en **Reenvío de puertos** de la red ALMICHAIN:

| Nombre | Protocolo | IP anfitrión | Puerto anfitrión | IP invitado | Puerto invitado |
|---|---|---|---|---|---|
| odoo-ssh | TCP | **127.0.0.1** | 2230 | 192.168.10.30 | 22 |
| odoo-https | TCP | **127.0.0.1** | 8443 | 192.168.10.30 | 443 |
| bd-ssh | TCP | **127.0.0.1** | 2220 | 192.168.10.20 | 22 |

La **IP anfitrión 127.0.0.1** es importante: si se deja vacía, VirtualBox abre esos puertos en todas las interfaces del PC y cualquier ordenador del aula podría intentar entrar por SSH en nuestros servidores. Con 127.0.0.1 solo se llega desde el propio PC.

Desde el PC: `ssh -p 2230 almiadmin@localhost` y Odoo en `https://localhost:8443` (el certificado incluye `localhost`).

Lo mismo por comandos: `VBoxManage natnetwork modify --netname ALMICHAIN --port-forward-4 "odoo-ssh:tcp:[127.0.0.1]:2230:[192.168.10.30]:22"` (y igual con las otras dos).

## Contraseñas y secretos

Ninguna contraseña, clave de AWS ni token se escribe en el repositorio ni en la documentación. Están en la base **almichain.kdbx** de **KeePassXC**, que se comparte por USB, nunca por Git. En la documentación se escribe "contraseña guardada en el gestor".

## Dónde se cumple cada punto del enunciado

| Punto del enunciado | Dónde |
|---|---|
| Necesidades, configuración y presupuesto de equipos e impresoras | [01-windows-gerente-tpv](../01-windows-gerente-tpv/README.md), [presupuesto](../presupuesto/) |
| Hardware y software necesario | [01](../01-windows-gerente-tpv/README.md), [03](../03-arcade-stick/README.md), [04](../04-red/README.md) |
| Recreativa: instalación, optimización y monitorización | [02-linux-recreativa](../02-linux-recreativa/README.md) |
| Arcade stick con Arduino | [03-arcade-stick](../03-arcade-stick/README.md) |
| Necesidades de comunicación, WAN, plano, Wi-Fi segura y WDS | [04-red](../04-red/README.md) |
| Sistemas operativos | [01](../01-windows-gerente-tpv/README.md), [02](../02-linux-recreativa/README.md), [05](../05-erp-odoo/README.md), [07](../07-bd-raid-copias/README.md) |
| Mínimo privilegio y seguridad por defecto | Apartado "Seguridad aplicada" de cada bloque |
| Web: diseño, HTTPS, AWS, dominio, despliegue reproducible, geolocalización, formulario y slideshow | [06-web-aws](../06-web-aws/README.md) |
| ERP + TPV con un caso real automatizado | [05-erp-odoo](../05-erp-odoo/README.md) |
| Impresora | [01](../01-windows-gerente-tpv/README.md) y [05](../05-erp-odoo/README.md) |
| Modelo E/R, tablas, base de datos y consultas | [07-bd-raid-copias](../07-bd-raid-copias/README.md) |
| Disco redundante, plan de copias y restauración | [07-bd-raid-copias](../07-bd-raid-copias/README.md), [05](../05-erp-odoo/README.md) |
| Pruebas | Tabla "Pruebas" de cada bloque |
| Documentación con diagramas | Los README y [`docs/`](../docs/) |
| Seguimiento y control de versiones | Este tablero y el historial de Git |
| Anexo I y Anexo II | Esta carpeta (**pendientes**, ver "Estado de la gestión") |
