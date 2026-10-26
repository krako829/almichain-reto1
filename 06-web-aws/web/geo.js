// Geolocalización: calcula la distancia del visitante al restaurante
// y le da un enlace con la ruta. La API de geolocalización del navegador
// SOLO funciona en HTTPS (o en localhost).
(function () {
  const RESTAURANTE = { lat: 43.2715, lon: -2.947 };
  const btn = document.getElementById("geo-btn");
  const out = document.getElementById("geo-out");
  if (!btn || !out) return;

  function distanciaKm(a, b) {
    const R = 6371;
    const rad = (g) => (g * Math.PI) / 180;
    const dLat = rad(b.lat - a.lat);
    const dLon = rad(b.lon - a.lon);
    const h =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLon / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(h));
  }

  function formatoKm(km) {
    return km < 1
      ? Math.round(km * 1000) + " m"
      : km.toLocaleString("es-ES", { maximumFractionDigits: 1 }) + " km";
  }

  btn.addEventListener("click", function () {
    if (!window.isSecureContext) {
      out.textContent = "La geolocalización solo funciona si entras por HTTPS.";
      return;
    }
    if (!("geolocation" in navigator)) {
      out.textContent = "Tu navegador no permite la geolocalización.";
      return;
    }
    out.textContent = "Buscando tu ubicación…";
    btn.disabled = true;

    navigator.geolocation.getCurrentPosition(
      function (pos) {
        btn.disabled = false;
        const yo = { lat: pos.coords.latitude, lon: pos.coords.longitude };
        const km = distanciaKm(yo, RESTAURANTE);
        const minutos = Math.max(1, Math.round((km / 4.5) * 60)); // andando a 4,5 km/h
        const modo = km > 5 ? "fossgis_osrm_car" : "fossgis_osrm_foot";
        const ruta =
          "https://www.openstreetmap.org/directions?engine=" + modo +
          "&route=" + yo.lat + "%2C" + yo.lon + "%3B" + RESTAURANTE.lat + "%2C" + RESTAURANTE.lon;

        out.innerHTML = "";
        out.append(
          "Estás a " + formatoKm(km) + " del restaurante" +
          (km <= 5 ? " (unos " + minutos + " min andando). " : ". ")
        );
        const a = document.createElement("a");
        a.href = ruta;
        a.target = "_blank";
        a.rel = "noopener";
        a.textContent = "Ver cómo llegar";
        out.append(a);
      },
      function (err) {
        btn.disabled = false;
        const msg = {
          1: "Has denegado el permiso de ubicación.",
          2: "No se ha podido obtener tu ubicación.",
          3: "Se ha tardado demasiado en obtener tu ubicación.",
        };
        out.textContent = msg[err.code] || "Error al obtener la ubicación.";
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
    );
  });
})();
