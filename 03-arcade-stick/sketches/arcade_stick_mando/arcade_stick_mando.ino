// Arcade stick Almi-Chain - camino A: mando USB (gamepad)
#include <Joystick.h>

const uint8_t PIN_ARRIBA = 2, PIN_ABAJO = 3, PIN_IZQ = 4, PIN_DER = 5;
// Boton 1..6, Moneda, Start, Menu
const uint8_t PINES_BOTONES[] = {6, 7, 8, 9, 10, A0, A1, A2, A3};
const uint8_t NUM_BOTONES = sizeof(PINES_BOTONES);

// Mando con 9 botones, sin cruceta "hat", con ejes X e Y y nada mas
Joystick_ mando(JOYSTICK_DEFAULT_REPORT_ID, JOYSTICK_TYPE_GAMEPAD,
    NUM_BOTONES, 0,
    true, true, // X, Y
    false, false, false, false, // Z, Rx, Ry, Rz
    false, false, false, false, false); // timon, acelerador...

int ultimoX = 0, ultimoY = 0;
uint8_t ultimos[NUM_BOTONES];

void setup() {
  pinMode(PIN_ARRIBA, INPUT_PULLUP);
  pinMode(PIN_ABAJO, INPUT_PULLUP);
  pinMode(PIN_IZQ, INPUT_PULLUP);
  pinMode(PIN_DER, INPUT_PULLUP);
  for (uint8_t i = 0; i < NUM_BOTONES; i++) {
    pinMode(PINES_BOTONES[i], INPUT_PULLUP);
    ultimos[i] = 0;
  }
  mando.setXAxisRange(-1, 1);
  mando.setYAxisRange(-1, 1);
  mando.begin(false); // enviamos nosotros con sendState()
  mando.setXAxis(0);
  mando.setYAxis(0);
  mando.sendState();
}

void loop() {
  bool cambio = false;

  int x = 0, y = 0;
  if (digitalRead(PIN_IZQ) == LOW) x = -1;
  if (digitalRead(PIN_DER) == LOW) x = 1;
  if (digitalRead(PIN_ARRIBA) == LOW) y = -1;
  if (digitalRead(PIN_ABAJO) == LOW) y = 1;
  if (x != ultimoX) { mando.setXAxis(x); ultimoX = x; cambio = true; }
  if (y != ultimoY) { mando.setYAxis(y); ultimoY = y; cambio = true; }

  for (uint8_t i = 0; i < NUM_BOTONES; i++) {
    uint8_t v = (digitalRead(PINES_BOTONES[i]) == LOW) ? 1 : 0;
    if (v != ultimos[i]) { mando.setButton(i, v); ultimos[i] = v; cambio = true; }
  }

  if (cambio) mando.sendState();
  delay(5); // antirrebote sencillo
}
