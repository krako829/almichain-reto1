# 0. Gestión del proyecto

## Contenido

| Archivo | Qué es |
|---|---|
| [`Guias-paso-a-paso-Reto1-Almi-Chain.docx`](Guias-paso-a-paso-Reto1-Almi-Chain.docx) | Guías paso a paso de las 8 partes del reto, con las tareas G, P, A, S, R, E, W y B |
| [`tablero/`](tablero/) | Tablero tipo Trello con las 90 tareas (abrir `tablero/index.html`). Se exporta a JSON en esta carpeta al final de cada sesión |

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

| Tema | Decisión |
|---|---|
| Qué cuenta | La lista de tareas del enunciado (los RA no se tienen en cuenta) |
| Equipos físicos | Solo 2 routers, 1 impresora de tickets (la comparten los dos TPV) y el arcade stick con Arduino |
| Resto | Máquinas virtuales de VirtualBox en los PC de clase (Zorin OS, 16 GB de RAM) |
| Gerente | Windows 10 Pro en la VM ALMI-GERENTE (usuario Gerente). **Sin doble arranque**: la recreativa es una VM aparte |
| TPV | Una sola VM, ALMI-TPV, con los usuarios TPV1 y TPV2 |
| Recreativa | VM ALMI-ARCADE: 1 núcleo y 1 GB, sin swap, MAME |
| Red | Packet Tracer y 2 routers reales: uno da señal al otro como repetidor (WDS) |
| ERP | Odoo (que haga algo funcional de verdad, no hace falta usarlo entero) |
| Web | Geolocalización, HTTPS y dominio de DuckDNS, desplegada con Terraform en AWS Academy |
| Base de datos | Con RAID y con pruebas |
| Seguridad | Mínimo privilegio: cada usuario solo accede a lo suyo |
| Licencias | Windows 10 Pro/Education con licencia; todo lo demás gratis |

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

## Red NAT ALMICHAIN {#red-nat-almichain}

Una vez en cada PC que tenga máquinas del reto:

1. VirtualBox → **Archivo → Herramientas → Administrador de red** → pestaña **Redes NAT** → **Crear**.
2. Nombre `ALMICHAIN`, prefijo `192.168.10.0/24`, **Habilitar DHCP** → **Aplicar**.
3. En cada VM: **Configuración → Red → Adaptador 1 → Red NAT → ALMICHAIN**.
4. Para administrar desde el PC, en **Reenvío de puertos** de la red ALMICHAIN:

| Nombre | Protocolo | Puerto anfitrión | IP invitado | Puerto invitado |
|---|---|---|---|---|
| odoo-ssh | TCP | 2230 | 192.168.10.30 | 22 |
| odoo-https | TCP | 8443 | 192.168.10.30 | 443 |
| bd-ssh | TCP | 2220 | 192.168.10.20 | 22 |

Desde el PC: `ssh -p 2230 almiadmin@localhost` y Odoo en `https://localhost:8443`.

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
| Anexo I y Anexo II | Esta carpeta |
