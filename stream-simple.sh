#!/bin/bash

# ============================================================
# YouTube 24/7 Radio - Simple FFmpeg Streaming
# ============================================================
# Streams a static image with audio from YouTube to RTMP
# Uses direct yt-dlp audio streaming without buffering
# ============================================================

set -e

# Configuration from environment variables
STREAM_KEY="${YOUTUBE_STREAM_KEY}"
STREAM_URL="${STREAM_URL:-rtmp://a.rtmp.youtube.com/live2}"
PLAYLIST_URL="${PLAYLIST_URL:-https://www.youtube.com/playlist?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf}"
DURATION_HOURS="${STREAM_DURATION_HOURS:-5.5}"
BACKGROUND_IMAGE="${BACKGROUND_IMAGE:-background.png}"

# Validate required variables
if [ -z "$STREAM_KEY" ]; then
    echo "❌ ERROR: YOUTUBE_STREAM_KEY is required!"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  🎵 YouTube 24/7 Radio - Simple Stream"
echo "═══════════════════════════════════════════"
echo "📺 Stream URL: $STREAM_URL"
echo "🎨 Background: $BACKGROUND_IMAGE"
echo "🎵 Playlist: $PLAYLIST_URL"
echo "⏱️  Duration: ${DURATION_HOURS} hours"
echo "═══════════════════════════════════════════"

# Calculate duration in seconds
DURATION_SECONDS=$(echo "$DURATION_HOURS * 3600" | bc)

# Create RTMP URL
RTMP_FULL="${STREAM_URL}/${STREAM_KEY}"

# Get first video URL from playlist
echo "🔍 Fetching video from playlist..."
VIDEO_URL=$(yt-dlp --flat-playlist --print url "$PLAYLIST_URL" 2>/dev/null | head -n 1)

if [ -z "$VIDEO_URL" ]; then
    echo "❌ No videos found in playlist, trying a public lo-fi stream..."
    # Fallback to a known working lofi stream
    VIDEO_URL="https://www.youtube.com/watch?v=jfKfPfyJRdk"
fi

echo "🎶 Selected video: $VIDEO_URL"

# Get the actual audio stream URL
echo "🔗 Getting audio stream URL..."
AUDIO_URL=$(yt-dlp -f 'bestaudio' --get-url "$VIDEO_URL" 2>/dev/null)

if [ -z "$AUDIO_URL" ]; then
    echo "❌ Could not get audio URL. YouTube may be blocking. Using silent audio."
    USE_SILENT=true
else
    echo "✅ Audio URL obtained"
    USE_SILENT=false
fi

# Start streaming
echo ""
echo "🎬 Starting FFmpeg stream..."
echo "⏰ Will run for ${DURATION_HOURS} hours (${DURATION_SECONDS}s)"
echo ""

if [ "$USE_SILENT" = true ]; then
    # Stream with silent audio (for testing connectivity)
    ffmpeg \
        -re \
        -loop 1 \
        -i "$BACKGROUND_IMAGE" \
        -f lavfi -i anullsrc=r=44100:cl=stereo \
        -c:v libx264 \
        -preset ultrafast \
        -tune stillimage \
        -b:v 1500k \
        -maxrate 2000k \
        -bufsize 3000k \
        -pix_fmt yuv420p \
        -g 60 \
        -c:a aac \
        -b:a 128k \
        -ar 44100 \
        -ac 2 \
        -shortest \
        -f flv \
        -t "$DURATION_SECONDS" \
        "$RTMP_FULL"
else
    # Stream with real audio
    ffmpeg \
        -re \
        -loop 1 \
        -i "$BACKGROUND_IMAGE" \
        -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
        -i "$AUDIO_URL" \
        -c:v libx264 \
        -preset ultrafast \
        -tune stillimage \
        -b:v 1500k \
        -maxrate 2000k \
        -bufsize 3000k \
        -pix_fmt yuv420p \
        -g 60 \
        -c:a aac \
        -b:a 128k \
        -ar 44100 \
        -ac 2 \
        -map 0:v:0 \
        -map 1:a:0 \
        -shortest \
        -f flv \
        -t "$DURATION_SECONDS" \
        "$RTMP_FULL"
fi

echo ""
echo "⏰ Stream ended."
