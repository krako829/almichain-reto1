# Resumen de pruebas, conclusiones y trabajo pendiente

## Resumen de las pruebas

Cada bloque tiene su tabla de pruebas con el resultado obtenido y la captura. Este es el resumen a fecha de 10 de noviembre de 2026.

| Bloque | Pruebas hechas | Pendientes | Dónde se hicieron |
|---|---|---|---|
| 01 Windows gerente y TPV | 4 de 14 (arranque dual, administradores de ALMI-TPV, directiva de contraseñas, Defender y cortafuegos) | Usuario Gerente, quiosco, impresora y certificado de Odoo | VirtualBox en clase |
| 02 Recreativa | 7 de 9 | Benchmark en la VM de VirtualBox y prueba con el stick | VM y anfitrión (benchmark) |
| 03 Arcade stick | 0 de 8 (los cuatro programas compilan, incluido el configurable con antirrebote y remapeo) | Todas | — (necesita la placa y el material) |
| 04 Red | 0 de 14 | Todas | — (necesita Packet Tracer y los routers) |
| 05 ERP Odoo | 9 de 12 completas, 3 a medias | Envío real del correo, ticket en la impresora física y fallo del RAID del servidor | Servidor de Odoo y VirtualBox (RAID 1, 30 oct) |
| 06 Web en AWS | 0 de 10 documentadas (Lighthouse hecho solo en local); la web ya está desplegada | Capturas y pruebas | AWS Academy |
| 08 Copias de los SO | Fallo de disco del RAID, copia de Windows y Debian, incremental, retención, cron semanal real (10 nov), réplica en AWS y restauración desde AWS. **Validado por el profesor** | — | VirtualBox en clase y AWS Academy |
| 07 Base de datos | 15 de 15 | Repetir en VirtualBox las del RAID | VM de la base de datos |

## Conclusiones

**Lo que funciona y está demostrado.** El ERP Odoo con los dos TPV factura solo al cobrar a un cliente, publica la factura, la deja lista para enviar por correo con el PDF y descuenta el stock; todo publicado solo por HTTPS. La base de datos propia tiene 13 tablas normalizadas, usuarios de mínimo privilegio, copias diarias comprobadas con su huella, copia cruzada a la otra máquina y restauración probada; el RAID 1 aguanta la pérdida de un disco y se reconstruye. La recreativa arranca sola en MAME con 1 núcleo, 1 GB y sin swap, y no usa swap mientras se juega. Las tres VM Linux se pueden reconstruir con [`herramientas/`](../herramientas/README.md) (hacen falta las contraseñas iniciales, acceso a los repositorios de Ubuntu y, para Odoo, un Odoo ya configurado del que sacar los datos) y generan sus propias claves y contraseñas de servicio al importarse; solo comparten la contraseña inicial de `almiadmin` (obligatorio cambiarla) y la clave de las copias cruzadas.

**Lo que está preparado pero falta probar.** Los puestos Windows ya están instalados en VirtualBox con arranque dual en el equipo del gerente, pero falta el quiosco de los TPV, la impresora y el certificado. La red (Packet Tracer y routers físicos), el arcade stick y la web en AWS tienen su procedimiento, sus scripts y sus configuraciones revisados, pero no se han ejecutado todavía: dependen de material, licencias o cuentas que se usan en clase. Sus tablas de pruebas están marcadas como «Pendiente — en clase».

**Lo que se aprendió de la revisión.** Una revisión interna del proyecto (hecha con ayuda de IA) encontró y se corrigieron, entre otros: un certificado HTTPS que podía firmar certificados para cualquier web, una clave de copias que permitía borrar las copias del otro servidor, un orden de pasos en la base de datos que dejaba los datos ocultos bajo el RAID, una directiva de contraseñas que se aplicaba después de crear los usuarios y documentación que daba por hechas cosas que faltaban. La lección principal: **cada afirmación tiene que tener su prueba**, y lo que no se ha probado se dice.

**Valoración del equipo**: *por escribir por el equipo al terminar el reto (qué ha ido bien, qué cambiaríamos y qué ha aprendido cada uno).*

## Trabajo pendiente antes de la entrega (13 de noviembre)

1. Montar en clase los bloques 03, 04 y 06, terminar el 01 (quiosco, impresora, certificado; se puede hacer con sus scripts) y rellenar sus tablas de pruebas con capturas.
3. Poner la contraseña de aplicación de Gmail en Odoo y probar el envío real; imprimir un ticket en la impresora física.
4. Gestión: repartir las tareas en el tablero, exportarlo, Anexo I firmado (sin datos personales en el repositorio), Anexo II y commits de los cinco.
6. Diagramas que faltan: plano del local (draw.io), archivo `.pkt` de Packet Tracer y **diseño conceptual (boceto) de la web**.
7. Recreativa: 3 ROMs legales de mamedev.org y un tercer juego en el benchmark.
8. Windows: `Test-NetConnection` al 443 y al 8069 de Odoo desde ALMI-TPV (prueba 2 de Odoo desde Windows).
9. Web: hacer público el repositorio de la web (W04) si lo pide el profesor; hoy es privado.
10. Presentación final (G15) y valoración del equipo (apartado de conclusiones).

## Bibliografía

Documentación oficial consultada (cada capítulo tiene además sus propias fuentes):

- Odoo 18: documentación oficial, <https://www.odoo.com/documentation/18.0/>, e instalación en servidor, <https://www.odoo.com/documentation/18.0/administration/on_premise/deploy.html>.
- Imagen de Docker de Odoo: <https://hub.docker.com/_/odoo>.
- MariaDB Knowledge Base: <https://mariadb.com/kb/>.
- Linux RAID (mdadm): <https://raid.wiki.kernel.org/>.
- rsync y rrsync: páginas de manual `rsync(1)` y `rrsync(1)` de Ubuntu 24.04.
- OpenSSL: página de manual `openssl-req(1)` y `x509v3_config(5)`.
- nginx: <https://nginx.org/en/docs/>.
- Ubuntu Server 24.04: <https://documentation.ubuntu.com/server/>.
- Terraform, proveedor de AWS: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs>.
- Let's Encrypt y Certbot: <https://certbot.eff.org/>; DuckDNS: <https://www.duckdns.org/install.jsp>.
- MDN, API de geolocalización: <https://developer.mozilla.org/es/docs/Web/API/Geolocation_API>.
- MAME: <https://docs.mamedev.org/> y ROMs legales <https://www.mamedev.org/roms/>.
- Arduino, librería Keyboard: <https://docs.arduino.cc/language-reference/en/functions/usb/Keyboard/>; ArduinoJoystickLibrary: <https://github.com/MHeironimus/ArduinoJoystickLibrary>.
- Cisco Packet Tracer y documentación de IOS de Cisco (VLAN, ACL, NAT, SSH).
- Microsoft: documentación de PowerShell (módulo `Microsoft.PowerShell.LocalAccounts`) y de directivas de grupo.

## Índice de anexos

| Anexo | Qué es | Dónde |
|---|---|---|
| A | Routers reales y repetidor WDS | [`04-red/routers/configuracion-routers.md`](../04-red/routers/configuracion-routers.md) |
| B y C | Web: guía de despliegue y explicación del código | [`06-web-aws/docs/`](../06-web-aws/docs/) |
| D | Web: diseño (secciones, colores, responsive, accesibilidad) | [`06-web-aws/docs/00-diseno-web.md`](../06-web-aws/docs/00-diseno-web.md) |
| — | Guías paso a paso del equipo (planificación previa) | [`00-gestion/Guias-paso-a-paso-Reto1-Almi-Chain.docx`](../00-gestion/Guias-paso-a-paso-Reto1-Almi-Chain.docx) |
| — | Anexo I y Anexo II del reto | Pendientes (ver [00-gestion](../00-gestion/README.md)) |
