/* ==========================================================
   Tablero Almi-Chain · lógica
   - Las tareas empiezan sin responsable: os las repartís vosotros.
   - Todo se guarda en el navegador (localStorage).
   - Exportar/Importar en .json para compartir el estado por Git.
   - Cada cambio queda en el historial: quién y cuándo.
   ========================================================== */
(function () {
  "use strict";

  const CLAVE = "almichain-tablero-v3";
  const CLAVE_SOY = "almichain-soy";
  const CLAVE_VISTA = "almichain-vista";

  const ESTADOS = [
    { id: "todo",     nombre: "Por hacer",   sub: "Pendientes" },
    { id: "curso",    nombre: "En curso",    sub: "Alguien está en ello" },
    { id: "revision", nombre: "En revisión", sub: "Otro lo comprueba" },
    { id: "hecho",    nombre: "Hecho",       sub: "Con su prueba" },
  ];
  const NOMBRE_ESTADO = Object.fromEntries(ESTADOS.map(e => [e.id, e.nombre]));

  const SEMANAS = [
    { n: 1, desde: "2026-10-16", hasta: "2026-10-23", fechas: "16 – 23 oct", objetivo: "Análisis y diseño" },
    { n: 2, desde: "2026-10-24", hasta: "2026-10-30", fechas: "26 – 30 oct", objetivo: "Instalaciones base" },
    { n: 3, desde: "2026-10-31", hasta: "2026-11-06", fechas: "2 – 6 nov",   objetivo: "Integración y seguridad" },
    { n: 4, desde: "2026-11-07", hasta: "2026-11-13", fechas: "9 – 13 nov",  objetivo: "Pruebas y entrega" },
  ];

  // Iconos de cada bloque (trazos SVG de 24x24)
  const ICONOS = {
    GES: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 3h6v3H9z"/><path d="M9 11h6M9 15h4"/>',
    PUE: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
    ARC: '<rect x="2" y="7" width="20" height="11" rx="5.5"/><path d="M6.5 12.5h4M8.5 10.5v4"/><circle cx="15.5" cy="13.5" r="1"/><circle cx="18" cy="11" r="1"/>',
    STK: '<circle cx="12" cy="6" r="3"/><path d="M12 9v7"/><rect x="4" y="16" width="16" height="5" rx="2"/>',
    RED: '<path d="M2 9a15 15 0 0 1 20 0"/><path d="M5 12.5a10 10 0 0 1 14 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/><circle cx="12" cy="19.5" r="1"/>',
    ERP: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/>',
    WEB: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
    BD:  '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5"/><path d="M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"/>',
  };
  const icono = b => `<svg viewBox="0 0 24 24" aria-hidden="true">${ICONOS[b] || ICONOS.GES}</svg>`;
  const colorBloque = b => `var(--b-${b})`;
  const colorPersona = p => p ? `var(--p-${p.toLowerCase()})` : "transparent";
  const colorEstado = e => `var(--e-${e})`;

  const $ = s => document.querySelector(s);
  const esc = t => String(t ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const hoyISO = () => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  };
  const fechaCorta = iso => iso ? new Date(iso.length === 10 ? iso + "T12:00:00" : iso).toLocaleDateString("es-ES", { day: "numeric", month: "short" }) : "";
  const fechaHora = iso => new Date(iso).toLocaleString("es-ES", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
  const semanaDe = inicio => { const s = SEMANAS.find(x => inicio && inicio <= x.hasta); return inicio ? (s ? s.n : 4) : null; };
  const semanaActual = () => { const h = hoyISO(); const s = SEMANAS.find(x => h >= x.desde && h <= x.hasta); return s ? s.n : null; };

  /* ---------- Estado ---------- */
  let estado = cargar();
  let soy = leerLS(CLAVE_SOY) || "";
  let vista = leerLS(CLAVE_VISTA) || "estado";
  const filtro = { persona: "", bloque: "", semana: "" };
  let editando = null;
  let arrastrando = null;

  function leerLS(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function escribirLS(k, v) { try { localStorage.setItem(k, v); return true; } catch (e) { return false; } }

  function desdeIniciales() {
    const base = JSON.parse(JSON.stringify(window.TAREAS_INICIALES));
    return {
      version: 2,
      personas: base.personas,
      bloques: base.bloques,
      tareas: base.tareas.map(t => Object.assign({ estado: "todo", hechaPor: "", fechaHecho: "", notas: "", historial: [] }, t)),
      actividad: [],
    };
  }
  function cargar() {
    const raw = leerLS(CLAVE);
    if (raw) { try { const d = JSON.parse(raw); if (d && Array.isArray(d.tareas)) return d; } catch (e) { /* dañado */ } }
    return desdeIniciales();
  }
  function guardar() {
    if (!escribirLS(CLAVE, JSON.stringify(estado))) avisar("No se pudo guardar en este navegador. Usa «Exportar» para no perder cambios.");
  }
  function registrar(tarea, accion) {
    const e = { fecha: new Date().toISOString(), quien: soy || "Sin identificar", accion };
    if (tarea) { tarea.historial = tarea.historial || []; tarea.historial.unshift(e); }
    estado.actividad.unshift(Object.assign({ id: tarea ? tarea.id : "", titulo: tarea ? tarea.titulo : "" }, e));
    estado.actividad = estado.actividad.slice(0, 300);
  }

  /* ---------- Avisos ---------- */
  let temporizador;
  function avisar(texto) {
    const a = $("#aviso");
    a.textContent = texto; a.hidden = false;
    clearTimeout(temporizador);
    temporizador = setTimeout(() => { a.hidden = true; }, 3400);
  }
  function exigirIdentidad() {
    if (soy) return true;
    const caja = $(".soy");
    caja.classList.add("falta"); $("#soy").focus();
    avisar("Elige primero quién eres en «Soy» para apuntar el cambio a tu nombre.");
    setTimeout(() => caja.classList.remove("falta"), 2500);
    return false;
  }

  /* ---------- Controles ---------- */
  function opciones(select, lista, vacio) {
    select.innerHTML = "";
    if (vacio !== undefined) select.add(new Option(vacio, ""));
    lista.forEach(o => select.add(typeof o === "string" ? new Option(o, o) : new Option(o.nombre, o.id)));
  }
  function prepararControles() {
    opciones($("#soy"), estado.personas, "— elige tu nombre —");
    $("#soy").value = soy;
    opciones($("#t-bloque"), estado.bloques);
    opciones($("#t-estado"), ESTADOS);
    opciones($("#t-responsable"), estado.personas.concat(["Todos"]), "Sin asignar");
    opciones($("#t-hecha"), estado.personas, "—");
    const colabs = $("#t-colaboradores");
    colabs.innerHTML = "";
    estado.personas.forEach(p => {
      const id = "colab-" + p.toLowerCase();
      const l = document.createElement("label");
      l.htmlFor = id;
      l.innerHTML = `<input type="checkbox" id="${id}" value="${esc(p)}"> ${esc(p)}`;
      colabs.appendChild(l);
    });
    $("#f-semana").value = filtro.semana;
    marcarVista();
  }

  /* ---------- Filtros ---------- */
  const retrasada = t => t.estado !== "hecho" && t.fin && t.fin < hoyISO();
  function pasaFiltro(t) {
    if (filtro.persona === "__libres" && t.responsable) return false;
    if (filtro.persona && filtro.persona !== "__libres" && t.responsable !== filtro.persona && !(t.colaboradores || []).includes(filtro.persona)) return false;
    if (filtro.bloque && t.bloque !== filtro.bloque) return false;
    if (filtro.semana && String(t.semana) !== filtro.semana) return false;
    if ($("#f-libres").checked && t.responsable) return false;
    if ($("#f-retrasadas").checked && !retrasada(t)) return false;
    const q = $("#f-texto").value.trim().toLowerCase();
    if (q && !(`${t.id} ${t.titulo} ${t.descripcion} ${t.notas} guía ${t.guia}`.toLowerCase().includes(q))) return false;
    return true;
  }
  function textoFiltro() {
    const partes = [];
    if (filtro.bloque) { const b = estado.bloques.find(x => x.id === filtro.bloque); partes.push(`bloque <b>${esc(b ? b.nombre : filtro.bloque)}</b>`); }
    if (filtro.persona === "__libres") partes.push("tareas <b>sin asignar</b>");
    else if (filtro.persona) partes.push(`persona <b>${esc(filtro.persona)}</b>`);
    if (filtro.semana) partes.push(`semana <b>S${filtro.semana}</b>`);
    const el = $("#filtro-activo");
    el.hidden = !partes.length;
    el.innerHTML = partes.length ? `Mostrando: ${partes.join(" · ")}` : "";
  }

  /* ---------- Pintar ---------- */
  function pintar() { pintarResumen(); pintarBloques(); pintarEquipo(); pintarTablero(); pintarActividad(); textoFiltro(); }

  function pintarResumen() {
    const ts = estado.tareas;
    const total = ts.length;
    const hechas = ts.filter(t => t.estado === "hecho").length;
    const curso = ts.filter(t => t.estado === "curso" || t.estado === "revision").length;
    const libres = ts.filter(t => !t.responsable).length;
    const tarde = ts.filter(retrasada).length;
    const pct = total ? Math.round(hechas / total * 100) : 0;
    const R = 46, C = 2 * Math.PI * R;
    $("#total").innerHTML = `
      <svg class="anillo" viewBox="0 0 116 116" role="img" aria-label="${pct}% del reto hecho">
        <circle class="fondo" cx="58" cy="58" r="${R}" fill="none" stroke-width="12"/>
        <circle class="valor" cx="58" cy="58" r="${R}" fill="none" stroke-width="12" stroke-linecap="round"
          stroke-dasharray="${(C * pct / 100).toFixed(1)} ${C.toFixed(1)}" transform="rotate(-90 58 58)"/>
        <text x="58" y="60" text-anchor="middle" font-size="24" font-weight="800">${pct}%</text>
        <text x="58" y="78" text-anchor="middle" font-size="10.5" opacity=".7">hecho</text>
      </svg>
      <div class="cifras">
        <div class="cifra"><span class="punto" style="--c:var(--e-hecho)"></span><b>${hechas}</b> de ${total} hechas</div>
        <div class="cifra"><span class="punto" style="--c:var(--e-curso)"></span><b>${curso}</b> en curso o revisión</div>
        <div class="cifra"><span class="punto" style="--c:var(--aviso)"></span><b>${libres}</b> sin asignar</div>
        <div class="cifra"><span class="punto" style="--c:var(--peligro)"></span><b>${tarde}</b> retrasadas</div>
      </div>`;

    const actual = semanaActual();
    const cont = $("#semanas");
    cont.innerHTML = "";
    SEMANAS.forEach(s => {
      const deS = ts.filter(t => t.semana === s.n);
      const n = deS.length || 1;
      const parte = e => (deS.filter(t => t.estado === e).length / n * 100).toFixed(1);
      const b = document.createElement("button");
      b.type = "button";
      b.className = "semana" + (s.n === actual ? " actual" : "") + (filtro.semana === String(s.n) ? " elegida" : "");
      b.title = filtro.semana === String(s.n) ? "Quitar filtro de semana" : "Ver solo esta semana";
      b.innerHTML = `
        <span class="s-cab"><b>S${s.n}</b><span class="fechas">${s.fechas}</span></span>
        ${s.n === actual ? '<span class="ahora">Semana actual</span>' : ""}
        <span class="objetivo">${s.objetivo} · ${deS.filter(t => t.estado === "hecho").length}/${deS.length}</span>
        <span class="barrita" aria-hidden="true">
          <span style="width:${parte("hecho")}%;background:var(--e-hecho)"></span>
          <span style="width:${parte("revision")}%;background:var(--e-revision)"></span>
          <span style="width:${parte("curso")}%;background:var(--e-curso)"></span>
        </span>`;
      b.addEventListener("click", () => {
        filtro.semana = filtro.semana === String(s.n) ? "" : String(s.n);
        $("#f-semana").value = filtro.semana;
        pintar();
      });
      cont.appendChild(b);
    });
  }

  function pintarBloques() {
    const cont = $("#bloques");
    cont.innerHTML = "";
    estado.bloques.forEach(b => {
      const ts = estado.tareas.filter(t => t.bloque === b.id);
      const hechas = ts.filter(t => t.estado === "hecho").length;
      const libres = ts.filter(t => !t.responsable).length;
      const gente = [...new Set(ts.map(t => t.responsable).filter(Boolean))];
      const pct = ts.length ? Math.round(hechas / ts.length * 100) : 0;
      const el = document.createElement("button");
      el.type = "button";
      el.className = "bloque" + (filtro.bloque === b.id ? " activo" : "");
      el.style.setProperty("--c", colorBloque(b.id));
      el.innerHTML = `
        <span class="icono">${icono(b.id)}</span>
        <span class="nombre">${esc(b.nombre)}</span>
        <span class="meta"><span>Guía ${esc(b.guia || "")}</span><span class="num">${hechas}/${ts.length}</span>
          ${libres ? `<span class="libres">${libres} sin asignar</span>` : `<span>${gente.map(esc).join(", ") || "—"}</span>`}</span>
        <span class="barrita"><span style="width:${pct}%;background:var(--c)"></span></span>`;
      el.addEventListener("click", () => { filtro.bloque = filtro.bloque === b.id ? "" : b.id; pintar(); });
      cont.appendChild(el);
    });
  }

  function pintarEquipo() {
    const cont = $("#equipo");
    cont.innerHTML = "";
    const tarjetaPersona = (clave, nombre, ts, vacio) => {
      const hechas = ts.filter(t => t.estado === "hecho").length;
      const curso = ts.filter(t => t.estado === "curso" || t.estado === "revision").length;
      const el = document.createElement("button");
      el.type = "button";
      el.className = "persona" + (vacio ? " sin" : "") + (filtro.persona === clave ? " activa" : "");
      el.style.setProperty("--c", vacio ? "var(--aviso)" : colorPersona(clave));
      el.innerHTML = `
        <span class="avatar${vacio ? " vacio" : ""}">${vacio ? "?" : esc(nombre[0])}</span>
        <span class="info"><span class="nombre">${esc(nombre)}</span>
          <span class="detalle">${vacio ? `${ts.length} tareas por repartir` : `${ts.length} tareas · ${hechas} hechas · ${curso} en marcha`}</span>
          ${vacio ? "" : `<span class="barrita"><span style="width:${ts.length ? hechas / ts.length * 100 : 0}%;background:var(--c)"></span></span>`}
        </span>`;
      el.addEventListener("click", () => { filtro.persona = filtro.persona === clave ? "" : clave; pintar(); });
      cont.appendChild(el);
    };
    estado.personas.forEach(p => tarjetaPersona(p, p, estado.tareas.filter(t => t.responsable === p || (t.colaboradores || []).includes(p)), false));
    tarjetaPersona("__libres", "Sin asignar", estado.tareas.filter(t => !t.responsable), true);
  }

  function pintarTablero() {
    const tablero = $("#tablero");
    tablero.innerHTML = "";
    const grupos = vista === "semanas"
      ? SEMANAS.map(s => ({ id: s.n, nombre: `Semana ${s.n}`, sub: `${s.fechas} · ${s.objetivo}`, color: "var(--focus)", filtro: t => t.semana === s.n, soltable: false }))
      : ESTADOS.map(e => ({ id: e.id, nombre: e.nombre, sub: e.sub, color: colorEstado(e.id), filtro: t => t.estado === e.id, soltable: true }));

    grupos.forEach(g => {
      const tareas = estado.tareas.filter(t => g.filtro(t) && pasaFiltro(t))
        .sort((a, b) => (a.inicio || "").localeCompare(b.inicio || "") || a.id.localeCompare(b.id));
      const col = document.createElement("section");
      col.className = "columna";
      col.style.setProperty("--e", g.color);
      col.innerHTML = `<header><div><h2>${g.nombre}</h2><div class="sub">${g.sub}</div></div><span class="n">${tareas.length}</span></header>`;
      const lista = document.createElement("div");
      lista.className = "lista";
      if (!tareas.length) lista.innerHTML = `<div class="vacia">${g.soltable ? "Arrastra aquí una tarea" : "Nada con estos filtros"}</div>`;
      tareas.forEach(t => lista.appendChild(tarjeta(t)));
      col.appendChild(lista);
      if (g.soltable) {
        col.addEventListener("dragover", ev => { ev.preventDefault(); col.classList.add("sobre"); });
        col.addEventListener("dragleave", ev => { if (!col.contains(ev.relatedTarget)) col.classList.remove("sobre"); });
        col.addEventListener("drop", ev => {
          ev.preventDefault(); col.classList.remove("sobre");
          const id = ev.dataTransfer.getData("text/plain") || arrastrando;
          if (id) mover(id, g.id);
        });
      }
      tablero.appendChild(col);
    });
  }

  function tarjeta(t) {
    const i = ESTADOS.findIndex(e => e.id === t.estado);
    const el = document.createElement("article");
    el.className = "tarjeta";
    el.draggable = vista === "estado";
    el.tabIndex = 0;
    el.style.setProperty("--c", colorBloque(t.bloque));
    const bloque = estado.bloques.find(b => b.id === t.bloque);
    const rango = t.inicio && t.fin && t.inicio !== t.fin ? `${fechaCorta(t.inicio)} → ${fechaCorta(t.fin)}` : fechaCorta(t.fin || t.inicio);
    const ayudan = (t.colaboradores || []).filter(c => c !== t.responsable);
    const persona = t.responsable
      ? `<span class="gente">${[t.responsable].concat(ayudan).map(p => `<span class="avatar peq" style="--c:${colorPersona(p)}" title="${esc(p)}">${p === "Todos" ? "★" : esc(p[0])}</span>`).join("")}</span><span>${esc(t.responsable === "Todos" ? "Todo el equipo" : t.responsable)}</span>`
      : `<span class="avatar peq vacio" title="Sin asignar">?</span>${soy ? `<button type="button" class="coger">Me la quedo</button>` : `<span class="sin-asignar">Sin asignar</span>`}`;
    el.innerHTML = `
      <div class="franja">${icono(t.bloque)}<span>${esc(bloque ? bloque.nombre : t.bloque)}</span><span class="id">${esc(t.id)}</span></div>
      <div class="cuerpo">
        <div class="titulo"></div>
        <div class="chips">
          ${t.guia ? `<span class="chip guia">Guía ${esc(t.guia)}</span>` : ""}
          ${vista === "semanas" ? `<span class="chip estado" style="--e:${colorEstado(t.estado)}">${NOMBRE_ESTADO[t.estado]}</span>` : `<span class="chip">S${t.semana || "?"}</span>`}
          <span class="chip num">${rango}</span>
          ${t.hito ? `<span class="chip hito">Hito</span>` : ""}
          ${retrasada(t) ? `<span class="chip retraso">Retrasada</span>` : ""}
        </div>
        <div class="pie">${persona}
          ${vista === "estado" ? `<span class="mover">
            <button type="button" data-dir="-1" aria-label="Mover a la columna anterior" ${i === 0 ? "disabled" : ""}>‹</button>
            <button type="button" data-dir="1" aria-label="Mover a la columna siguiente" ${i === ESTADOS.length - 1 ? "disabled" : ""}>›</button>
          </span>` : ""}
        </div>
        ${t.estado === "hecho" && t.hechaPor ? `<div class="hecha">✔ Hecha por ${esc(t.hechaPor)}${t.fechaHecho ? " · " + fechaCorta(t.fechaHecho) : ""}</div>` : ""}
      </div>`;
    el.querySelector(".titulo").textContent = t.titulo;

    el.addEventListener("dragstart", ev => { arrastrando = t.id; ev.dataTransfer.setData("text/plain", t.id); ev.dataTransfer.effectAllowed = "move"; el.classList.add("arrastrando"); });
    el.addEventListener("dragend", () => { arrastrando = null; el.classList.remove("arrastrando"); });
    el.addEventListener("click", ev => {
      if (ev.target.closest(".coger")) { ev.stopPropagation(); quedarme(t.id); return; }
      const b = ev.target.closest("button[data-dir]");
      if (b) { ev.stopPropagation(); const d = ESTADOS[i + Number(b.dataset.dir)]; if (d) mover(t.id, d.id); return; }
      abrir(t.id);
    });
    el.addEventListener("keydown", ev => { if (ev.key === "Enter" && ev.target === el) abrir(t.id); });
    return el;
  }

  function pintarActividad() {
    const ol = $("#actividad");
    ol.innerHTML = "";
    const ultimas = estado.actividad.slice(0, 25);
    if (!ultimas.length) { ol.innerHTML = `<li class="vacia">Aún no hay cambios. Cuando alguien se quede, mueva o edite una tarea, aparecerá aquí con su nombre y la hora.</li>`; return; }
    ultimas.forEach(a => {
      const li = document.createElement("li");
      li.innerHTML = `<time datetime="${a.fecha}">${fechaHora(a.fecha)}</time><span><b></b> <span class="acc"></span></span>`;
      li.querySelector("b").textContent = a.quien;
      li.querySelector(".acc").textContent = `${a.accion}${a.id ? ` · ${a.id} ${a.titulo}` : ""}`;
      ol.appendChild(li);
    });
  }

  /* ---------- Acciones ---------- */
  function quedarme(id) {
    if (!exigirIdentidad()) return;
    const t = estado.tareas.find(x => x.id === id);
    if (!t || t.responsable) return;
    t.responsable = soy;
    registrar(t, "se quedó la tarea");
    guardar(); pintar();
    avisar(`${t.id} asignada a ${soy}.`);
  }

  function mover(id, nuevo) {
    const t = estado.tareas.find(x => x.id === id);
    if (!t || t.estado === nuevo) return;
    if (!exigirIdentidad()) return;
    const antes = t.estado;
    t.estado = nuevo;
    if (!t.responsable && nuevo !== "todo") { t.responsable = soy; registrar(t, "se quedó la tarea"); }
    if (nuevo === "hecho") { t.hechaPor = soy; t.fechaHecho = new Date().toISOString(); }
    else if (antes === "hecho") { t.hechaPor = ""; t.fechaHecho = ""; }
    registrar(t, `movió de «${NOMBRE_ESTADO[antes]}» a «${NOMBRE_ESTADO[nuevo]}»`);
    guardar(); pintar();
    if (nuevo === "hecho") avisar(`${t.id} hecha por ${soy}.`);
  }

  function siguienteId(bloque) {
    const pref = { GES: "G", PUE: "P", ARC: "A", STK: "S", RED: "R", ERP: "E", WEB: "W", BD: "B" }[bloque] || "X";
    const nums = estado.tareas.filter(t => t.id.startsWith(pref)).map(t => parseInt(t.id.slice(1), 10) || 0);
    return pref + String((nums.length ? Math.max(...nums) : 0) + 1).padStart(2, "0");
  }

  function pintarCabeceraModal(bloque) {
    const cab = $("#modal-cab");
    cab.style.setProperty("--c", colorBloque(bloque));
    $("#modal-icono").innerHTML = icono(bloque);
  }

  function abrir(id) {
    editando = id;
    const t = id ? estado.tareas.find(x => x.id === id) : null;
    $("#modal-titulo").textContent = t ? `${t.id} · ${t.titulo}` : "Nueva tarea";
    $("#t-titulo").value = t ? t.titulo : "";
    $("#t-descripcion").value = t ? t.descripcion || "" : "";
    $("#t-bloque").value = t ? t.bloque : (filtro.bloque || estado.bloques[0].id);
    $("#t-guia").value = t ? t.guia || "" : "";
    $("#t-estado").value = t ? t.estado : "todo";
    $("#t-responsable").value = t ? t.responsable || "" : "";
    $("#t-hecha").value = t ? t.hechaPor || "" : "";
    $("#t-inicio").value = t ? t.inicio || "" : hoyISO();
    $("#t-fin").value = t ? t.fin || "" : "";
    $("#t-hito").checked = t ? !!t.hito : false;
    $("#t-notas").value = t ? t.notas || "" : "";
    document.querySelectorAll("#t-colaboradores input").forEach(c => { c.checked = !!(t && (t.colaboradores || []).includes(c.value)); });
    pintarCabeceraModal($("#t-bloque").value);
    const hist = $("#t-historial");
    hist.innerHTML = "";
    if (t && t.historial && t.historial.length) {
      t.historial.forEach(e => {
        const li = document.createElement("li");
        li.innerHTML = `<time datetime="${e.fecha}">${fechaHora(e.fecha)}</time><span><b></b> <span></span></span>`;
        li.querySelector("b").textContent = e.quien;
        li.querySelector("span span").textContent = e.accion;
        hist.appendChild(li);
      });
    } else hist.innerHTML = `<li>Sin cambios todavía.</li>`;
    $(".historial").hidden = !t;
    $("#btn-eliminar").hidden = !t;
    resetEliminar();
    $("#modal").showModal();
    $("#t-titulo").focus();
  }
  function cerrar() { $("#modal").close(); editando = null; }

  function guardarFormulario(ev) {
    ev.preventDefault();
    if (!exigirIdentidad()) return;
    const titulo = $("#t-titulo").value.trim();
    if (!titulo) { $("#t-titulo").focus(); return; }
    const datos = {
      titulo,
      descripcion: $("#t-descripcion").value.trim(),
      bloque: $("#t-bloque").value,
      guia: $("#t-guia").value.trim(),
      estado: $("#t-estado").value,
      responsable: $("#t-responsable").value,
      hechaPor: $("#t-hecha").value,
      inicio: $("#t-inicio").value,
      fin: $("#t-fin").value || $("#t-inicio").value,
      hito: $("#t-hito").checked,
      notas: $("#t-notas").value.trim(),
      colaboradores: [...document.querySelectorAll("#t-colaboradores input:checked")].map(c => c.value).filter(c => c !== $("#t-responsable").value),
    };
    datos.semana = semanaDe(datos.inicio);

    if (editando) {
      const t = estado.tareas.find(x => x.id === editando);
      const cambios = [];
      [["titulo", "título"], ["descripcion", "descripción"], ["bloque", "bloque"], ["guia", "guía"], ["inicio", "inicio"], ["fin", "fin"], ["notas", "notas"]]
        .forEach(([k, n]) => { if ((t[k] || "") !== (datos[k] || "")) cambios.push(n); });
      if ((t.responsable || "") !== datos.responsable) cambios.push(`responsable → ${datos.responsable || "sin asignar"}`);
      if (t.estado !== datos.estado) cambios.push(`estado → ${NOMBRE_ESTADO[datos.estado]}`);
      if (datos.estado === "hecho" && !datos.hechaPor) datos.hechaPor = soy;
      if (datos.estado === "hecho" && t.estado !== "hecho") datos.fechaHecho = new Date().toISOString();
      if (datos.estado !== "hecho") { datos.hechaPor = ""; datos.fechaHecho = ""; }
      if (datos.hechaPor && (t.hechaPor || "") !== datos.hechaPor) cambios.push(`hecha por ${datos.hechaPor}`);
      if (JSON.stringify(t.colaboradores || []) !== JSON.stringify(datos.colaboradores)) cambios.push("le ayudan");
      Object.assign(t, datos);
      if (cambios.length) registrar(t, "editó: " + cambios.join(", "));
    } else {
      const t = Object.assign({ id: siguienteId(datos.bloque), historial: [], fechaHecho: "" }, datos);
      if (t.estado === "hecho") { t.hechaPor = t.hechaPor || soy; t.fechaHecho = new Date().toISOString(); }
      estado.tareas.push(t);
      registrar(t, "creó la tarea");
    }
    guardar(); cerrar(); pintar();
  }

  let eliminarArmado = false;
  function resetEliminar() { eliminarArmado = false; const b = $("#btn-eliminar"); b.textContent = "Eliminar"; b.classList.remove("confirmar"); }
  function eliminar() {
    if (!exigirIdentidad()) return;
    const b = $("#btn-eliminar");
    if (!eliminarArmado) { eliminarArmado = true; b.textContent = "¿Seguro? Pulsa otra vez"; b.classList.add("confirmar"); return; }
    const t = estado.tareas.find(x => x.id === editando);
    estado.tareas = estado.tareas.filter(x => x.id !== editando);
    registrar(null, `eliminó ${t.id} ${t.titulo}`);
    guardar(); cerrar(); pintar();
  }

  let resetArmado = false;
  function restablecer() {
    const b = $("#btn-reset");
    if (!resetArmado) {
      resetArmado = true; b.textContent = "¿Borrar todo? Pulsa otra vez"; b.classList.add("confirmar");
      setTimeout(() => { resetArmado = false; b.textContent = "Restablecer"; b.classList.remove("confirmar"); }, 4000);
      return;
    }
    escribirLS(CLAVE + "-copia", JSON.stringify(estado));
    estado = desdeIniciales();
    registrar(null, "restableció el tablero a las tareas iniciales");
    guardar();
    resetArmado = false; b.textContent = "Restablecer"; b.classList.remove("confirmar");
    prepararControles(); pintar();
    avisar("Tablero restablecido. Se guardó una copia del anterior en el navegador.");
  }

  function exportar() {
    const blob = new Blob([JSON.stringify(estado, null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `tablero-almi-chain-${hoyISO()}.json`;
    document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500);
    avisar("Exportado. Súbelo al repo (00-gestion/tablero) para que lo vea el resto.");
  }
  function importar(archivo) {
    const lector = new FileReader();
    lector.onload = () => {
      try {
        const d = JSON.parse(lector.result);
        if (!d || !Array.isArray(d.tareas) || !Array.isArray(d.personas)) throw new Error("formato");
        escribirLS(CLAVE + "-copia", JSON.stringify(estado));
        d.actividad = d.actividad || [];
        estado = d;
        registrar(null, `importó ${archivo.name}`);
        guardar(); prepararControles(); pintar();
        avisar(`Importadas ${d.tareas.length} tareas desde ${archivo.name}.`);
      } catch (e) { avisar("Ese archivo no es un tablero exportado. Elige un .json creado con «Exportar»."); }
    };
    lector.readAsText(archivo);
  }

  function marcarVista() {
    $("#vista-estado").setAttribute("aria-selected", String(vista === "estado"));
    $("#vista-semanas").setAttribute("aria-selected", String(vista === "semanas"));
  }
  function cambiarVista(v) { vista = v; escribirLS(CLAVE_VISTA, v); marcarVista(); pintarTablero(); }

  /* ---------- Eventos ---------- */
  $("#soy").addEventListener("change", e => { soy = e.target.value; escribirLS(CLAVE_SOY, soy); pintarTablero(); });
  $("#f-semana").addEventListener("change", e => { filtro.semana = e.target.value; pintar(); });
  ["#f-libres", "#f-retrasadas"].forEach(s => $(s).addEventListener("change", pintarTablero));
  $("#f-texto").addEventListener("input", pintarTablero);
  $("#btn-limpiar").addEventListener("click", () => {
    filtro.persona = ""; filtro.bloque = ""; filtro.semana = "";
    $("#f-semana").value = ""; $("#f-texto").value = ""; $("#f-libres").checked = false; $("#f-retrasadas").checked = false;
    pintar();
  });
  $("#vista-estado").addEventListener("click", () => cambiarVista("estado"));
  $("#vista-semanas").addEventListener("click", () => cambiarVista("semanas"));
  $("#btn-nueva").addEventListener("click", () => abrir(null));
  $("#btn-exportar").addEventListener("click", exportar);
  $("#btn-importar").addEventListener("click", () => $("#archivo-importar").click());
  $("#archivo-importar").addEventListener("change", e => { if (e.target.files[0]) importar(e.target.files[0]); e.target.value = ""; });
  $("#btn-reset").addEventListener("click", restablecer);
  $("#form-tarea").addEventListener("submit", guardarFormulario);
  $("#t-bloque").addEventListener("change", e => pintarCabeceraModal(e.target.value));
  $("#btn-cerrar").addEventListener("click", cerrar);
  $("#btn-cancelar").addEventListener("click", cerrar);
  $("#btn-eliminar").addEventListener("click", eliminar);
  $("#modal").addEventListener("close", () => { editando = null; });

  prepararControles();
  pintar();
})();
