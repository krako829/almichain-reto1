/*
 * Arcade stick con Arduino - Reto 1 Almi-Chain
 *
 * Placa: Arduino Leonardo / Micro / Pro Micro (ATmega32U4, USB nativo)
 * Libreria: "Joystick" de Matthew Heironimus (ArduinoJoystickLibrary)
 *   Instalar: Programa > Incluir Libreria > Anadir biblioteca .ZIP
 *   con https://github.com/MHeironimus/ArduinoJoystickLibrary/archive/master.zip
 *
 * El Arduino se presenta al PC como un gamepad HID estandar:
 * Windows, Linux y cualquier emulador (MAME, RetroArch...) lo detectan
 * sin drivers, y el mapeo se puede cambiar en el propio emulador.
 *
 * Personalizacion a nivel de firmware (sin recompilar):
 * por el puerto serie (115200 baud) se puede cambiar que boton del
 * sistema genera cada boton fisico y guardarlo en la EEPROM.
 *
 *   SHOW               muestra el mapeo actual
 *   MAP <entrada> <b>  la entrada fisica (1-4) pasa a ser el boton b (1-4)
 *   SAVE               guarda el mapeo en EEPROM
 *   RESET              vuelve al mapeo por defecto (luego SAVE para fijarlo)
 *
 * Cableado: cada pulsador entre su pin y GND (se usa INPUT_PULLUP,
 * no hacen falta resistencias externas).
 */

#include <Joystick.h>
#include <EEPROM.h>

// ---------------- Configuracion ----------------
// 0 = palanca como ejes X/Y (lo mas habitual en MAME)
// 1 = palanca como cruceta (hat switch / D-pad)
#define DIRECTIONS_AS_HAT 0

const uint16_t DEBOUNCE_MS = 5;      // antirrebote
const uint32_t SERIAL_BAUD = 115200;

// ---------------- Pines ----------------
const uint8_t NUM_DIR = 4;   // arriba, abajo, izquierda, derecha
const uint8_t NUM_BTN = 4;   // 4 botones de accion
const uint8_t NUM_IN  = NUM_DIR + NUM_BTN;

enum { DIR_UP = 0, DIR_DOWN, DIR_LEFT, DIR_RIGHT };

// Entradas 0-3: direcciones. Entradas 4-7: botones 1-4.
// Para anadir botones: sube NUM_BTN y anade sus pines aqui al final.
const uint8_t IN_PINS[NUM_IN] = {
  2, 3, 4, 5,   // UP, DOWN, LEFT, RIGHT
  6, 7, 8, 9    // botones 1-4
};

// ---------------- Objeto mando ----------------
#if DIRECTIONS_AS_HAT
Joystick_ Joystick(JOYSTICK_DEFAULT_REPORT_ID, JOYSTICK_TYPE_GAMEPAD,
                   NUM_BTN, 1,
                   false, false, false, false, false, false,
                   false, false, false, false, false);
#else
Joystick_ Joystick(JOYSTICK_DEFAULT_REPORT_ID, JOYSTICK_TYPE_GAMEPAD,
                   NUM_BTN, 0,
                   true, true, false, false, false, false,
                   false, false, false, false, false);
#endif

// ---------------- Estado ----------------
bool stable[NUM_IN];        // estado ya filtrado (true = pulsado)
bool lastRaw[NUM_IN];
uint32_t changedAt[NUM_IN];
uint8_t btnMap[NUM_BTN];    // entrada fisica i -> boton del sistema btnMap[i]

const int EE_ADDR = 0;
const uint8_t EE_MAGIC = 0xA5;

// ---------------- Mapeo (EEPROM) ----------------
void resetMap() {
  for (uint8_t i = 0; i < NUM_BTN; i++) btnMap[i] = i;
}

void saveMap() {
  EEPROM.update(EE_ADDR, EE_MAGIC);
  for (uint8_t i = 0; i < NUM_BTN; i++) EEPROM.update(EE_ADDR + 1 + i, btnMap[i]);
}

void loadMap() {
  resetMap();
  if (EEPROM.read(EE_ADDR) != EE_MAGIC) return;
  uint8_t tmp[NUM_BTN];
  for (uint8_t i = 0; i < NUM_BTN; i++) {
    tmp[i] = EEPROM.read(EE_ADDR + 1 + i);
    if (tmp[i] >= NUM_BTN) return;   // datos corruptos: se queda el defecto
  }
  for (uint8_t i = 0; i < NUM_BTN; i++) btnMap[i] = tmp[i];
}

// ---------------- Lectura con antirrebote ----------------
void readInputs() {
  uint32_t now = millis();
  for (uint8_t i = 0; i < NUM_IN; i++) {
    bool raw = (digitalRead(IN_PINS[i]) == LOW);
    if (raw != lastRaw[i]) {
      lastRaw[i] = raw;
      changedAt[i] = now;
    } else if (raw != stable[i] && (now - changedAt[i]) >= DEBOUNCE_MS) {
      stable[i] = raw;
    }
  }
}

// ---------------- Envio al PC ----------------
void sendDirections() {
  bool up    = stable[DIR_UP];
  bool down  = stable[DIR_DOWN];
  bool left  = stable[DIR_LEFT];
  bool right = stable[DIR_RIGHT];

  // Direcciones opuestas a la vez se anulan
  if (up && down)    { up = false; down = false; }
  if (left && right) { left = false; right = false; }

#if DIRECTIONS_AS_HAT
  int16_t angle = -1;   // -1 = centro
  if (up && right)        angle = 45;
  else if (down && right) angle = 135;
  else if (down && left)  angle = 225;
  else if (up && left)    angle = 315;
  else if (up)            angle = 0;
  else if (right)         angle = 90;
  else if (down)          angle = 180;
  else if (left)          angle = 270;
  Joystick.setHatSwitch(0, angle);
#else
  Joystick.setXAxis((int)right - (int)left);
  Joystick.setYAxis((int)down - (int)up);   // Y positivo = abajo en HID
#endif
}

void sendButtons() {
  bool out[NUM_BTN];
  for (uint8_t o = 0; o < NUM_BTN; o++) out[o] = false;
  for (uint8_t i = 0; i < NUM_BTN; i++) {
    if (stable[NUM_DIR + i]) out[btnMap[i]] = true;
  }
  for (uint8_t o = 0; o < NUM_BTN; o++) Joystick.setButton(o, out[o]);
}

// ---------------- Configuracion por serie ----------------
void showMap() {
  Serial.println(F("Entrada fisica -> boton del sistema"));
  for (uint8_t i = 0; i < NUM_BTN; i++) {
    Serial.print(F("  ")); Serial.print(i + 1);
    Serial.print(F(" -> ")); Serial.println(btnMap[i] + 1);
  }
}

void handleCommand(const char *cmd) {
  int a, b;
  if (!strcmp(cmd, "SHOW")) {
    showMap();
  } else if (!strcmp(cmd, "SAVE")) {
    saveMap();
    Serial.println(F("OK guardado"));
  } else if (!strcmp(cmd, "RESET")) {
    resetMap();
    Serial.println(F("OK mapeo por defecto (usa SAVE para guardarlo)"));
  } else if (sscanf(cmd, "MAP %d %d", &a, &b) == 2 &&
             a >= 1 && a <= NUM_BTN && b >= 1 && b <= NUM_BTN) {
    btnMap[a - 1] = b - 1;
    Serial.println(F("OK (usa SAVE para guardarlo)"));
  } else {
    Serial.println(F("Comandos: SHOW | MAP <entrada> <boton> | SAVE | RESET"));
  }
}

void handleSerial() {
  static char line[32];
  static uint8_t len = 0;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\r' || c == '\n') {
      if (len > 0) {
        line[len] = '\0';
        handleCommand(line);
        len = 0;
      }
    } else if (len < sizeof(line) - 1) {
      line[len++] = toupper(c);
    }
  }
}

// ---------------- Arduino ----------------
void setup() {
  for (uint8_t i = 0; i < NUM_IN; i++) {
    pinMode(IN_PINS[i], INPUT_PULLUP);
    stable[i] = false;
    lastRaw[i] = false;
    changedAt[i] = 0;
  }
  loadMap();
  Serial.begin(SERIAL_BAUD);
#if !DIRECTIONS_AS_HAT
  Joystick.setXAxisRange(-1, 1);
  Joystick.setYAxisRange(-1, 1);
#endif
  Joystick.begin(false);   // false = enviamos el estado a mano
}

void loop() {
  readInputs();
  sendDirections();
  sendButtons();
  Joystick.sendState();
  handleSerial();
}
