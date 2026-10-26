// Arcade stick Almi-Chain - camino B: teclado USB con las teclas por defecto de MAME
#include <Keyboard.h>

const uint8_t PINES[] = {2, 3, 4, 5, 6, 7, 8, 9, 10, A0, A1, A2, A3};
const uint8_t TECLAS[] = {KEY_UP_ARROW, KEY_DOWN_ARROW, KEY_LEFT_ARROW, KEY_RIGHT_ARROW,
  KEY_LEFT_CTRL, KEY_LEFT_ALT, ' ', KEY_LEFT_SHIFT, 'z', 'x',
  '5', '1', KEY_TAB};
const uint8_t N = sizeof(PINES);
bool pulsado[N];
bool activo = true;

void setup() {
  for (uint8_t i = 0; i < N; i++) {
    pinMode(PINES[i], INPUT_PULLUP);
    pulsado[i] = false;
  }
  delay(500);
  // Modo seguro: si se conecta con el boton Menu (A3) pulsado, no envia teclas.
  // Sirve para poder volver a programar la placa sin que "escriba" sola.
  if (digitalRead(A3) == LOW) { activo = false; return; }
  Keyboard.begin();
}

void loop() {
  if (!activo) return;
  for (uint8_t i = 0; i < N; i++) {
    bool ahora = (digitalRead(PINES[i]) == LOW);
    if (ahora != pulsado[i]) {
      if (ahora) Keyboard.press(TECLAS[i]);
      else Keyboard.release(TECLAS[i]);
      pulsado[i] = ahora;
    }
  }
  delay(5); // antirrebote sencillo
}
