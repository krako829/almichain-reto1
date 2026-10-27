#!/usr/bin/env python3
"""Almi-Chain · Manejar una VM de QEMU por su consola serie (la que crea qemu-vm.sh ... serie).

  consola.py SOCKET entrar USUARIO CONTRASEÑA [CONTRASEÑA_NUEVA]
      Espera "login:", entra y, si el sistema obliga a cambiar la contraseña (chage -d 0),
      la cambia por CONTRASEÑA_NUEVA. Deja la sesión con TERM=dumb y sin colores.
  consola.py SOCKET orden SEGUNDOS_MAX "orden"
      Ejecuta la orden y escribe su salida (sin el eco ni el prompt). Espera a que termine
      con una marca, no un tiempo fijo. Código de salida = el de la orden.
  consola.py SOCKET transcribir SALIDA.txt SEGUNDOS_MAX "orden1" ["orden2" ...]
      Ejecuta las órdenes y guarda la transcripción ("$ orden" + salida real) en SALIDA.txt.
      De ahí se hacen las capturas con pintar-terminal.py.
  consola.py SOCKET escribir "texto"      Escribe una línea tal cual (p. ej. una contraseña de sudo).

Las contraseñas se pasan como argumentos: usar solo en la máquina de pruebas.
"""
import codecs, re, socket, sys, time, random

ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07|\r')


class Consola:
    def __init__(self, ruta):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(ruta)
        self.s.settimeout(0.3)
        self.buf = ''
        # Decodificador incremental: una letra con tilde puede llegar partida en dos lecturas
        self.dec = codecs.getincrementaldecoder('utf-8')('replace')

    def leer(self, segundos):
        fin = time.time() + segundos
        while time.time() < fin:
            try:
                d = self.s.recv(65536)
                if not d:  # QEMU ha cerrado la consola (VM apagada o caída)
                    raise SystemExit('La consola serie se ha cerrado: la VM ya no está en marcha')
                self.buf += self.dec.decode(d)
            except socket.timeout:
                pass
        return self.buf

    def esperar(self, patron, segundos):
        fin = time.time() + segundos
        while time.time() < fin:
            m = re.search(patron, ANSI.sub('', self.buf))
            if m:
                return m
            self.leer(0.5)
        return None

    def escribir(self, texto):
        self.s.send((texto + '\r').encode())

    def orden(self, orden, segundos):
        marca = f'FIN{random.randint(10**6, 10**7)}'
        self.buf = ''
        # printf con \n delante: la marca sale en su propia línea aunque la salida no acabe en \n
        self.escribir(f'{orden}; printf "\\n{marca}=%d\\n" $?')
        m = self.esperar(rf'\n{marca}=(\d+)', segundos)
        texto = ANSI.sub('', self.buf)
        if not m:
            return None, texto
        # El eco de la orden (printf ... FIN...) puede salir dos veces (eco del terminal y bash
        # al pintar el prompt): la salida empieza después de la ÚLTIMA aparición antes del final
        eco = texto.rfind(marca, 0, m.start())
        inicio = texto.find('\n', eco) + 1 if 0 <= eco < m.start() else 0
        salida = texto[inicio:m.start()]
        return int(m.group(1)), salida.strip('\n')


def entrar(c, usuario, clave, nueva=None):
    c.escribir('')
    if not c.esperar(r'login: *$', 600):
        sys.exit('No aparece "login:"')
    c.buf = ''
    c.escribir(usuario)
    c.esperar(r'[Pp]assword: *$|[Cc]ontraseña: *$', 30)
    c.buf = ''
    c.escribir(clave)
    m = c.esperar(r'\$ *$|[Cc]urrent password: *$|[Cc]ontraseña actual: *$|incorrect|incorrecto', 60)
    if m and re.search(r'[Cc]urrent|actual', m.group(0)):
        if not nueva:
            sys.exit('El sistema pide cambiar la contraseña y no se ha dado CONTRASEÑA_NUEVA')
        c.buf = ''
        c.escribir(clave)
        c.esperar(r'[Nn]ew password: *$|[Nn]ueva contraseña: *$', 30)
        c.buf = ''
        c.escribir(nueva)
        c.esperar(r'[Rr]etype|[Vv]uelva|[Rr]epeat', 30)
        c.buf = ''
        c.escribir(nueva)
        m = c.esperar(r'\$ *$|BAD PASSWORD|[Ee]rror', 60)
        print('Contraseña cambiada en el primer acceso (chage -d 0)')
    if not m or not m.group(0).strip().endswith('$'):
        sys.exit('No se ha podido entrar: ' + ANSI.sub('', c.buf)[-300:])
    c.escribir('export TERM=dumb PS1="\\u@\\h:\\w\\$ "; unset PROMPT_COMMAND; stty cols 200 -echoctl')
    c.leer(2)
    print(f'Sesión iniciada como {usuario}')


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        sys.exit(__doc__)
    c = Consola(a[0])
    c.leer(0.5)
    if a[1] == 'entrar':
        entrar(c, a[2], a[3], a[4] if len(a) > 4 else None)
    elif a[1] == 'orden':
        rc, salida = c.orden(a[3], float(a[2]))
        print(salida)
        sys.exit(255 if rc is None else rc)
    elif a[1] == 'transcribir':
        partes = []
        for o in a[4:]:
            rc, salida = c.orden(o, float(a[3]))
            partes.append(f'$ {o}\n{salida}' if salida else f'$ {o}')
            if rc is None:
                partes.append('(sin terminar en el tiempo máximo)')
        open(a[2], 'w').write('\n'.join(partes) + '\n')
        print(open(a[2]).read())
    elif a[1] == 'escribir':
        c.escribir(a[2])
        c.leer(2)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
