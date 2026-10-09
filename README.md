# ani-es — Ver anime en español desde la terminal

CLI en Bash para **buscar, ver y continuar anime en español** (doblaje latino y subtitulado) sin salir de la terminal. Inspirado en `ani-cli`, enfocado en contenido en español vía **mpv + fzf**.

![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20WSL%20%7C%20Termux-blue)
![License](https://img.shields.io/github/license/MeldrickV/terminal-anime-es)
![Made with Bash](https://img.shields.io/badge/made%20with-bash-1f425f)
![Uses mpv](https://img.shields.io/badge/player-mpv-orange)

> **Sesión actual: solo versión terminal.** El port Android vive en otro repositorio y no se toca aquí para evitar confusiones entre proyectos.

---

## Filosofía del proyecto

1. **La terminal es la interfaz.** Nada de navegador, nada de anuncios, nada de cuentas: buscar → elegir → ver.
2. **Determinista antes que listo.** La extracción de datos se hace sobre una página descargada con `curl` (token CSRF + POST ajax), nunca sobre rutas frágiles del mirror de `wget`. Si la web cambia, falla con mensaje claro, no en silencio.
3. **El historial es sagrado.** Escritura atómica (`jq` → temporal → `mv` solo si todo salió bien), backup rotativo y auto-reparación si el archivo se corrompe. Ningún error de red o selección vacía puede borrar tu progreso.
4. **Hotfix sin release.** El mapa de slugs problemáticos (`excepciones.json`) se consume remoto: un anime con slug raro se corrige en el servidor sin que actualices nada.
5. **Liviano y auditable.** Un solo script Bash (~950 líneas), dependencias del sistema, sin builds ni demonios. Todo lo que hace se puede leer en minutos.
6. **Degradación elegante.** Sin red, con un enlace roto o si cancelas una selección, el programa vuelve al menú. Nunca te deja tirado ni cierra la sesión por un error recuperable.

---

## Características

- 🔍 Búsqueda interactiva de animes con **fzf**.
- 📺 Reproducción directa con **mpv** (Linux/WSL) o VLC/intent (Termux).
- ⏭️ Menú post-reproducción: siguiente / retroceder / atrás / salir.
- 💾 Historial automático: último episodio + progreso `HH:MM:SS` por anime.
- 🔁 `-c` para continuar donde lo dejaste (reanuda en el minuto exacto).
- 🗣️ Detección de idioma por anime (**Doblaje latino / Subtitulado / Castellano**) y catálogo por idioma con `-i`.
- 🌐 Red robusta: timeouts (25 s) y reintentos en todas las descargas.
- 🧹 Limpieza garantizada de temporales (`cookies.txt`, páginas, mirrors) incluso con Ctrl+C.
- 🛰️ Vigía semanal en CI que avisa si la web cambia su HTML.

---

## Requisitos

| Dependencia | Uso |
|---|---|
| `bash` ≥ 5 | Intérprete |
| `mpv` | Reproductor (Linux/WSL) |
| `fzf` | Selectores interactivos |
| `curl`, `wget` | Descargas y scraping |
| `jq` | Historial JSON |
| `grep` (PCRE `-P`), `sed` | Extracción |
| `python3` | Migración legacy + decode base64 |

El instalador las resuelve solo. En Termux se usa VLC/`termux-open-url` en vez de mpv.

---

## Instalación

### Linux

```bash
git clone https://github.com/MeldrickV/terminal-anime-es.git
cd terminal-anime-es
chmod +x install.sh
./install.sh
```

Después:

```bash
ani-es
```

### Windows (WSL)

1. En PowerShell: `wsl --install` (reinicia) y luego `wsl --install -d Ubuntu`.
2. Abre Ubuntu, clona e instala igual que en Linux.
3. Instala mpv para Windows desde su [página oficial](https://mpv.io/installation/) y añádelo al PATH.
4. Ejecútalo desde CMD con `wsl ani-es`.

### Termux (Android)

Instala dependencias con `pkg` y usa el script desde el repo; la reproducción abre VLC o el navegador según lo configurado.

### Desinstalar

```bash
./uninstall.sh
```

Pregunta antes de borrar tu historial (`~/ani-es/history.json`).

---

## Uso

```bash
ani-es                  # menú interactivo (pide búsqueda)
ani-es naruto           # busca directo
ani-es -c               # continúa el último anime (con término: -c "one piece")
ani-es -i japones       # explora el catálogo subtitulado
ani-es -i espanol-latino # explora el catálogo con doblaje latino
ani-es -v               # versión
ani-es -h               # ayuda
```

Flujo típico:

```
búsqueda ─▶ elige anime (fzf) ─▶ ver ficha (tipo, idioma, último visto)
   ─▶ elige episodio (fzf o -c) ─▶ mpv desde tu progreso
   ─▶ guarda historial ─▶ siguiente / retroceder / salir
```

---

## Cómo funciona (arquitectura)

Fuente única actual: **jkanime.net**. Todo el flujo vive en `pipeline_jkanime()`.

```
1. BÚSQUEDA        GET /buscar/<termino_con_guiones_bajos>/  (+ excepciones.json remoto)
                      └─ títulos <h5><a> ─▶ fzf ─▶ slug (minúsculas, guiones)
2. FICHA           curl determinista de /<slug>/ ─▶ token CSRF + endpoint ajax
                      └─ POST ajax ─▶ total de episodios ("total": N)
                      └─ tipo (Serie/Película) + idiomas (/idioma/<slug>)
3. EPISODIO        seq 1..N | fzf   (o last_cap con -c; "pelicula" si es film)
4. VIDEO (cascada) ① iframe jkplayer/um → url directa
                   ② iframe /jk.php → url directa
                   ③ var servers → Mediafire → base64 → enlace download
5. REPRODUCIR      mpv --start=<progress> → parsea AV: HH:MM:SS al salir
6. HISTORIAL       save_history() atómico + backup
```

### Funciones principales (`ani-es`)

| Función | Rol |
|---|---|
| `main()` | Bucle principal, flags `-c`/`-i`, reentradas |
| `pipeline_jkanime()` | Búsqueda → ficha → episodio → video |
| `pipeline_idioma()` | Catálogo paginado por idioma, reentra al pipeline |
| `videocap()` / `ir_a_capitulo()` | Cascada de resolución de video |
| `reproducir()` | mpv / VLC / intent según entorno (`detect_env`: linux, wsl, termux) |
| `menu_post_reproduccion()` | Siguiente / retroceder / atrás / salir |
| `init_history()` | Crea, valida y auto-repara `history.json`; migra `history.db` legacy |
| `save_history()` / `get_last_cap()` / `get_progress()` | Lectura/escritura atómica del historial |
| `limpiar_temporales()` + `trap` | Limpieza al salir o con Ctrl+C (con guard anti-subshells) |
| `pagina_siguiente()` / `pagina_anterior()` | Paginación de resultados |

### Historial (`~/ani-es/history.json`)

```json
{
  "Pokemon": {"last_cap": 118, "progress": "00:12:30", "source": "jkanime"},
  "Naruto":  {"last_cap": 5,   "progress": "",         "source": "jkanime"}
}
```

- `progress` vacío = empezar desde el inicio; si no, mpv arranca en ese minuto.
- `history.json.bak`: copia de seguridad de 1 generación antes de cada escritura.
- Archivo vacío o JSON inválido → se regenera solo al arrancar (`init_history`).
- Registros legacy `source: animeflv` se migran a `jkanime` automáticamente.
- Este archivo **no se sube al repo** (ver `.gitignore`): es tu dato personal.

### Idiomas

La ficha del anime lista sus idiomas (`Doblaje latino`, `Subtitulado`, `Castellano`) y cada episodio detecta su pista (`#deflang`). Con `-i <slug>` exploras el catálogo completo de un idioma.

### Red

- `CURL_OPTS="--max-time 25 --retry 2 --fail -s"`, `WGET_OPTS="--timeout=25 --tries=2"` globales.
- Una red caída falla en ~25 s con mensaje; nunca cuelga el programa.

---

## Estructura del repo

```
terminal-anime-es/
├── ani-es                  # el script (≈950 líneas, ejecutable)
├── excepciones.json        # mapa local de slugs (la fuente viva es la remota)
├── install.sh              # dependencias + copia a /usr/local/bin
├── uninstall.sh            # desinstala (pregunta por el historial)
├── README.md               # este archivo
├── LICENSE
└── .github/workflows/
    ├── static.yml          # publica excepciones.json en GitHub Pages
    ├── version.yml         # auto-bump de VERSION según Conventional Commits
    └── snapshot.yml        # vigía semanal del HTML de jkanime (lunes 08:00 UTC)
```

Sin tests automatizados por decisión del proyecto: **el QA es manual** (ver `QA.md` si existe en tu rama de trabajo) con casos testigo fijos: `pokemon` (276 eps, latino), `pokemon-xy` (93, subtitulado), `dragon-ball-z` (291, ambos).

---

## Solución de problemas

| Síntoma | Causa probable / acción |
|---|---|
| "Enlace no válido…" | El slug cambió o la web cambió su HTML: vuelve al menú e inténtalo de nuevo; si persiste, abre un issue con el enlace. |
| No cargan los capítulos | Revisa tu conexión (timeout 25 s); si hay red, el vigía semanal ya habrá avisado del cambio. |
| `history.json` corrupto | Se regenera solo al arrancar; recupera el anterior desde `history.json.bak`. |
| `mpv` no arranca (WSL) | Instala mpv de Windows y añádelo al PATH. |
| Error `jq` al guardar | No toques `history.json` a mano con el programa abierto; restaura el `.bak`. |

---

## Roadmap

- [ ] Selector de fuente múltiple (segunda fuente tipo AnimeFLV como feature nueva).
- [ ] Reintento con backoff exponencial.
- [ ] Modo no interactivo (`--play <anime> <cap>` para scripts).

---

## Contribuir

- Reporta bugs con: anime, enlace, idioma y el paso exacto donde falla.
- Pull requests contra `main` con mensajes Conventional Commits (`fix:`, `feat:`, `docs:`, `ci:`) — el versionado es automático.

## Nota legal

Interfaz CLI para sitios de streaming de terceros. No aloja ni distribuye contenido.

## Licencia

Ver `LICENSE`.
