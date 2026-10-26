// Prueba de cableado: muestra en el Monitor Serie lo que se pulsa
const uint8_t PINES[] = {2, 3, 4, 5, 6, 7, 8, 9, 10, A0, A1, A2, A3};
const char* NOMBRES[] = {"Arriba", "Abajo", "Izquierda", "Derecha",
  "Boton 1", "Boton 2", "Boton 3", "Boton 4", "Boton 5", "Boton 6",
  "Moneda", "Start", "Menu"};
const uint8_t N = sizeof(PINES);

void setup() {
  Serial.begin(9600);
  for (uint8_t i = 0; i < N; i++) {
    pinMode(PINES[i], INPUT_PULLUP); // pulsado = LOW
  }
}

void loop() {
  for (uint8_t i = 0; i < N; i++) {
    if (digitalRead(PINES[i]) == LOW) {
      Serial.println(NOMBRES[i]);
    }
  }
  delay(150);
}
