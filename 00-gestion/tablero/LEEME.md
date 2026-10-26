# Tablero Almi-Chain

Tablero tipo Trello para el Reto 1 de ASIR1. Funciona sin instalar nada ni conexión a Internet.

## Cómo abrirlo

Descomprime la carpeta y abre `index.html` con Chrome, Firefox o Edge.

## Qué trae

- Las 90 tareas del reto, **sin responsable**: os las repartís vosotros.
- Cada tarea indica el **apartado de la guía** («Guía 2.4») del documento «Guías paso a paso» donde se explica cómo hacerla.
- Arriba: progreso total, las 4 semanas (la actual marcada), los 8 bloques con su progreso y el equipo.
- Dos vistas: **Por estado** (Por hacer → En curso → En revisión → Hecho) y **Por semanas**.

## Uso diario

1. Arriba, en **Soy**, elige tu nombre. Así cada cambio queda apuntado a tu nombre con fecha y hora.
2. Para quedarte una tarea, pulsa **Me la quedo** en su tarjeta. También puedes elegir el responsable dentro de la tarjeta.
3. Mueve las tarjetas arrastrándolas o con las flechas ‹ › (en móvil, mejor las flechas). Si mueves a «En curso» una tarea sin responsable, pasa a ser tuya.
4. Al pasar una tarea a **Hecho** se guarda **quién la hizo y cuándo**.
5. Pulsa un bloque, una persona o una semana para filtrar. **Quitar filtros** vuelve a mostrar todo.
6. Las tareas que pasan de su fecha de fin sin estar hechas salen como **Retrasada**.

## Compartir el estado entre los 5

Todo se guarda en el navegador de cada ordenador, así que no se sincroniza solo:

- Al terminar la sesión, quien haya hecho cambios pulsa **Exportar** y sube el `.json` al repositorio (`00-gestion/tablero/`).
- Los demás, al empezar, hacen `git pull` y pulsan **Importar** con ese archivo.
- Lo más sencillo: que una persona (el coordinador) lleve el tablero en clase y los demás le digan los cambios.

**Importar** sustituye el tablero actual. Antes guarda una copia del anterior en el navegador.

## Archivos

- `Guias-paso-a-paso-Reto1-Almi-Chain.docx`: la documentación con las guías paso a paso de cada apartado (se abre con Word o LibreOffice).
- `index.html`: estructura de la página.
- `css/estilos.css`: diseño. Al principio están los colores de cada bloque (`--b-…`) y de cada persona (`--p-…`).
- `js/tareas.js`: las tareas iniciales. Se usan la primera vez o al pulsar **Restablecer**.
- `js/app.js`: lógica del tablero (asignar, mover, editar, guardar, exportar e importar).
