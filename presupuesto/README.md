# Presupuesto global (G11)

Precios con IVA en tiendas españolas. Cada fila lleva el enlace y la fecha en que se miró el precio, porque cambian a menudo. Las filas marcadas *por completar* las rellena el responsable de cada bloque (P02, R02, S01).

## Equipos del restaurante (P02)

| Elemento | Cant. | Modelo elegido | Características clave | Precio unidad (€) | Total (€) | Enlace y fecha |
|---|---|---|---|---|---|---|
| TPV táctil de barra | 2 | Geon Zazoo POS 360 | Intel N150, 8 GB, SSD 128 GB, táctil 15" Full HD, Windows 11, 4×USB 3.0, LAN | 556,94 | 1.113,88 | [PcComponentes](https://www.pccomponentes.com/tpv-tactil-geon-zazoo-pos-360-intel-n150-8gb-128gb-15) · 26/10/2026 |
| Impresora de tickets | 2 | Epson TM-T20III (USB + serie) | Térmica 80 mm, ESC/POS, corte automático | 251,58 | 503,16 | [PcComponentes](https://www.pccomponentes.com/opiniones/epson-tm-t20iii-impresora-tickets-usb-serial-negra) · 26/10/2026 |
| Cajón portamonedas | 2 | *por completar* (con conector RJ11 para abrirlo desde la impresora) | | | | [PcComponentes, cajones RJ11](https://www.pccomponentes.com/cajon-portamonedas-avpos-cash-u280-acero-5-billetes-8-monedas-negro-rj-11) |
| Equipo del gerente | 1 | *por completar* (4 núcleos, 16 GB, SSD NVMe 500 GB) | | | | |
| Monitor del gerente | 1 | *por completar* (24") | | | | |
| Licencia Windows Pro | 3 | Windows 11 Pro (permite instalar Windows 10 Pro con derechos de *downgrade*) | Microsoft ya no vende licencias de Windows 10 | | | [BleepingComputer](https://www.bleepingcomputer.com/news/microsoft/microsoft-stops-selling-windows-10-licenses-a-day-early) |
| SAI | 1 | *por completar* (≥ 850 VA para router, switch y servidores) | | | | |

> Nota sobre la impresora: según las opiniones de compradores, el modelo USB + serie de la TM-T20III no trae conexión para el cajón; para el restaurante real conviene el modelo con **Ethernet** (C31CH51012), que además permite ponerla en la VLAN de TPV.

## Red (R02, R04)

| Elemento | Cant. | Modelo / tarifa | Características | Precio (€) | Enlace y fecha |
|---|---|---|---|---|---|
| Línea de fibra para empresas | 1 | *por completar* (comparar 4 operadores: Movistar Empresas, Vodafone Business, Orange Empresas, Euskaltel/Digi) | Simétrica ≥ 300 Mb/s, IP fija, soporte 24 h, respaldo 4G/5G | /mes | |
| Router del local | 1 | *por completar* | Con VLAN y NAT | | |
| Switch gestionable 24 puertos | 1 | *por completar* | VLAN 802.1Q, port-security | | |
| Punto de acceso / router Wi-Fi | 2 | Los 2 routers del laboratorio | WDS, WPA2-AES | | |
| Cable Cat 6 U/UTP, conectores, tomas y panel | 1 lote | *por completar* | T568B | | |

## Arcade stick (S01)

| Elemento | Cant. | Detalle | Precio (€) | Enlace y fecha |
|---|---|---|---|---|
| Placa Arduino | 1 | La que da el centro | 0 | — |
| Joystick 8 direcciones | 1 | *por completar* | | |
| Botones 30 mm | 6 | *por completar* | | |
| Botones 24 mm | 3 | Moneda, Start, Menú | | |
| Cables faston 2,8 mm | 1 juego | | | |
| Caja | 1 | MDF o impresión 3D | | |

## Software (P03)

Todo el software del reto es gratuito salvo Windows: Ubuntu, MariaDB, PostgreSQL, Odoo Community (LGPL), Docker, nginx, MAME (GPL), KeePassXC, Arduino IDE, Terraform y AWS Academy (créditos del curso). Coste de software: solo las 3 licencias de Windows Pro.
