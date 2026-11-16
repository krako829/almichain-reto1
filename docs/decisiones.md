# Decisiones del reto y por qué las tomamos

Los cuatro grupos hemos montado lo mismo: un ERP con TPV, una base de datos con RAID y copias, los puestos Windows, la recreativa, el arcade stick, la red y la web. Lo que nos diferencia es **cómo** lo hemos hecho y **por qué**. Este capítulo recoge cada decisión importante, las alternativas que había y el motivo de la elección.

## Resumen

| Tema | Elegimos | En lugar de | Motivo principal |
|---|---|---|---|
| Dónde va Odoo | VM en VirtualBox, en el local | EC2 en AWS | El TPV tiene que cobrar aunque se caiga Internet, y los datos de clientes y facturas se quedan en el local |
| Dónde va la web | EC2 en AWS | Servidor en el local | Es pública: tiene que estar siempre en línea y separada de la red interna |
| Cómo se crea la web | Terraform (IaC) | Consola de AWS a mano | AWS Academy borra los laboratorios: con un `apply` vuelve igual |
| ERP | Odoo Community instalado en Ubuntu con systemd | Dolibarr, ERPNext | TPV, facturas, inventario y CRM en uno; arranca solo como servicio |
| Base de datos | MySQL, y una copia en el PostgreSQL de Odoo | Solo una de las dos | MySQL es el gestor de clase; en PostgreSQL queda junto a los datos de Odoo |
| Disco redundante | RAID 1 por software (mdadm) | RAID 0, RAID 5, controladora | Con 2 discos, el espejo es el único que aguanta un fallo |
| Copias | Local + otro servidor + nube (S3/EC2) | Solo una copia local | Regla 3-2-1: una copia fuera del local |
| Red de las VM | Adaptador puente (192.168.0.0/24) | Red NAT de VirtualBox | Las VM tienen que hablar con los equipos físicos: routers, impresora, móviles |
| Equipo del gerente | Arranque dual Windows 10 Pro + Debian 13 | Una sola VM con un sistema | Lo pide el enunciado; Windows primero para que GRUB gestione el arranque |
| Recreativa | VM aparte, Ubuntu mínimo, sin swap | MAME en el Debian del gerente | Limitarla a 1 núcleo y 1 GB sin afectar al equipo del gerente |
| TPV | Una VM con dos usuarios (TPV1 y TPV2) | Dos VM | La RAM del PC de clase (16 GB) no da para todas; la configuración es la misma |
| Windows | Windows 10 **Pro** | Home | Directivas de grupo y modo quiosco solo existen en Pro |
| Arcade stick | Arduino Leonardo como mando HID | Arduino Uno; mando comercial | Se reconoce como mando sin drivers y se puede personalizar |
| Wi-Fi | Repetidor WDS con el segundo router | Cablear o comprar un repetidor | Usamos los dos routers que hay, sin obras ni coste |
| Contraseñas | KeePassXC | Documento o repositorio | Cifradas en un solo archivo; nunca en Git |
| Trabajo en equipo | Git + GitHub y tablero Kanban | Carpetas compartidas | Historial de cambios y quién hizo cada tarea |

## Odoo en VirtualBox y no en AWS

**Lo que hicimos.** Odoo corre en la VM **ALMI-ODOO** (`odooserver`, 192.168.0.53) dentro del PC de clase, en la red del local.

**Alternativa.** Montarlo en una EC2 de AWS, como la web.

**Por qué no en AWS:**

1. **El restaurante tiene que poder cobrar sin Internet.** Los TPV y la impresora de tickets están en el local. Con Odoo en la nube, una caída de la fibra deja la barra sin poder cobrar; con Odoo en el local, los TPV siguen funcionando y solo se pierden el correo y la copia a la nube hasta que vuelva la línea.
2. **Los datos se quedan en el local.** Clientes, facturas y empleados son datos personales (RGPD). En el local controlamos quién llega a ellos.
3. **AWS Academy no sirve para un servicio que tiene que estar siempre encendido.** El laboratorio se apaga al terminar la sesión y la IP pública cambia; un ERP no puede desaparecer cada pocas horas.
4. **Latencia y periféricos.** La impresora de tickets y el cajón están conectados al TPV; con el servidor en la misma red la respuesta es inmediata.
5. **Coste.** En el local no hay cuota mensual; una EC2 con la RAM que pide Odoo sí la tendría.

**Lo que sí va a la nube:** lo que tiene que estar fuera del local, es decir, la web pública y las **copias** (S3 y la EC2 de copias remotas). Si el local se quema o roban el servidor, las copias siguen a salvo.

## La web en AWS y no en el local

**Por qué en AWS:**

- **Es pública**: tiene que estar disponible a todas horas y desde cualquier sitio. En el local habría que abrir puertos del router a Internet.
- **Separación**: si alguien ataca la web, no está en la misma red que los TPV ni que Odoo.
- **Dominio y HTTPS**: DuckDNS apunta a la IP elástica y Let's Encrypt da el certificado gratis.

**Por qué Terraform y no la consola de AWS:** AWS Academy borra los recursos al terminar el laboratorio. Con Terraform, `terraform apply` crea en minutos la misma instancia, el grupo de seguridad, la IP elástica y el certificado; y `terraform destroy` lo borra todo sin dejar nada facturando. Además, el código queda en Git: cualquiera del equipo puede repetirlo.

**Por qué HTML y CSS sin frameworks:** la web es informativa. Sin frameworks carga más rápido (Lighthouse 92/100/96/100 en local), no tiene dependencias que actualizar y se puede revisar entera. Solo hay JavaScript para la geolocalización, que es lo que pide el enunciado.

**Por qué DuckDNS:** es gratis y basta para tener un nombre fijo y un certificado de Let's Encrypt. Un dominio propio de pago sería lo siguiente para un restaurante real.

## Odoo y cómo lo instalamos

**Por qué Odoo:** tiene en un solo programa todo lo que pide el enunciado (facturas, clientes, personal, marketing, inventario y **TPV**), la versión Community es gratuita y es el ERP que indicó el profesor.

**Por qué instalado a mano y como servicio:** en Ubuntu Server, con su entorno virtual de Python y PostgreSQL 16, se ve cada pieza (configuración, usuario, base de datos). Como servicio de systemd arranca solo al encender el servidor y se reinicia si se cae.

## Base de datos

**Por qué MySQL y también PostgreSQL:** la base del restaurante se hizo en MySQL, el gestor que trabajamos en clase. Odoo usa PostgreSQL, así que la base del restaurante también se importó en el PostgreSQL del servidor de Odoo, para tener las dos juntas si hay que cruzar datos.

**Por qué RAID 1:** con dos discos, el espejo es la única opción que sigue funcionando si se rompe uno. RAID 0 pierde todo con un fallo y RAID 5 necesita tres discos. Lo hacemos **por software con mdadm** porque las VM no tienen controladora RAID y así se puede ver y probar el fallo de un disco.

**Por qué el RAID no basta:** el RAID protege de un disco roto, pero no de borrar una tabla por error ni de un virus. Para eso están las copias.

## Copias de seguridad: regla 3-2-1

| Copia | Dónde | Protege de |
|---|---|---|
| Datos originales | Disco de cada servidor (en RAID 1) | Fallo de un disco |
| Copia local | En el mismo servidor | Borrados por error |
| Copia cruzada | ALMI-ODOO ↔ ALMI-BD | Que se pierda un servidor entero |
| Copia en la nube | Bucket S3 y EC2 de copias remotas | Que se pierda el local (incendio, robo) |

- **Automáticas** (cron): una copia que depende de que alguien se acuerde acaba sin hacerse.
- **La clave de copias solo puede escribir**: si alguien entra en un servidor, no puede borrar ni leer las copias del otro.
- **Probadas**: una copia que no se ha restaurado nunca no sabemos si sirve. Por eso cada plan tiene su prueba de restauración.
- **Equipos de usuario** (bloque 08): Windows con copia completa y Debian con copia incremental, porque cambian de forma distinta.

## Red

**Por qué adaptador puente y no Red NAT:** con la Red NAT de VirtualBox las VM solo se veían entre ellas. Con el adaptador puente están en la red del reto (192.168.0.0/24), igual que un equipo físico: los TPV llegan a la impresora, los móviles a la Wi-Fi y el PC de clase administra todo por SSH.

**Por qué dos redes:** la red de clase (192.168.1.0/24) es la del aula. El router R1 la usa como WAN y crea nuestra propia red (192.168.0.0/24): así no interferimos con los otros grupos y controlamos el DHCP y las IP.

**Por qué IP fijas en los servidores:** los TPV, las copias y el certificado apuntan a una dirección concreta. Si Odoo cambiara de IP, los TPV dejarían de encontrarlo.

**Por qué WDS:** el segundo router amplía la cobertura de la Wi-Fi sin tirar cable ni comprar nada. Va sin DHCP, para que solo R1 reparta direcciones.

**Por qué la Wi-Fi de clientes va aparte (Packet Tracer):** los clientes no deben poder llegar a los TPV ni a los servidores. Por eso tienen su propia red, 192.168.50.0/24, detrás de su propio router.

## Puestos Windows

**Por qué arranque dual en el equipo del gerente:** lo pide el enunciado. Primero se instala Windows y después Debian, porque Windows sobrescribe el gestor de arranque; al revés, Debian desaparecería del menú.

**Por qué una sola VM para los dos TPV:** el PC de clase tiene 16 GB de RAM y hay que tener encendidos a la vez Odoo, la base de datos, el gerente y los TPV. La configuración que se evalúa (usuarios estándar, quiosco, impresora) es la misma en una VM con dos usuarios.

**Por qué Windows 10 Pro:** las directivas de grupo, el modo quiosco y el bloqueo de USB no existen en Home.

**Por qué mínimo privilegio:** solo `almiadmin` es administrador. El gerente usa su cuenta estándar y los camareros solo pueden abrir el TPV. Si un camarero pincha un USB con un virus o alguien se sienta en la barra, no puede instalar nada ni ver las facturas.

## Recreativa

**Por qué una VM aparte y no MAME en el Debian del gerente:** hay que demostrar que funciona con **1 núcleo y 1 GB**. En su propia VM se puede limitar exactamente sin afectar al equipo del gerente.

**Por qué Ubuntu mínimo:** trae una versión reciente de MAME en sus repositorios y la instalación mínima no lleva escritorio ni servicios que gasten memoria.

**Por qué sin swap:** con 1 GB, si el sistema empezara a usar el disco como memoria el juego iría a tirones. Sin swap, y con el sistema recortado, todo cabe en la RAM.

**Por qué entra sola en MAME:** es una máquina para clientes. El usuario `arcade` no tiene contraseña de administrador ni puede salir a un escritorio.

## Arcade stick

**Por qué Arduino Leonardo y no Uno:** el Leonardo (ATmega32U4) tiene USB nativo y el ordenador lo reconoce como **mando** sin instalar drivers. El Uno necesitaría reprogramar su chip USB.

**Por qué Arduino y no un mando comercial:** un mando comercial no se puede adaptar. Con Arduino elegimos los botones, el remapeo se cambia sin reprogramar (por el puerto serie, guardado en la EEPROM) y el antirrebote está en el código. Además es la tecnología habilitadora del reto: un sistema embebido sencillo y barato (el kit cuesta unos 33 €).

## Organización

**Por qué Git y GitHub:** guarda el historial de todos los cambios, se ve quién hizo cada cosa y nadie pisa el trabajo de otro.

**Por qué KeePassXC:** las contraseñas van cifradas en un solo archivo que se comparte fuera del repositorio. En Git nunca hay contraseñas.

**Por qué un tablero Kanban:** con cinco personas y ocho partes, hay que ver de un vistazo qué está hecho, qué falta y quién lo lleva.
