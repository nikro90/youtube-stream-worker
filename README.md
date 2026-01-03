# 🎵 YouTube 24/7 Stream Worker

Este repositorio es el "worker" que ejecuta el streaming 24/7 a YouTube usando GitHub Actions **GRATIS**.

## 🚀 Configuración Rápida

### 1. Configurar Secrets

Ve a **Settings → Secrets and variables → Actions** y agrega:

| Secret | Descripción | Obligatorio |
|--------|-------------|-------------|
| `YOUTUBE_STREAM_KEY` | Tu clave de stream de YouTube | ✅ Sí |
| `STREAM_URL` | URL RTMP (default: `rtmp://a.rtmp.youtube.com/live2`) | ❌ No |
| `OVERLAY_TITLE` | Título del overlay (default: `YouTube Radio 24/7`) | ❌ No |
| `BACKEND_API_URL` | URL de tu backend para reportar status | ❌ No |

### 2. Obtener tu Stream Key de YouTube

1. Ve a [YouTube Studio](https://studio.youtube.com)
2. Click en **Crear** → **Transmitir en vivo**
3. Copia la **Clave de transmisión**

### 3. Iniciar el Stream

**Opción A: Manual**
1. Ve a la pestaña **Actions**
2. Click en **24/7 YouTube Stream**
3. Click en **Run workflow**

**Opción B: Automático**
- El stream se reinicia automáticamente cada 6 horas via cron.

## 📊 Recursos Utilizados

GitHub Actions te da **GRATIS** (en repos públicos):
- 🧠 **7 GB RAM**
- 💻 **2 CPU cores**
- ⏱️ **Minutos ilimitados**

## 🔄 ¿Cómo funciona el 24/7?

1. El workflow se ejecuta por ~5.5 horas
2. Antes de terminar, se "auto-dispara" para iniciar uno nuevo
3. YouTube mantiene el stream unido (puede haber 1-2 segundos de corte)

## ⚠️ Importante

- Este repo debe ser **PÚBLICO** para tener minutos ilimitados
- Tus secrets (Stream Key) están **seguros** y no se exponen
- Si GitHub detecta abuso, pueden suspender la cuenta (raro pero posible)

## 🔗 Conexión con Backend

Este worker puede recibir comandos de tu backend principal via Repository Dispatch:

```bash
curl -X POST \
  -H "Authorization: token TU_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/USUARIO/REPO/dispatches \
  -d '{"event_type":"start-stream"}'
```

## 📁 Estructura

```
├── .github/
│   └── workflows/
│       └── stream.yml    # GitHub Action principal
├── overlay.html          # Visualización del stream
├── stream.js             # Script de streaming
├── package.json          # Dependencias
└── README.md             # Este archivo
```

---
Made with ❤️ for free 24/7 streaming
