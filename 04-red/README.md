# 4. Red: WAN, plano, Packet Tracer y repetidor WDS

## Objetivo

Diseñar la red del restaurante: elegir la línea **WAN**, hacer el **plan de direccionamiento con VLAN**, el **plano del local**, la red completa en **Packet Tracer** (switch, router, operador, servidores, TPV, Wi-Fi) con seguridad, y configurar los **dos routers físicos**: el principal seguro y el secundario como **repetidor WDS**.

Tareas del tablero: R01 a R10.

## Necesidades de comunicación (R01)

| Equipo | Cantidad | Conexión | VLAN | Necesita |
|---|---|---|---|---|
| Equipo del gerente | 1 | Cable | 10 Gestión | Odoo, servidores, Internet |
| Servidor BD (ALMI-BD) | 1 | Cable | 10 Gestión | Red interna |
| Servidor ERP (ALMI-ODOO) | 1 | Cable | 10 Gestión | Red interna, Internet (correo) |
| TPV de barra | 2 | Cable | 20 TPV | Solo Odoo e Internet |
| Impresora de tickets | 2 | USB al TPV (o cable) | 20 TPV | Solo su TPV |
| Recreativa | 1 | Cable | 30 Clientes | Nada (opcional Internet) |
| Wi-Fi de clientes | 2 puntos (principal + repetidor) | Inalámbrico | 30 Clientes | Solo Internet |
| Router, switch y puntos de acceso | — | — | 99 Administración | Solo los administra almiadmin |

## Línea WAN (R02)

Lo que necesita el restaurante: fibra **simétrica** (las copias suben a la nube), suficiente para los TPV, Odoo, la Wi-Fi de clientes y las copias, **línea fija** para las reservas, router con buena Wi-Fi y sin permanencia larga. Se han comparado las ofertas de fibra para negocios de dos operadores, a la misma velocidad (600 Mb), consultadas el 16 de noviembre de 2026 en sus páginas oficiales:

| | **Movistar** · Fibra 600 Mb Autónomos | **Vodafone Business** · Fibra óptica 600 Mbps |
|---|---|---|
| Velocidad | 600 Mb simétricos | 600 Mb simétricos (según cobertura) |
| Precio con IVA | **24,90 €/mes** los 12 primeros meses, después 35,00 €/mes | **37,05 €/mes** (30,62 € sin IVA) |
| Precio sin IVA | 20,57 €/mes, después 28,93 €/mes | 30,62 €/mes |
| Coste el primer año (con IVA) | **298,80 €** | **444,60 €** |
| Línea fija | Incluida: llamadas ilimitadas a fijos y 50 min/mes a móviles | Incluida: 6.000 min/mes a fijos y móviles nacionales |
| Router | Smart WiFi 7 | WiFi 6, hasta 120 dispositivos |
| Alta e instalación | Gratis | Gratis (oferta web) |
| Permanencia | Sin permanencia | No se indica |
| Soporte | Llamadas de clientes prioritarias | Soporte preferente para empresas |
| IP fija | No se indica: hay que pedirla aparte | No se indica: hay que pedirla aparte |
| Fuente | [movistar.es · Internet autónomos](https://www.movistar.es/autonomos/fibra-optica/internet-autonomos) (promoción hasta el 30/11/2026) | [vodafone.es · Fibra pymes](https://www.vodafone.es/c/empresas/pymes/es/conectividad/internet-fijo-y-television/fibra/) |

**Elección: Movistar Fibra 600 Mb.** A la misma velocidad cuesta unos 146 € menos el primer año y, después de la promoción, sigue siendo más barata (35,00 € frente a 37,05 € al mes). Además no tiene permanencia, las llamadas a fijos son ilimitadas y el router es Wi-Fi 7. Ninguna de las dos incluye IP fija en la oferta: hay que pedirla al contratar, porque el local no la necesita para navegar pero sí si un día se quiere acceder a Odoo desde fuera.

## Plan de direccionamiento (R03)

| VLAN | Nombre | Red | Puerta de enlace | DHCP | Direcciones fijas |
|---|---|---|---|---|---|
| 10 | GESTION | 192.168.10.0/24 | 192.168.10.1 | .100 – .199 | BD .20, Odoo .30 |
| 20 | TPV | 192.168.20.0/24 | 192.168.20.1 | .100 – .199 | Impresoras .50 y .51 |
| 30 | CLIENTES | 192.168.30.0/24 | 192.168.30.1 | .100 – .250 | — |
| 99 | ADMIN | 192.168.99.0/24 | 192.168.99.1 | Sin DHCP | Switch .2 |
| 998 | SIN-USO | — | — | — | Puertos libres apagados |
| 999 | NATIVA | — | — | — | Nativa del troncal, sin equipos |
| WAN | Operador | 203.0.113.0/30 | 203.0.113.1 | — | Router del local .2 |

La VLAN 10 coincide con la Red NAT ALMICHAIN de VirtualBox (192.168.10.0/24): los servidores tienen la misma IP en el laboratorio y en el diseño.

## Plano y esquema lógico (R04)

**Plano del local: pendiente.** Se hará en draw.io (`diagramas/red-plano.drawio` y `.png`) con la vista del local, el rack, las tomas T01…, los cables Cat 6 U/UTP T568B, el router Wi-Fi en la sala y el repetidor WDS en la terraza con su cobertura. Todavía **no está** en el repositorio.

**Esquema lógico** (VLAN, direcciones y reglas entre redes):

```mermaid
flowchart TB
  ISP["Operador · 203.0.113.1"] --- R["R-ALMI 2911<br/>G0/1 203.0.113.2 · NAT"]
  R -- "G0/0 troncal 802.1Q<br/>nativa 999" --- SW["SW-ALMI 2960<br/>Gi0/1"]
  SW --- V10["VLAN 10 GESTION 192.168.10.0/24<br/>PC-GERENTE · SRV-BD .20 · SRV-ODOO .30"]
  SW --- V20["VLAN 20 TPV 192.168.20.0/24<br/>TPV1 · TPV2 · IMP-TICKET1 .50"]
  SW --- V30["VLAN 30 CLIENTES 192.168.30.0/24<br/>AP-SALA · AP-TERRAZA · RECREATIVA"]
  SW --- V99["VLAN 99 ADMIN 192.168.99.0/24<br/>switch .2"]
  V30 -. "ACL: solo Internet" .-x V10
  V20 -. "ACL: solo Odoo (443/80)" .-> V10
```

## Red final en Packet Tracer (Gontzal, 12 de noviembre)

Archivo: [`packet-tracer/RETO1-FINAL.pkz`](packet-tracer/RETO1-FINAL.pkz).

![Red final en Packet Tracer](capturas/01-packet-tracer-red-final.png)

| Zona | Red | Equipos |
|---|---|---|
| Local (switch SW-Local) | 192.168.0.0/24, puerta de enlace 192.168.0.1 | Odoo .53 (con la impresora), BD-MySQL .54, PC-Gerente .61 (doble arranque), TPV-1 .71, TPV-2 .72, PC-Recreativa .81 |
| Router R-Principal (2911) | Gi0/0 192.168.0.1 (LAN), Gi0/1 192.168.1.112 (WAN), Gi0/2 192.168.2.1 (Wi-Fi) | — |
| Wi-Fi de clientes (WRT300N) | WAN 192.168.2.2, LAN 192.168.50.0/24 con DHCP desde .100, WPA2 | Móviles de los clientes, separados del local |
| Internet (switch SW-Internet) | 192.168.1.0/24, puerta de enlace 192.168.1.112 | Internet, Web-AWS, DuckDNS, Trello, GitHub y nginx (simulados) |

Los clientes de la Wi-Fi están en una red aparte (192.168.50.0/24), detrás de su propio router, así que no llegan a los equipos del local.

## Packet Tracer (R05-R06)

Equipos: R-ALMI y ISP (Router 2911), SW-ALMI (2960-24TT), INTERNET (Server-PT), PC-GERENTE, SRV-BD, SRV-ODOO, TPV1, TPV2, IMP-TICKET1, AP-SALA, AP-TERRAZA, RECREATIVA y dos portátiles con WPC300N.

| Puerto del switch | Equipo | VLAN | Seguridad |
|---|---|---|---|
| Fa0/1-3 | Gerente, BD, Odoo | 10 | port-security, 1 MAC sticky, shutdown |
| Fa0/5-7 | TPV1, TPV2, impresora | 20 | port-security, 1 MAC sticky, shutdown |
| Fa0/10-12 | AP-SALA, AP-TERRAZA, recreativa | 30 | portfast |
| Gi0/1 | R-ALMI | troncal 10,20,30,99 | nativa 999 |
| Resto | — | 998 | apagados |

Configuraciones por línea de comandos, listas para pegar en la pestaña **CLI** (lo que se hace con el ratón está justo después):

| Archivo | Equipo | Qué configura |
|---|---|---|
| [`packet-tracer/SW-ALMI.txt`](packet-tracer/SW-ALMI.txt) | Switch | VLAN, puertos de acceso con seguridad, troncal, puertos sin uso apagados, IP de gestión en VLAN 99, SSH v2 solo desde las VLAN 10 y 99 |
| [`packet-tracer/R-ALMI.txt`](packet-tracer/R-ALMI.txt) | Router | Subinterfaces 802.1Q, DHCP por VLAN (solo en el rango del plan), NAT con sobrecarga, ACL de clientes y de TPV, SSH v2 solo desde las VLAN 10 y 99 (`access-class`), bloqueo tras 3 intentos fallidos |
| [`packet-tracer/ISP.txt`](packet-tracer/ISP.txt) | Operador | Enlace WAN y red de "Internet" 198.51.100.0/24 |

Listas de acceso del router:

- **CLIENTES-SOLO-INTERNET** (entrada en G0/0.30): los clientes del Wi-Fi no llegan a Gestión, TPV ni Administración.
- **TPV-SOLO-ODOO** (entrada en G0/0.20): los TPV solo llegan a Odoo (192.168.10.30) por **443** (y 80, que redirige a HTTPS); el resto de Gestión y Administración, bloqueado.

### Lo que se configura con el ratón (no tiene CLI en Packet Tracer)

**Servidor INTERNET** (simula una web de fuera): **Desktop → IP Configuration → Static**: IP 198.51.100.10, máscara 255.255.255.0, puerta 198.51.100.1, DNS 198.51.100.10. **Services → DNS**: activado, nombre `www.ejemplo.com` → 198.51.100.10. **Services → HTTP**: activado.

**Equipos con IP fija** (Desktop → IP Configuration → Static):

| Equipo | IP | Máscara | Puerta de enlace | DNS |
|---|---|---|---|---|
| SRV-BD | 192.168.10.20 | 255.255.255.0 | 192.168.10.1 | 198.51.100.10 |
| SRV-ODOO | 192.168.10.30 | 255.255.255.0 | 192.168.10.1 | 198.51.100.10 |
| IMP-TICKET1 | 192.168.20.50 | 255.255.255.0 | 192.168.20.1 | — |

En SRV-ODOO se dejan activados **Services → HTTP** y **HTTPS** (simulan la web de Odoo). La ACL de los TPV deja pasar los dos puertos, así que la prueba 6 se puede hacer con `http://` y con `https://`.

**Equipos con DHCP**: PC-GERENTE, TPV1, TPV2 y RECREATIVA → **Desktop → IP Configuration → DHCP**. Tiene que salir una IP de su VLAN (por ejemplo 192.168.20.100 en TPV1).

**Wi-Fi de clientes**:

1. AP-SALA y AP-TERRAZA → **Config → Port 1**: SSID `AlmiChain-Clientes`, **WPA2-PSK**, clave de 12 caracteres o más, cifrado **AES** (los dos iguales).
2. CLIENTE1 y CLIENTE2 → **Physical**: apagar, quitar el módulo de cable, poner **WPC300N**, encender.
3. **Config → Wireless0**: mismo SSID, WPA2-PSK, la misma clave, IP por **DHCP**. Tiene que salir una IP 192.168.30.x.

El archivo de Packet Tracer se guardará como `packet-tracer/almichain.pkt` (indicando la versión de Packet Tracer). **Todavía no está en el repositorio**: la red no se ha montado aún.

## Routers reales (R07-R08)

**R1, principal**: reset de fábrica, contraseña de administración nueva, firmware actualizado, SSID `AlmiChain-Clientes`, **canal fijo** (1, 6 u 11, el menos usado: `nmcli -f SSID,CHAN,SIGNAL dev wifi list`), ancho de 20 MHz, **WPA2-PSK AES**, **WPS desactivado**, **administración remota y UPnP desactivados**, aislamiento de clientes si lo tiene.

**R2, repetidor WDS**: reset, contraseña nueva, **IP de LAN en la red de R1 fuera de su rango DHCP** (p. ej. 192.168.0.2), **DHCP desactivado**, **mismo canal** que R1, **Habilitar puente WDS** → buscar `AlmiChain-Clientes` → WPA2-PSK con la clave de R1. En Estado tiene que poner WDS **Run/Conectado**. Si el modelo no tiene WDS, se usa el modo repetidor/extensor y se documenta.

Guía detallada: [`routers/configuracion-routers.md`](routers/configuracion-routers.md).

## Seguridad aplicada

- **Segmentación por VLAN**: gestión, TPV, clientes y administración separadas; la VLAN nativa del troncal (999) y la de los puertos sin uso (998) no llevan tráfico.
- **ACL en el router**: los clientes del Wi-Fi solo salen a Internet; los TPV solo llegan a Odoo por 443 y 80.
- **Puertos del switch**: *port-security* con 1 MAC aprendida (*sticky*) y apagado si cambia; puertos sin uso apagados.
- **Administración**: solo por SSH v2 con usuario local, solo desde las VLAN 10 y 99 (`access-class`), bloqueo tras 3 intentos fallidos, cierre por inactividad y contraseñas cifradas (`enable secret`, `service password-encryption`).
- **Wi-Fi**: WPA2-PSK con AES y clave de 12 caracteres o más; WPS, administración remota y UPnP desactivados; aislamiento de clientes si el router lo permite.
- Contraseñas de los equipos de red en KeePassXC, nunca en los archivos del repositorio (`<contraseña>`).

## Pruebas (R09-R10)

| Nº | Qué se prueba | Cómo | Resultado esperado | Resultado obtenido | Captura |
|---|---|---|---|---|---|
| 1 | VLAN | `show vlan brief` en SW-ALMI | Puertos en 10, 20, 30 y 998 | Pendiente — en clase | |
| 2 | Troncal | `show interfaces trunk` | Gi0/1, nativa 999, VLAN 10,20,30,99 | Pendiente — en clase | |
| 3 | DHCP | `show ip dhcp binding` en R-ALMI | IPs a PCs y portátiles | Pendiente — en clase | |
| 4 | Cliente a Internet | CLIENTE1 → http://www.ejemplo.com | Abre la web | Pendiente — en clase | |
| 5 | Cliente aislado | CLIENTE1 `ping 192.168.10.30` y `192.168.20.100` | Fallan | Pendiente — en clase | |
| 6 | TPV solo a Odoo | TPV1 → http://192.168.10.30 y `ping 192.168.10.20` | Abre Odoo; el ping falla | Pendiente — en clase | |
| 7 | Gerente | `ping 192.168.10.20` y `198.51.100.10` | Responden | Pendiente — en clase | |
| 8 | NAT y ACL | `show ip nat translations` y `show access-lists` | Traducciones y coincidencias en los deny | Pendiente — en clase | |
| 9 | SSH | PC-GERENTE `ssh -l almiadmin 192.168.10.1` | Entra en R-ALMI | Pendiente — en clase | |
| 9b | SSH bloqueado desde fuera de gestión | CLIENTE1 `ssh -l almiadmin 192.168.30.1` y TPV1 `ssh -l almiadmin 192.168.20.1` | Conexión rechazada | Pendiente — en clase | |
| 10 | Routers seguros | Contraseña de fábrica y WPS | No entra con la de la pegatina; WPS desactivado | Pendiente — en clase | |
| 11 | Cliente en R2 recibe IP de R1 | `ip -4 addr` y `ip route` | Red de R1, puerta = R1 | Pendiente — en clase | |
| 12 | Repetidor sin pérdidas | `ping -c 20` a R1 y a 8.8.8.8 | 0 % de pérdidas | Pendiente — en clase | |
| 13 | Velocidad y cobertura | `iperf3 -c` en 4 puntos | Por R2 ~la mitad (normal en WDS); en el punto más lejano R2 da más señal | Pendiente — en clase | |

**Estado**: la red todavía no se ha montado en Packet Tracer ni con los routers físicos: las configuraciones se han revisado a mano, pero ninguna prueba está hecha. El `.pkt`, las capturas y los resultados se hacen en clase.

## Problemas encontrados y previstos

La red todavía no se ha montado en Packet Tracer ni con los routers físicos. El primer problema se encontró al revisar la configuración de la guía; los otros dos son **previstos** (documentación de los fabricantes y de la guía), no observados.

| Problema | Solución |
|---|---|
| (Encontrado al revisar) La ACL de la guía dejaba a los TPV solo el puerto 80, pero Odoo va por HTTPS | Se añade `permit tcp 192.168.20.0 0.0.0.255 host 192.168.10.30 eq 443` antes del `deny` |
| WDS no funciona con WPA3 en la mayoría de routers domésticos | WPA2-PSK con AES en los dos |
| Con canal automático el WDS se cae | Canal fijo e igual en R1 y R2 |

## Fuentes

- Cisco Packet Tracer: configuración de VLAN, router-on-a-stick, DHCP, NAT y ACL extendidas.
- Manual del fabricante de los routers (modo WDS).
- Guías paso a paso del equipo, parte 5.
