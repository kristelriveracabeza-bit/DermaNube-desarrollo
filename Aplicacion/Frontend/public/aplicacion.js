const configuracion = window.ConfiguracionDermaNube || { urlApi: "/api", modoLocal: true }

const estado = {
  ruta: window.location.hash.replace("#", "") || "/",
  especialistas: [],
  citas: [],
  usuario: JSON.parse(localStorage.getItem("usuarioDermaNube") || "null"),
  token: localStorage.getItem("tokenDermaNube") || "",
  filtro: "",
  especialidad: "Todas",
  medicoSeleccionado: null,
  cargando: false
}


function convertirBase64Url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
}

async function crearDesafioPkce(verificador) {
  const datos = new TextEncoder().encode(verificador)
  return convertirBase64Url(new Uint8Array(await crypto.subtle.digest("SHA-256", datos)))
}

function leerToken(token) {
  try {
    const cuerpo = token.split(".")[1].replaceAll("-", "+").replaceAll("_", "/")
    return JSON.parse(decodeURIComponent(escape(atob(cuerpo))))
  } catch {
    return {}
  }
}

async function iniciarAccesoCognito() {
  if (configuracion.modoLocal || !configuracion.dominioCognito) {
    navegar("/acceso")
    return
  }
  const verificador = convertirBase64Url(crypto.getRandomValues(new Uint8Array(48)))
  const desafio = await crearDesafioPkce(verificador)
  const estadoAcceso = convertirBase64Url(crypto.getRandomValues(new Uint8Array(24)))
  sessionStorage.setItem("verificadorPkce", verificador)
  sessionStorage.setItem("estadoAcceso", estadoAcceso)
  const parametros = new URLSearchParams({
    response_type: "code",
    client_id: configuracion.idClienteUsuarios,
    redirect_uri: configuracion.urlRetorno || window.location.origin,
    scope: "openid email profile",
    state: estadoAcceso,
    code_challenge: desafio,
    code_challenge_method: "S256"
  })
  window.location.assign(`${configuracion.dominioCognito}/oauth2/authorize?${parametros}`)
}

async function completarAccesoCognito() {
  const parametros = new URLSearchParams(window.location.search)
  const codigo = parametros.get("code")
  if (!codigo || configuracion.modoLocal) return
  if (parametros.get("state") !== sessionStorage.getItem("estadoAcceso")) throw new Error("La validación de acceso no coincide")
  const verificador = sessionStorage.getItem("verificadorPkce")
  const cuerpo = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: configuracion.idClienteUsuarios,
    code: codigo,
    redirect_uri: configuracion.urlRetorno || window.location.origin,
    code_verifier: verificador
  })
  const respuesta = await fetch(`${configuracion.dominioCognito}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: cuerpo
  })
  if (!respuesta.ok) throw new Error("No fue posible completar el acceso")
  const tokens = await respuesta.json()
  const datos = leerToken(tokens.id_token)
  estado.usuario = { id: datos.sub, correo: datos.email, nombre: datos.name || datos.email?.split("@")[0] || "Paciente" }
  estado.token = tokens.access_token
  localStorage.setItem("usuarioDermaNube", JSON.stringify(estado.usuario))
  localStorage.setItem("tokenDermaNube", estado.token)
  sessionStorage.removeItem("verificadorPkce")
  sessionStorage.removeItem("estadoAcceso")
  history.replaceState({}, "", `${window.location.pathname}#/micuenta`)
}

const especialistasDemostracion = [
  { id: "ESP001", nombre: "Valeria Ríos", especialidad: "Dermatología clínica", experiencia: 12, calificacion: 4.9, opiniones: 184, sede: "Trujillo Centro", precio: 130, modalidades: ["Presencial", "En línea"], resumen: "Atención integral de acné, dermatitis y salud preventiva de la piel." },
  { id: "ESP002", nombre: "Mateo Salazar", especialidad: "Dermatología capilar", experiencia: 9, calificacion: 4.8, opiniones: 121, sede: "California", precio: 145, modalidades: ["Presencial"], resumen: "Diagnóstico y seguimiento personalizado de alopecia y alteraciones del cuero cabelludo." },
  { id: "ESP003", nombre: "Lucía Cárdenas", especialidad: "Dermatología estética", experiencia: 14, calificacion: 4.9, opiniones: 207, sede: "El Golf", precio: 160, modalidades: ["Presencial", "En línea"], resumen: "Tratamientos dermatológicos con enfoque conservador y seguimiento fotográfico." },
  { id: "ESP004", nombre: "Andrés Vega", especialidad: "Oncología dermatológica", experiencia: 16, calificacion: 4.9, opiniones: 96, sede: "Primavera", precio: 180, modalidades: ["Presencial"], resumen: "Evaluación de lunares, prevención y diagnóstico temprano de lesiones cutáneas." }
]

function escapar(texto = "") {
  return String(texto).replace(/[&<>'"]/g, caracter => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[caracter]))
}

function iniciales(nombre) {
  return nombre.split(" ").slice(0, 2).map(parte => parte[0]).join("")
}

function notificar(mensaje, tipo = "normal") {
  const contenedor = document.getElementById("notificaciones")
  const elemento = document.createElement("div")
  elemento.className = `notificacion ${tipo === "error" ? "notificacionError" : ""}`
  elemento.textContent = mensaje
  contenedor.appendChild(elemento)
  setTimeout(() => elemento.remove(), 4200)
}

async function solicitar(ruta, opciones = {}) {
  const encabezados = { "Content-Type": "application/json", ...(opciones.headers || {}) }
  if (estado.token) encabezados.Authorization = `Bearer ${estado.token}`
  const respuesta = await fetch(`${configuracion.urlApi}${ruta}`, { ...opciones, headers: encabezados })
  if (!respuesta.ok) {
    const detalle = await respuesta.json().catch(() => ({ mensaje: "No fue posible completar la operación" }))
    throw new Error(detalle.mensaje || "No fue posible completar la operación")
  }
  return respuesta.status === 204 ? null : respuesta.json()
}

function navegar(ruta) {
  window.location.hash = ruta
}

function obtenerEnlaceActivo(ruta) {
  return estado.ruta === ruta ? "activo" : ""
}

function cabecera() {
  return `
    <header class="cabecera">
      <div class="contenedor barraNavegacion">
        <a class="marca" href="#/">
          <img src="recursos/Marca.svg" alt="DermaNube">
          <span>DermaNube</span>
        </a>
        <nav class="enlacesNavegacion" id="enlacesNavegacion">
          <a class="enlaceNavegacion ${obtenerEnlaceActivo("/")}" href="#/">Inicio</a>
          <a class="enlaceNavegacion ${obtenerEnlaceActivo("/especialistas")}" href="#/especialistas">Especialistas</a>
          <a class="enlaceNavegacion" href="#/">Tratamientos</a>
          <a class="enlaceNavegacion" href="#/">Cómo funciona</a>
        </nav>
        <div class="accionesNavegacion">
          ${estado.usuario ? `<button class="botonTexto" dataaccion="salir">Salir</button><a class="boton" href="#/micuenta">Mi cuenta</a>` : `<button class="botonTexto" dataaccion="acceso">Iniciar sesión</button><a class="boton" href="#/especialistas">Reservar evaluación</a>`}
          <button class="menuMovil" dataaccion="menu" aria-label="Abrir navegación">☰</button>
        </div>
      </div>
    </header>
  `
}

function pie() {
  return `
    <footer class="piePagina">
      <div class="contenedor grillaPie">
        <div>
          <h3 class="marca"><img src="recursos/Marca.svg" alt="">DermaNube</h3>
          <p>Atención dermatológica digital con seguimiento claro, agenda flexible y cuidado responsable de la información.</p>
        </div>
        <div><h4>Servicios</h4><div class="listaPie"><a href="#/especialistas">Consulta dermatológica</a><a href="#/especialistas">Seguimiento capilar</a><a href="#/especialistas">Evaluación preventiva</a></div></div>
        <div><h4>Plataforma</h4><div class="listaPie"><a href="#/micuenta">Mis citas</a><a href="#/especialistas">Especialistas</a><a href="#/">Preguntas frecuentes</a></div></div>
        <div><h4>Información</h4><div class="listaPie"><a href="#/">Privacidad</a><a href="#/">Términos</a><a href="#/">Seguridad</a></div></div>
      </div>
    </footer>
  `
}

function paginaInicio() {
  return `
    ${cabecera()}
    <main>
      <section class="hero">
        <div class="heroContenido">
          <span class="sobretitulo">Dermatología personalizada</span>
          <h1>Evidencia antes que promesas</h1>
          <p>Consulta, agenda y seguimiento dermatológico en una experiencia simple, segura y pensada para evolucionar contigo.</p>
          <div class="metricasHero">
            <div class="metricaHero"><strong>94%</strong><span>califica su atención como clara</span></div>
            <div class="metricaHero"><strong>24 h</strong><span>para confirmar el seguimiento</span></div>
            <div class="metricaHero"><strong>4.9</strong><span>valoración promedio</span></div>
          </div>
          <div><a class="boton" href="#/especialistas">Empezar en minutos</a></div>
        </div>
        <div class="heroImagen"><img src="recursos/HeroDermatologia.svg" alt="Ilustración editorial de cuidado dermatológico"></div>
      </section>

      <section class="seccion seccionBlanca">
        <div class="contenedor">
          <div class="cabeceraSeccion"><div><h2>Planes de cuidado que se adaptan a tu piel</h2><p>El especialista combina tu evaluación, antecedentes y seguimiento para definir una ruta de atención personalizada.</p></div><a class="boton" href="#/especialistas">Encontrar especialista</a></div>
          <div class="grillaFormulas">
            ${tarjetaFormula("recursos/FormulaFacial.svg", "Control facial", "Evaluación de acné, sensibilidad, manchas y barrera cutánea.")}
            ${tarjetaFormula("recursos/FormulaCapilar.svg", "Seguimiento capilar", "Revisión del cuero cabelludo y evolución del crecimiento capilar.")}
            ${tarjetaFormula("recursos/FormulaProteccion.svg", "Prevención solar", "Evaluación de lunares y estrategia cotidiana de fotoprotección.")}
            ${tarjetaFormula("recursos/FormulaHidratacion.svg", "Recuperación de barrera", "Plan para textura, resequedad y tolerancia progresiva a activos.")}
          </div>
        </div>
      </section>

      <section class="seccion">
        <div class="contenedor resultadosPrincipal">
          <div class="resultadosTexto"><h2>90.5% observó una mejora visible durante su seguimiento</h2><div class="estrellas">★★★★★ <span>Más de 900 valoraciones verificadas</span></div></div>
          <div class="carruselResultados">
            ${resultado("Andrea", "La explicación fue clara y pude ver mi progreso sin cambiar de rutina cada semana.", "6 semanas")}
            ${resultado("Carlos", "La agenda y los recordatorios hicieron que no abandonara el seguimiento capilar.", "3 meses")}
            ${resultado("Mariana", "Me gustó que el tratamiento se ajustara según la respuesta de mi piel.", "8 semanas")}
          </div>
        </div>
      </section>

      <section class="seccion seccionBlanca">
        <div class="contenedor">
          <div class="cabeceraSeccion"><div><h2>Cómo funciona</h2><p>Una ruta breve para conectar la atención digital con un seguimiento clínico ordenado.</p></div><a class="boton" href="#/especialistas">Reservar evaluación</a></div>
          <div class="pasos">
            ${paso("1", "Cuéntanos qué necesitas", "Elige el motivo de consulta, modalidad y disponibilidad que prefieres.")}
            ${paso("2", "Conecta con un especialista", "Compara perfiles, experiencia, sedes y horarios disponibles.")}
            ${paso("3", "Inicia tu evaluación", "Registra tu cita y recibe la confirmación sin llamadas ni esperas.")}
            ${paso("4", "Mantén el seguimiento", "Consulta tus citas, documentos y próximos controles desde tu cuenta.")}
          </div>
        </div>
      </section>
    </main>
    ${pie()}
  `
}

function tarjetaFormula(imagen, titulo, descripcion) {
  return `<article class="tarjetaFormula"><img src="${imagen}" alt="${escapar(titulo)}"><div class="tarjetaFormulaContenido"><h3>${escapar(titulo)}</h3><p>${escapar(descripcion)}</p><a class="botonTexto" href="#/especialistas">Conocer opciones →</a></div></article>`
}

function resultado(nombre, texto, tiempo) {
  return `<article class="resultado"><div class="comparacion"><div class="pielAntes"><span class="etiquetaComparacion">Inicio</span></div><div class="pielDespues"><span class="etiquetaComparacion">${escapar(tiempo)}</span></div></div><h3>${escapar(nombre)}</h3><p>${escapar(texto)}</p></article>`
}

function paso(numero, titulo, descripcion) {
  return `<article class="paso"><span class="numeroPaso">${numero}</span><h3>${escapar(titulo)}</h3><p>${escapar(descripcion)}</p></article>`
}

async function cargarEspecialistas() {
  estado.cargando = true
  renderizar()
  try {
    const datos = await solicitar("/personas/especialistas")
    estado.especialistas = datos.elementos || datos
  } catch (error) {
    if (configuracion.modoLocal) estado.especialistas = especialistasDemostracion
    else notificar(error.message, "error")
  } finally {
    estado.cargando = false
    renderizar()
  }
}

function paginaEspecialistas() {
  const especialidades = ["Todas", ...new Set(estado.especialistas.map(item => item.especialidad))]
  const filtrados = estado.especialistas.filter(item => {
    const coincideTexto = `${item.nombre} ${item.especialidad} ${item.sede}`.toLowerCase().includes(estado.filtro.toLowerCase())
    const coincideEspecialidad = estado.especialidad === "Todas" || item.especialidad === estado.especialidad
    return coincideTexto && coincideEspecialidad
  })
  return `
    ${cabecera()}
    <main class="pagina">
      <section class="encabezadoPagina">
        <div class="contenedor">
          <h1>Especialistas en dermatología</h1>
          <p>Encuentra una atención adecuada por especialidad, ubicación, modalidad y horario.</p>
          <div class="buscadorMedicos">
            <input class="campo" id="busquedaEspecialista" value="${escapar(estado.filtro)}" placeholder="Especialidad, tratamiento o especialista">
            <select class="selector" id="ubicacionEspecialista"><option>Trujillo, La Libertad</option><option>Consulta en línea</option></select>
            <button class="boton" dataaccion="buscar">Buscar</button>
          </div>
        </div>
      </section>
      <section class="contenedor">
        <div class="filtros">${especialidades.map(especialidad => `<button class="filtro ${estado.especialidad === especialidad ? "activo" : ""}" dataespecialidad="${escapar(especialidad)}">${escapar(especialidad)}</button>`).join("")}</div>
        <div class="contenidoMedicos">
          <div class="listaMedicos">
            ${estado.cargando ? `<div class="carga">Cargando especialistas...</div>` : filtrados.length ? filtrados.map(tarjetaMedico).join("") : `<div class="vacio">No encontramos especialistas con esos filtros.</div>`}
          </div>
          <div class="mapaFicticio" aria-label="Mapa referencial">
            ${filtrados.slice(0, 6).map((item, indice) => `<div class="marcadorMapa" style="left:${18 + (indice * 13) % 65}%;top:${22 + (indice * 17) % 64}%"><span>${indice + 1}</span></div>`).join("")}
          </div>
        </div>
      </section>
    </main>
    ${pie()}
  `
}

function tarjetaMedico(medico) {
  return `<article class="tarjetaMedico">
    <div class="avatarMedico">${iniciales(medico.nombre)}</div>
    <div class="informacionMedico">
      <h3>${escapar(medico.nombre)} <span class="verificado">●</span></h3>
      <div class="especialidadMedico">${escapar(medico.especialidad)} · ${medico.calificacion || "4.8"} ★ · ${medico.opiniones || 0} opiniones</div>
      <p>${escapar(medico.resumen || "Atención dermatológica personalizada y seguimiento clínico.")}</p>
      <div class="detallesMedico"><span>${medico.experiencia || 8} años de experiencia</span><span>${escapar(medico.sede || "Trujillo")}</span><span>${(medico.modalidades || ["Presencial"]).join(" · ")}</span></div>
    </div>
    <div class="accionesMedico"><div class="precioMedico">Consulta desde S/ ${medico.precio || 120}</div><button class="boton" datareservar="${medico.id}">Ver horarios</button><button class="botonSecundario" datareservar="${medico.id}">Ver perfil</button></div>
  </article>`
}

function paginaCuenta() {
  if (!estado.usuario) return paginaAcceso()
  const confirmadas = estado.citas.filter(cita => cita.estado === "Confirmada").length
  const pendientes = estado.citas.filter(cita => cita.estado === "Pendiente").length
  return `
    ${cabecera()}
    <main class="pagina panel">
      <div class="contenedor">
        <div class="cabeceraSeccion"><div><h2>Hola, ${escapar(estado.usuario.nombre || "Paciente")}</h2><p>Consulta tus citas y el estado de cada atención.</p></div><a class="boton" href="#/especialistas">Nueva cita</a></div>
        <div class="grillaPanel">
          <aside class="menuPanel"><button class="activo">Mis citas</button><button>Mi perfil</button><button>Documentos</button><button>Notificaciones</button></aside>
          <section class="contenidoPanel">
            <div class="resumenes"><div class="resumen"><span>Próximas</span><strong>${confirmadas}</strong></div><div class="resumen"><span>Pendientes</span><strong>${pendientes}</strong></div><div class="resumen"><span>Total</span><strong>${estado.citas.length}</strong></div></div>
            ${estado.citas.length ? `<div class="tablaResponsiva"><table><thead><tr><th>Especialista</th><th>Fecha</th><th>Modalidad</th><th>Estado</th><th></th></tr></thead><tbody>${estado.citas.map(filaCita).join("")}</tbody></table></div>` : `<div class="vacio">Todavía no tienes citas registradas. <a href="#/especialistas">Encuentra un especialista</a>.</div>`}
          </section>
        </div>
      </div>
    </main>
    ${pie()}
  `
}

function filaCita(cita) {
  const especialista = estado.especialistas.find(item => item.id === cita.especialistaId)
  const clase = cita.estado === "Cancelada" ? "estadoCancelada" : cita.estado === "Pendiente" ? "estadoPendiente" : "estadoConfirmada"
  return `<tr><td>${escapar(especialista?.nombre || cita.especialistaNombre || "Especialista")}</td><td>${new Date(cita.fechaHora).toLocaleString("es-PE")}</td><td>${escapar(cita.modalidad || "Presencial")}</td><td><span class="estado ${clase}">${escapar(cita.estado)}</span></td><td>${cita.estado !== "Cancelada" ? `<button class="botonTexto botonPeligro" datacancelar="${cita.id}">Cancelar</button>` : ""}</td></tr>`
}

function paginaAcceso() {
  const contenido = configuracion.modoLocal ? `<form class="formulario" id="formularioAcceso"><div class="grupoCampo"><label>Correo</label><input class="campo" type="email" name="correo" required placeholder="paciente@correo.com"></div><div class="grupoCampo"><label>Nombre</label><input class="campo" name="nombre" required placeholder="Nombre del paciente"></div><button class="boton" type="submit">Continuar</button></form>` : `<div class="formulario"><p>El acceso seguro se realiza mediante el servicio de identidad de la plataforma.</p><button class="boton" dataaccion="acceso">Continuar con acceso seguro</button></div>`
  return `
    ${cabecera()}
    <main class="pagina panel">
      <div class="contenedor" style="max-width:760px">
        <section class="contenidoPanel">
          <div class="cabeceraSeccion"><div><h2>Accede a tu cuenta</h2><p>Revisa tus citas, recordatorios y documentos de seguimiento.</p></div></div>
          ${contenido}
        </section>
      </div>
    </main>
    ${pie()}
  `
}

function modalReserva(medico) {
  const manana = new Date(Date.now() + 86400000).toISOString().slice(0, 10)
  return `<div class="modalFondo" id="modalReserva"><div class="modal"><div class="modalCabecera"><div><h2>Reservar evaluación</h2><div>${escapar(medico.nombre)} · ${escapar(medico.especialidad)}</div></div><button class="cerrarModal" dataaccion="cerrarmodal">×</button></div><form id="formularioReserva"><div class="modalContenido formulario"><div class="filaFormulario"><div class="grupoCampo"><label>Fecha</label><input class="campo" type="date" name="fecha" min="${manana}" value="${manana}" required></div><div class="grupoCampo"><label>Hora</label><select class="selector" name="hora"><option>09:00</option><option>10:30</option><option>12:00</option><option>15:00</option><option>17:30</option></select></div></div><div class="grupoCampo"><label>Modalidad</label><select class="selector" name="modalidad">${(medico.modalidades || ["Presencial"]).map(item => `<option>${escapar(item)}</option>`).join("")}</select></div><div class="grupoCampo"><label>Motivo de consulta</label><textarea class="areaTexto" name="motivo" required placeholder="Describe brevemente el motivo de la evaluación"></textarea></div></div><div class="modalPie"><button class="botonSecundario" type="button" dataaccion="cerrarmodal">Volver</button><button class="boton" type="submit">Confirmar cita</button></div></form></div></div>`
}

async function reservarCita(formulario) {
  if (!estado.usuario) {
    notificar("Inicia sesión antes de reservar una cita", "error")
    navegar("/acceso")
    return
  }
  const datos = new FormData(formulario)
  const fechaHora = new Date(`${datos.get("fecha")}T${datos.get("hora")}:00`).toISOString()
  const carga = {
    pacienteId: estado.usuario.id,
    especialistaId: estado.medicoSeleccionado.id,
    especialistaNombre: estado.medicoSeleccionado.nombre,
    fechaHora,
    modalidad: datos.get("modalidad"),
    motivo: datos.get("motivo")
  }
  try {
    const cita = await solicitar("/citas", { method: "POST", body: JSON.stringify(carga) })
    estado.citas.unshift(cita)
  } catch (error) {
    if (!configuracion.modoLocal) {
      notificar(error.message, "error")
      return
    }
    estado.citas.unshift({ id: crypto.randomUUID(), ...carga, estado: "Confirmada", creadaEn: new Date().toISOString() })
  }
  localStorage.setItem("citasDermaNube", JSON.stringify(estado.citas))
  document.getElementById("modalReserva")?.remove()
  notificar("La cita fue registrada correctamente")
  navegar("/micuenta")
}

async function cancelarCita(id) {
  try {
    await solicitar(`/citas/${id}/cancelar`, { method: "PATCH" })
  } catch (error) {
    if (!configuracion.modoLocal) {
      notificar(error.message, "error")
      return
    }
  }
  estado.citas = estado.citas.map(cita => cita.id === id ? { ...cita, estado: "Cancelada" } : cita)
  localStorage.setItem("citasDermaNube", JSON.stringify(estado.citas))
  notificar("La cita fue cancelada")
  renderizar()
}

function registrarEventos() {
  document.querySelectorAll("[dataaccion]").forEach(elemento => elemento.addEventListener("click", evento => {
    const accion = evento.currentTarget.dataset.accion
    if (accion === "menu") document.getElementById("enlacesNavegacion")?.classList.toggle("abierto")
    if (accion === "acceso") iniciarAccesoCognito().catch(error => notificar(error.message, "error"))
    if (accion === "salir") {
      localStorage.removeItem("usuarioDermaNube")
      localStorage.removeItem("tokenDermaNube")
      estado.usuario = null
      estado.token = ""
      navegar("/")
    }
    if (accion === "buscar") {
      estado.filtro = document.getElementById("busquedaEspecialista")?.value || ""
      renderizar()
    }
    if (accion === "cerrarmodal") document.getElementById("modalReserva")?.remove()
  }))

  document.querySelectorAll("[dataespecialidad]").forEach(elemento => elemento.addEventListener("click", () => {
    estado.especialidad = elemento.dataset.especialidad
    renderizar()
  }))

  document.querySelectorAll("[datareservar]").forEach(elemento => elemento.addEventListener("click", () => {
    const medico = estado.especialistas.find(item => item.id === elemento.dataset.reservar)
    if (!medico) return
    estado.medicoSeleccionado = medico
    document.body.insertAdjacentHTML("beforeend", modalReserva(medico))
    document.getElementById("formularioReserva")?.addEventListener("submit", evento => {
      evento.preventDefault()
      reservarCita(evento.currentTarget)
    })
    registrarEventos()
  }))

  document.querySelectorAll("[datacancelar]").forEach(elemento => elemento.addEventListener("click", () => cancelarCita(elemento.dataset.cancelar)))

  document.getElementById("formularioAcceso")?.addEventListener("submit", evento => {
    evento.preventDefault()
    const datos = new FormData(evento.currentTarget)
    estado.usuario = { id: `PAC${Date.now()}`, correo: datos.get("correo"), nombre: datos.get("nombre") }
    estado.token = "tokenlocal"
    localStorage.setItem("usuarioDermaNube", JSON.stringify(estado.usuario))
    localStorage.setItem("tokenDermaNube", estado.token)
    notificar("Sesión iniciada")
    navegar("/micuenta")
  })
}

function renderizar() {
  estado.ruta = window.location.hash.replace("#", "") || "/"
  const aplicacion = document.getElementById("aplicacion")
  if (estado.ruta === "/especialistas") aplicacion.innerHTML = paginaEspecialistas()
  else if (estado.ruta === "/micuenta") aplicacion.innerHTML = paginaCuenta()
  else if (estado.ruta === "/acceso") aplicacion.innerHTML = paginaAcceso()
  else aplicacion.innerHTML = paginaInicio()
  registrarEventos()
  window.scrollTo({ top: 0, behavior: "instant" })
}

async function iniciar() {
  await completarAccesoCognito().catch(error => notificar(error.message, "error"))
  estado.citas = JSON.parse(localStorage.getItem("citasDermaNube") || "[]")
  estado.especialistas = especialistasDemostracion
  renderizar()
  await cargarEspecialistas()
}

window.addEventListener("hashchange", renderizar)
iniciar()
