# ani-es — Ver anime en español desde la terminal

CLI en Bash para **buscar, ver y continuar anime en español** (doblaje latino
o subtitulado) sin salir de la terminal. Fuente actual: **J-Kanime**.

```bash
ani-es naruto          # buscar y ver
ani-es -c naruto       # continuar donde lo dejaste
ani-es -i espanol-latino   # explorar catálogo con doblaje latino
```

---

## 1. Filosofía del proyecto

1. **La terminal es suficiente.** Sin navegador, sin anuncios, sin cuentas:
   buscar → elegir → ver. Todo con herramientas del sistema.
2. **Un solo archivo auditable.** El programa es un script Bash (~940 líneas)
   que cualquiera puede leer de arriba a abajo. Nada ofuscado, nada binario.
3. ** streaming, no descarga.** Solo se resuelve la URL directa del video y se
   entrega al reproductor (`mpv` / VLC). El proyecto no aloja contenido.
4. **El historial es del usuario.** JSON plano en `~/ani-es/history.json`:
   legible, copiable, editable a mano y con backup automático.
5. **Robusto ante la red real.** Timeouts, reintentos, escritura atómica del
   historial y auto-reparación si el archivo se corrompe.
6. **Hotfix sin release.** Los slugs problemáticos se corrigen con
   `excepciones.json` remoto: se arregla la fuente y todos los usuarios lo
   reciben sin actualizar.
7. **QA manual, casos testigo fijos.** Sin suite automatizada en este repo;
   cada cambio se valida a mano contra animes testigo (ver §10).

## 2. Características

- 🔍 Búsqueda interactiva con **fzf**
- 📺 Reproducción directa con **mpv** (Linux/WSL) o **VLC** (Termux/Android)
- ⏭️ Menú post-reproducción: siguiente / anterior / volver / salir
- 💾 Historial automático: último episodio + progreso `HH:MM:SS` + fuente,
  con backup `history.json.bak` y auto-reparación
- 🔁 `-c` continúa exactamente donde pausaste (`mpv --start=`)
- 🗣️ Detección de idioma por anime (*Doblaje latino / Subtitulado /
  Castellano*) y catálogo por idioma con `-i`
- 🌐 Soporta Linux, WSL (Windows) y Termux
- ⏱️ Red con timeouts (25 s) y 2 reintentos en todas las descargas
- 🧹 Limpieza garantizada de temporales al salir, incluso con Ctrl+C

## 3. Requisitos

`wget fzf grep sed python3 mpv jq curl`

El instalador las resuelve solo. Notas por plataforma:

| Plataforma | Reproductor | Detalle |
|---|---|---|
| Linux | `mpv` | Soporte completo, progreso exacto |
| WSL | `mpv.exe` en el PATH de Windows | El video abre en Windows; el control sigue en WSL |
| Termux | VLC (`org.videolan.vlc`) o navegador | Sin reporte de progreso (se guarda `00:00:00`) |

## 4. Instalación

```bash
git clone https://github.com/MeldrickV/terminal-anime-es.git
cd terminal-anime-es
chmod +x install.sh
./install.sh
```

Esto instala dependencias, copia `ani-es` a `/usr/local/bin` y crea
`~/ani-es/`. El historial (`~/ani-es/history.json`) se crea solo al primer
arranque.

Para actualizar el ejecutable tras un cambio del repo:

```bash
sudo cp ani-es /usr/local/bin/ani-es   # o /usr/bin/ani-es según tu instalación
```

## 5. Uso

```bash
ani-es [opciones] [búsqueda]
```

| Opción | Efecto |
|---|---|
| `-h, --help` | Mostrar ayuda |
| `-v, --version` | Mostrar versión |
| `-c, --continue` | Continuar el último anime donde lo dejaste (combina con búsqueda: `ani-es -c naruto`) |
| `-i, --idioma ID` | Explorar el catálogo de un idioma: `espanol-latino` \| `japones` |

### Flujo típico

1. `ani-es pokemon` → lista resultados (fzf) → eliges *pokemon*.
2. Ves ficha: título, último episodio visto, idioma.
3. Eliges episodio (o auto-continúa con `-c`) → se resuelve el video → abre `mpv`.
4. Al salir de `mpv`: menú *Siguiente / Retroceder / Atrás / Salir*.
5. El progreso se guarda solo en `history.json`.

### Idiomas

Cada ficha muestra el idioma detectado en la página del anime
(`Doblaje latino`, `Subtitulado`, `Castellano` o combinaciones). Con `-i`
navegas el catálogo completo de un idioma, paginado.

## 6. Arquitectura y flujo de datos

```
args (-c/-i/búsqueda)
  → main() [bucle; limpiar_estado() entre ciclos]
    → pipeline_idioma()   (solo con -i; al elegir, reentra a pipeline_jkanime)
    → pipeline_jkanime()
        → búsqueda: wget espejo buscar/<q>/ + grep <h5><a> + fzf
        → slug: saneado + corrección por excepciones.json remoto
        → ficha: curl página + token CSRF + POST ajax + total + tipo + idiomas
        → selector: seq 1..N | fzf   (o auto: -c / película)
        → videocap(): espejo del episodio + cascada jkplayer → jk.php → servers/Mediafire
        → reproducir(): mpv/VLC + captura de progreso
        → save_history(): escritura atómica + backup
        → menu_post_reproduccion(): siguiente/anterior/atrás/salir
```

**Reglas del flujo:**

- `main()` nunca muere por un enlace roto: vuelve al menú (`return`).
- Cancelar un `fzf` (Esc) aborta limpio a la pantalla anterior.
- `limpiar_estado()` resetea variables entre búsquedas sin tocar los flags
  de control (`CONTINUE/ABORT/SALIR`).

## 7. Referencia de funciones (`ani-es`)

| Función | Líneas* | Rol |
|---|---|---|
| `init_history()` | ~45 | Crea/valida `history.json`; regenera `{}` si está vacío o corrupto; migra `history.db` (sqlite) y `source: animeflv → jkanime` una sola vez |
| `get_last_cap` / `get_progress` | ~165 | Leen `last_cap` / `progress` con `jq` |
| `save_history` | ~183 | Guarda `anime → {last_cap, progress, source}` vía `mktemp+jq+mv` atómico; ignora `cap` vacío; backup `.bak` previo |
| `show_help` / `show_version` | ~216 | Ayuda y versión (`VERSION="1.5.1"`) |
| `check_dependencies` | ~263 | Aborta listando lo que falta |
| `detect_env` | ~284 | `wsl` / `termux` / `linux` |
| `reproducir` | ~299 | `mpv[.exe] --start=$progress` (Linux/WSL) o intent VLC / `termux-open-url` (Termux); parsea `AV: HH:MM:SS` del stdout como progreso |
| `limpiar_estado` | ~336 | Reset entre búsquedas |
| `limpiar_temporales` (+ `trap`) | ~900 | Borra `cookies.txt`, `resultados.txt`, `pagina_idioma.html`, `index` y la página temporal al salir (con guard `BASHPID` para no disparar en subshells) |
| `menu_post_reproduccion` | ~353 | fzf Siguiente / Retroceder / Atrás / Salir |
| `pipeline_jkanime` | ~378 | Pipeline completo (búsqueda → ficha → episodio → video). Incluye `pagina_siguiente/anterior`, `ir_a_capitulo`, `videocap` |
| `pipeline_idioma` | ~839 | Catálogo `GET /idioma/<slug>?p=N` paginado; reentra a `pipeline_jkanime` |
| `main` | ~902 | Bucle principal; gestiona `REENTRY`, `IDIOMA_BROWSE`, `SALIR/ABORT` |

\* Líneas aproximadas en v1.5.1.

### Variables globales de red

```bash
JK_UA="Mozilla/5.0 ... Chrome/91.0.4472.124"   # user-agent fijo
CURL_OPTS="--max-time 25 --retry 2 --fail -s"  # todos los curl
WGET_OPTS="--timeout=25 --tries=2"             # todos los wget -p
```

## 8. Cómo funciona el scraping (J-Kanime)

1. **Búsqueda:** espejo `wget -p https://jkanime.net/buscar/<q_con_guiones_bajos>/`
   y `grep -oP '<h5><a\s+href="[^"]*">\K.*?(?=</a></h5>)'`.
2. **Slug:** `tr -cd '[:alnum:] -'` → espacios a `-` → minúsculas; luego se
   corrige contra `excepciones.json` **remoto**
   (`https://zhuchii.github.io/ani-es/excepciones.json`, 634 entradas) para
   slugs truncados.
3. **Ficha (determinista):** `curl -c cookies.txt -o $page_anime $url` y de
   ahí: `meta csrf-token`, `url: '.../ajax/episodes/<id>/'`,
   `<span>Tipo:</span>`, enlaces `/idioma/<slug>`.
4. **Total:** `POST` al ajax con cookie + `X-CSRF-TOKEN` + `_token` →
   `"total": N`.
5. **Video (`videocap`):** espejo de `/<slug>/<cap>` y cascada:
   `jkplayer/um*` → iframe `/jk.php*` → `var servers` (Mediafire, base64) →
   URL directa a `mpv`. Películas: `capi=pelicula` → se registra como cap 1.

## 9. Historial (`~/ani-es/history.json`)

```json
{
  "Pokemon": {"last_cap": 118, "progress": "00:00:00", "source": "jkanime"},
  "Naruto":  {"last_cap": 5,   "progress": "00:12:30", "source": "jkanime"}
}
```

- `last_cap`: entero (`"pelicula"` se guarda como `1`).
- `progress`: `HH:MM:SS` (vacío/`00:00:00` en Termux, sin reporte).
- Protecciones: no guarda `cap` vacío, `mv` solo si `jq` sale bien,
  `history.json.bak` antes de cada escritura, auto-regeneración si el archivo
  está vacío o es JSON inválido.
- Migración legacy (una vez, interactiva `y/n`): `history.db` sqlite →
  JSON, y `animeflv → jkanime`.

## 10. Calidad: QA manual con casos testigo

Este repo no tiene suite automatizada; cada cambio se valida a mano contra:

| Anime | Episodios | Idioma | Caso que cubre |
|---|---|---|---|
| `pokemon` | 276 | latino | general + 1 idioma |
| `pokemon-xy` | 93 | subtitulado | 1 idioma (el que fallaba en v1.5.0) |
| `dragon-ball-z` | 291 | latino + subtitulado | 2 idiomas |

Batería mínima por cambio: búsqueda → ficha → 1 capítulo completo →
`-c` → corte de red (~25 s, sin colgarse) → slug inexistente (vuelve al
menú) → Ctrl+C (sin temporales huérfanos).

Además, el workflow **`snapshot.yml`** (Actions, semanal + manual) descarga
las páginas testigo y falla si desaparece algún marcador
(`<h5><a>`, `csrf-token`, `ajax/episodes`, `Tipo:`, `/idioma/`, `"total":`),
avisando antes de que rompa en producción.

## 11. Estructura del repositorio

```
terminal-anime-es/
├── ani-es                 # programa principal (Bash, ejecutable)
├── excepciones.json       # mapa local de slugs (la fuente viva es la remota)
├── install.sh             # dependencias + copia a /usr/local/bin + ~/ani-es/
├── uninstall.sh           # retira el binario; pregunta antes de borrar historial
├── history.json           # ejemplo (el real vive en ~/ani-es/)
├── README.md
├── LICENSE
└── .github/workflows/
    ├── snapshot.yml       # vigía semanal de marcadores HTML
    ├── version.yml        # auto-bump de VERSION según Conventional Commits
    └── static.yml         # pages
```

Versionado: `fix:` → patch, `feat:` → minor, `BREAKING CHANGE` → major
(automático en CI).

## 12. Solución de problemas

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| No carga capítulos / lista vacía | jkanime cambió su HTML | Abre un issue con el enlace; revisa el último run de `snapshot.yml` |
| `enlace no válido` | slug inexistente o página caída | Vuelve al menú y prueba otro título |
| Se cuelga >30 s | red caída sin timeout (versión vieja) | Actualiza el ejecutable (§4) |
| `history.json` a 0 bytes | corrupción (versiones < v1.5.1) | Arranca de nuevo: se regenera solo; restaura desde `.bak` si quieres |
| Dependencia faltante | instalación incompleta | Reejecuta `./install.sh` |

## 13. Desinstalar / contribuir

```bash
./uninstall.sh   # pregunta si borrar también el historial
```

Contribuciones: reportar bugs (con enlace del anime), sugerir features y pull
requests. Usa Conventional Commits (`fix:` / `feat:`) para que el versionado
automático funcione.

## 14. Nota legal

Interfaz CLI para sitios de streaming de terceros. No aloja ni distribuye
contenido. Úsalo bajo tu responsabilidad y respeta los términos de cada sitio.
