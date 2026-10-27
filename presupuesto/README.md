# Presupuesto global (G11)

Precios con IVA en tiendas online, con el enlace y la fecha en que se miraron, porque cambian a menudo. Las filas que todavía están *por completar* las rellena el responsable de cada bloque (P02, R02, S01). Por eso el total de abajo es **parcial**.

## Equipos del restaurante (P02)

| Elemento | Cant. | Modelo elegido | Características clave | Precio unidad (€) | Total (€) | Enlace y fecha |
|---|---|---|---|---|---|---|
| TPV táctil de barra | 2 | Geon Zazoo POS 360 | Intel N150, 8 GB, SSD 128 GB, táctil 15" Full HD, Windows 11, 4×USB 3.0, LAN | 556,94 | 1.113,88 | [PcComponentes](https://www.pccomponentes.com/tpv-tactil-geon-zazoo-pos-360-intel-n150-8gb-128gb-15) · 26/10/2026 |
| Impresora de tickets | 2 | Epson TM-T20III (USB + serie) | Térmica 80 mm, ESC/POS, corte automático | 251,58 | 503,16 | [PcComponentes](https://www.pccomponentes.com/opiniones/epson-tm-t20iii-impresora-tickets-usb-serial-negra) · 26/10/2026 |
| Cajón portamonedas | 2 | AVPos Cash-U280 | Acero, 5 billetes y 8 monedas, conector RJ11 (lo abre la impresora) | 45,99 | 91,98 | [PcComponentes](https://www.pccomponentes.com/cajon-portamonedas-avpos-cash-u280-acero-5-billetes-8-monedas-negro-rj-11) · 27/10/2026 |
| Equipo del gerente | 1 | *por completar* (4 núcleos, 16 GB, SSD NVMe 500 GB, **Windows 11 Pro incluido**) | | | | |
| Monitor del gerente | 1 | LG 24BA560-B | 23,8" IPS Full HD, altura ajustable, altavoces | 132,97 | 132,97 | [PcComponentes, monitores de 24"](https://www.pccomponentes.com/categorias/monitores-pc/24-pulgadas) · 27/10/2026 |
| SAI | 1 | APC Back-UPS BE850G2-GR | 850 VA, 8 enchufes Schuko, 2 USB (router, switch y servidores) | 144,99 | 144,99 | [PcComponentes](https://www.pccomponentes.com/apc-be850g2-gr-sai-850va-8-x-schucko-plus-2-x-usb) · 27/10/2026 |
| **Subtotal equipos** | | | | | **1.986,98** | Sin el equipo del gerente |

> **Impresora**: según las opiniones de compradores, el modelo USB + serie de la TM-T20III no trae conexión para el cajón; para el restaurante real conviene el modelo con **Ethernet** (C31CH51012), que además permite ponerla en la VLAN de TPV. No se ha encontrado su precio en una tienda española: *por completar* y sustituir la fila.
>
> **Licencias de Windows**: los TPV vienen con Windows 11 y el equipo del gerente se elige con Windows 11 Pro incluido, así que no hace falta comprar licencias aparte. Hay que comprobar que la de los TPV sea **Pro** (las directivas de grupo del quiosco no existen en Home); si fuera Home, sumar la actualización a Pro. Microsoft ya no vende licencias de Windows 10 ([BleepingComputer](https://www.bleepingcomputer.com/news/microsoft/microsoft-stops-selling-windows-10-licenses-a-day-early)). En el laboratorio se usa Windows 10 Pro/Education con la licencia del centro.

## Red (R02, R04)

| Elemento | Cant. | Modelo / tarifa | Características | Precio (€) | Enlace y fecha |
|---|---|---|---|---|---|
| Línea de fibra para empresas | 1 | *por completar* (comparar 4 operadores: Movistar Empresas, Vodafone Business, Orange Empresas, Euskaltel/Digi; cuota mensual × 12) | Simétrica ≥ 300 Mb/s, IP fija, soporte 24 h, respaldo 4G/5G | /mes | |
| Router del local | 1 | MikroTik hEX (RB750Gr3) | 5 puertos Gigabit, VLAN 802.1Q, NAT, cortafuegos, SSH | 61,90 | [Galaxus](https://galaxus.at/en/s1/product/mikrotik-rb750gr3-hex-routers-5831427) · 27/10/2026 |
| Switch gestionable 24 puertos | 1 | TP-Link TL-SG3428 | 24 Gigabit + 4 SFP, gestionable L2, VLAN 802.1Q, seguridad de puerto, SSH | 214,81 | [PcComponentes](https://www.pccomponentes.com/tp-link-tlsg3428-switch-24-puertos-gigabit-plus-4-sfp) · 27/10/2026 |
| Punto de acceso / router Wi-Fi | 2 | Los 2 routers del laboratorio | WDS, WPA2-AES | 0 | — |
| Cable Cat 6 U/UTP, conectores, tomas y panel | 1 lote | *por completar* | T568B | | |
| **Subtotal red** | | | | **276,71** | Sin la línea ni el cableado |

## Arcade stick (S01)

| Elemento | Cant. | Detalle | Precio (€) | Enlace y fecha |
|---|---|---|---|---|
| Placa Arduino | 1 | La que da el centro | 0 | — |
| Kit de joystick y botones | 1 | Eurojoystick 2 de 8 direcciones, 10 botones de 28 mm (8 de juego, 1 jugador y moneda), cables y microinterruptores. Trae un codificador USB que no hace falta (se usa el Arduino) | 33,05 | [Arcadexpress](https://www.arcadexpress.com/en/arcade-joystick-kits/118-kit-1-jugador-eurojoystick-2-10-botones-usb.html) · 27/10/2026 |
| Caja | 1 | MDF o impresión 3D: *por completar* | | |
| **Subtotal arcade stick** | | | **33,05** | Sin la caja |

## Software (P03)

Todo el software del reto es gratuito: Ubuntu, MariaDB, PostgreSQL, Odoo Community (LGPL), Docker, nginx, MAME (GPL), KeePassXC, Arduino IDE, Terraform y AWS Academy (créditos del curso). Windows va incluido en los equipos (ver la nota de licencias).

## Total

| Apartado | Total (€) |
|---|---|
| Equipos | 1.986,98 |
| Red | 276,71 |
| Arcade stick | 33,05 |
| **Total parcial (con IVA)** | **2.296,74** |
| Línea de fibra | *por completar* €/mes (gasto mensual, aparte) |

**Falta para el total completo**: equipo del gerente, impresora con Ethernet (sustituye a la USB), cableado, caja del stick y la cuota de la línea.
