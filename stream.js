/**
 * YouTube 24/7 Stream Worker
 * Designed to run in GitHub Actions
 * 
 * This script:
 * 1. Opens a browser with the visual overlay
 * 2. Plays music from YouTube playlists
 * 3. Captures audio/video and streams to YouTube via FFmpeg
 */

const puppeteer = require('puppeteer');
const { spawn } = require('child_process');
const path = require('path');
const http = require('http');
const fs = require('fs');

// Configuration from environment
const config = {
    streamKey: process.env.YOUTUBE_STREAM_KEY,
    streamUrl: process.env.STREAM_URL || 'rtmp://a.rtmp.youtube.com/live2',
    playlistUrl: process.env.PLAYLIST_URL || '',
    overlayTitle: process.env.OVERLAY_TITLE || 'YouTube Radio 24/7',
    durationHours: parseFloat(process.env.STREAM_DURATION_HOURS) || 5.5,
    backendApiUrl: process.env.BACKEND_API_URL || '',
    localPort: 8080
};

// Validate configuration
if (!config.streamKey) {
    console.error('❌ ERROR: YOUTUBE_STREAM_KEY is required!');
    console.error('Please add it to GitHub Secrets');
    process.exit(1);
}

let browser = null;
let ffmpegProcess = null;
let overlayServer = null;

/**
 * Start local HTTP server for overlay
 */
function startOverlayServer() {
    return new Promise((resolve) => {
        const overlayPath = path.join(__dirname, 'overlay.html');

        overlayServer = http.createServer((req, res) => {
            if (req.url === '/' || req.url === '/overlay.html') {
                fs.readFile(overlayPath, (err, data) => {
                    if (err) {
                        res.writeHead(500);
                        res.end('Error loading overlay');
                        return;
                    }
                    res.writeHead(200, { 'Content-Type': 'text/html' });
                    res.end(data);
                });
            } else {
                res.writeHead(404);
                res.end('Not found');
            }
        });

        overlayServer.listen(config.localPort, () => {
            console.log(`🌐 Overlay server running at http://localhost:${config.localPort}`);
            resolve();
        });
    });
}

/**
 * Launch browser with overlay
 */
async function launchBrowser() {
    console.log('🚀 Launching browser...');

    browser = await puppeteer.launch({
        headless: false,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--disable-gpu',
            '--window-size=1920,1080',
            '--autoplay-policy=no-user-gesture-required',
            '--use-fake-ui-for-media-stream',
            '--enable-audio-service-sandbox=false'
        ],
        defaultViewport: {
            width: 1920,
            height: 1080
        }
    });

    const page = await browser.newPage();

    // Navigate to overlay
    const overlayUrl = `http://localhost:${config.localPort}?title=${encodeURIComponent(config.overlayTitle)}`;
    await page.goto(overlayUrl, { waitUntil: 'networkidle0' });

    console.log('✅ Overlay loaded successfully');

    return page;
}

/**
 * Start FFmpeg streaming process
 */
function startFFmpegStream() {
    console.log('🎬 Starting FFmpeg stream...');

    const rtmpUrl = `${config.streamUrl}/${config.streamKey}`;

    // FFmpeg command for capturing and streaming
    const ffmpegArgs = [
        // Input: X11 display capture
        '-f', 'x11grab',
        '-video_size', '1920x1080',
        '-framerate', '30',
        '-i', ':99',

        // Input: PulseAudio capture
        '-f', 'pulse',
        '-i', 'default',

        // Video encoding
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-tune', 'zerolatency',
        '-b:v', '4500k',
        '-maxrate', '4500k',
        '-bufsize', '9000k',
        '-pix_fmt', 'yuv420p',
        '-g', '60',

        // Audio encoding
        '-c:a', 'aac',
        '-b:a', '128k',
        '-ar', '44100',
        '-ac', '2',

        // Output format
        '-f', 'flv',

        // RTMP destination
        rtmpUrl
    ];

    ffmpegProcess = spawn('ffmpeg', ffmpegArgs);

    ffmpegProcess.stdout.on('data', (data) => {
        console.log(`FFmpeg: ${data}`);
    });

    ffmpegProcess.stderr.on('data', (data) => {
        const msg = data.toString();
        // Only log important FFmpeg messages
        if (msg.includes('frame=') || msg.includes('error') || msg.includes('Error')) {
            console.log(`FFmpeg: ${msg.trim()}`);
        }
    });

    ffmpegProcess.on('error', (error) => {
        console.error('❌ FFmpeg error:', error.message);
    });

    ffmpegProcess.on('close', (code) => {
        console.log(`FFmpeg process exited with code ${code}`);
    });

    console.log('✅ FFmpeg streaming started');
}

/**
 * Report status to backend (optional)
 */
async function reportStatus(status) {
    if (!config.backendApiUrl) return;

    try {
        const response = await fetch(`${config.backendApiUrl}/api/stream-status`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                status,
                timestamp: new Date().toISOString(),
                worker: 'github-actions'
            })
        });
        console.log(`📡 Status reported: ${status}`);
    } catch (error) {
        console.log(`⚠️ Could not report status: ${error.message}`);
    }
}

/**
 * Graceful shutdown
 */
async function shutdown() {
    console.log('🛑 Shutting down...');

    if (ffmpegProcess) {
        ffmpegProcess.kill('SIGTERM');
    }

    if (browser) {
        await browser.close();
    }

    if (overlayServer) {
        overlayServer.close();
    }

    await reportStatus('stopped');

    console.log('👋 Goodbye!');
    process.exit(0);
}

/**
 * Main function
 */
async function main() {
    console.log('═══════════════════════════════════════════');
    console.log('  🎵 YouTube 24/7 Radio - Stream Worker');
    console.log('═══════════════════════════════════════════');
    console.log(`📺 Streaming to: ${config.streamUrl}`);
    console.log(`⏱️ Duration: ${config.durationHours} hours`);
    console.log(`🎨 Overlay title: ${config.overlayTitle}`);
    console.log('═══════════════════════════════════════════\n');

    // Handle shutdown signals
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);

    try {
        // 1. Start overlay server
        await startOverlayServer();

        // 2. Launch browser
        await launchBrowser();

        // 3. Wait a bit for overlay to initialize
        await new Promise(resolve => setTimeout(resolve, 3000));

        // 4. Start FFmpeg streaming
        startFFmpegStream();

        // 5. Report status
        await reportStatus('streaming');

        // 6. Calculate end time
        const durationMs = config.durationHours * 60 * 60 * 1000;
        const endTime = Date.now() + durationMs;

        console.log(`\n🎬 Stream is LIVE!`);
        console.log(`⏰ Will run until: ${new Date(endTime).toISOString()}\n`);

        // 7. Keep running until duration expires
        while (Date.now() < endTime) {
            // Log status every 5 minutes
            const remaining = Math.round((endTime - Date.now()) / 1000 / 60);
            console.log(`⏳ ${remaining} minutes remaining...`);

            // Wait 5 minutes
            await new Promise(resolve => setTimeout(resolve, 5 * 60 * 1000));
        }

        console.log('\n⏰ Duration reached, initiating graceful shutdown...');
        await shutdown();

    } catch (error) {
        console.error('❌ Fatal error:', error);
        await reportStatus('error');
        await shutdown();
    }
}

// Run!
main();
