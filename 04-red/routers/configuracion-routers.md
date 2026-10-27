# Routers reales: principal seguro y repetidor WDS

## 1. Configuración

Los menús cambian según la marca. Los nombres de abajo son los habituales (TP-Link entre paréntesis). Apunta modelo y versión de firmware de cada router.

**Router principal (R1)**, conectado a la toma de red de clase por su puerto WAN:

1.  Reinícialo de fábrica: con él encendido, mantén pulsado el botón RESET 10 segundos.

2.  Conecta el PC por cable a un puerto LAN. Mira la puerta de enlace con `ip route | grep default` (por ejemplo 192.168.0.1) y ábrela en el navegador. Usuario y contraseña de fábrica: en la pegatina del router.

3.  Cambia la contraseña de administración (Herramientas del sistema → Contraseña). Guárdala en KeePassXC.

4.  Actualiza el firmware si hay versión nueva (Herramientas del sistema → Actualización de firmware).

5.  Wi-Fi (Inalámbrico → Configuración):

    - SSID: AlmiChain-Clientes.

    - Región: España.

    - Canal: **fijo** (no automático). Elige el 1, el 6 o el 11, el menos usado. Para verlo desde Zorin: `nmcli -f SSID,CHAN,SIGNAL dev wifi list`.

    - Ancho de canal: **20 MHz** (más estable con WDS).

6.  Seguridad Wi-Fi: **WPA2-PSK** con cifrado **AES** y una clave de 12 caracteres o más. No uses WPA3: la mayoría de routers no admiten WDS con WPA3.

7.  Desactiva **WPS** (Inalámbrico → WPS → Deshabilitar).

8.  Desactiva la **administración remota** (Seguridad → Administración remota: IP 0.0.0.0 o desactivado) y **UPnP** (Reenvío → UPnP).

9.  Si tiene opción de **aislamiento de clientes** (AP Isolation), actívala: los clientes del Wi-Fi no se ven entre ellos.

10. Mira el rango DHCP (DHCP → Configuración), por ejemplo .100 a .199. Lo necesitas para el paso siguiente.

11. Guarda y haz capturas de cada pantalla.

**Router secundario (R2)**, sin cable al principal; solo por Wi-Fi:

1.  Reinícialo de fábrica y conéctate a él por cable desde el PC.

2.  Cambia su contraseña de administración y guárdala.

3.  Cambia su IP de LAN (Red → LAN) a una de la red de R1 que **no** esté en el rango DHCP de R1. Ejemplo: si R1 es 192.168.0.1, pon R2 en 192.168.0.2. Guarda. El router se reinicia: entra de nuevo con la IP nueva.

4.  Desactiva su **servidor DHCP** (DHCP → Deshabilitar). Solo reparte IPs R1.

5.  Inalámbrico → Configuración:

    - SSID: AlmiChain-Clientes-2 (distinto para las pruebas; al final puede ser el mismo que R1).

    - Canal: **el mismo** que R1. Ancho: 20 MHz.

    - Marca **Habilitar puente WDS** (Enable WDS Bridging).

    - Pulsa **Buscar** (Survey) → en la lista, **Conectar** en AlmiChain-Clientes.

    - Tipo de clave: **WPA2-PSK**. Contraseña: la de R1. Guarda.

6.  Seguridad Wi-Fi del propio R2: WPA2-PSK, AES, clave de 12 caracteres o más.

7.  Desactiva WPS, administración remota y UPnP, como en R1.

8.  Reinicia R2. En **Estado** (Status), el estado WDS tiene que poner **Run** o "Conectado".

9.  Si vuestro modelo no tiene WDS, busca "Modo repetidor" o "Extensor de cobertura" y documenta que se usó ese modo.

## 2. Pruebas del repetidor

1.  Conecta un portátil o móvil a AlmiChain-Clientes-2 (R2). Desconecta el cable del PC si lo tiene.

2.  Comprueba que la IP la da R1 (misma red y puerta de enlace = IP de R1):

    ```bash
    ip -4 addr show
    ip route | grep default
    ```

3.  Comprueba que llega a R1 y a Internet sin pérdidas (tiene que poner 0% packet loss):

    ```bash
    ping -c 20 192.168.0.1
    ping -c 20 8.8.8.8
    ```

4.  Velocidad con iperf3: en un PC conectado **por cable a R1**, `sudo apt install -y iperf3` y luego `iperf3 -s`. En el portátil (también con iperf3 instalado), primero conectado a R1 y después a R2 (cambiando `IP_DEL_PC_SERVIDOR` por la IP de ese PC):

    ```bash
    iperf3 -c IP_DEL_PC_SERVIDOR -t 20
    ```

5.  Es normal que a través de R2 salga más o menos la mitad: con WDS cada paquete viaja dos veces por el aire. Escríbelo en la documentación.

6.  Cobertura: elige 4 puntos (al lado de R1, mitad del pasillo, al lado de R2, el punto más lejano). En cada uno mide la señal con `nmcli -f SSID,SIGNAL,CHAN dev wifi list` o con una app de móvil (WiFi Analyzer) y rellena:

| Punto             | Señal de R1 (%) | Señal de R2 (%) | Velocidad iperf3 (Mb/s) |
|-------------------|-----------------|-----------------|-------------------------|
| Junto a R1        | Pendiente — en clase | | |
| Mitad del pasillo | Pendiente — en clase | | |
| Junto a R2        | Pendiente — en clase | | |
| Punto más lejano  | Pendiente — en clase | | |

> Estado: los routers físicos todavía no se han configurado; esta tabla y las capturas se rellenan en clase.

