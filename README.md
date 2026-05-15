# Astro Videos (sitio estatico)

## Abrir la pagina
1. Abre [`index.html`](./index.html) en tu navegador.
2. Opcional: para evitar restricciones del navegador con archivos locales, levanta un servidor simple:
   - `python -m http.server 8080`
   - luego abre `http://localhost:8080`

## Regenerar la data desde tu CSV
Ejecuta:

```powershell
./scripts/build-videos-data.ps1 -CsvPath "c:\Users\manue\Downloads\patreon_astro_v15_FLAG_GENERAL\salida_astro_v15_flag_general\02_colecciones_links_video.csv"
```

Eso vuelve a crear `videos-data.js` con:
- links canonicos `https://www.youtube.com/watch?v=...`
- deduplicacion de URLs repetidas (`youtu.be`, `embed`, `youtube-nocookie`)
- agrupacion por coleccion
