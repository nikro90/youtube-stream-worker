#!/bin/bash

# ============================================================
# YouTube 24/7 Radio - Simple FFmpeg Streaming
# ============================================================
# This script streams audio from a YouTube playlist with a 
# static background image to RTMP (YouTube/Twitch)
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

# Create a named pipe for audio streaming
AUDIO_PIPE="/tmp/audio_pipe"
rm -f $AUDIO_PIPE
mkfifo $AUDIO_PIPE

# Function to continuously stream audio from YouTube playlist
stream_audio() {
    echo "🎵 Starting audio streamer..."
    while true; do
        # Get random video from playlist and stream audio
        yt-dlp \
            --flat-playlist \
            --print url \
            "$PLAYLIST_URL" 2>/dev/null | \
        shuf | \
        while read -r video_url; do
            echo "🎶 Now playing: $video_url"
            yt-dlp \
                -f 'bestaudio' \
                -o - \
                "$video_url" 2>/dev/null || continue
        done
    done > $AUDIO_PIPE &
    AUDIO_PID=$!
    echo "🎵 Audio streamer PID: $AUDIO_PID"
}

# Function to stream video + audio to RTMP
stream_video() {
    echo "🎬 Starting FFmpeg stream..."
    
    ffmpeg \
        -re \
        -loop 1 \
        -i "$BACKGROUND_IMAGE" \
        -i $AUDIO_PIPE \
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
        -t $DURATION_SECONDS \
        "$RTMP_FULL" &
    
    FFMPEG_PID=$!
    echo "🎬 FFmpeg PID: $FFMPEG_PID"
}

# Cleanup function
cleanup() {
    echo "🛑 Shutting down..."
    kill $AUDIO_PID 2>/dev/null || true
    kill $FFMPEG_PID 2>/dev/null || true
    rm -f $AUDIO_PIPE
    echo "👋 Goodbye!"
}

trap cleanup EXIT INT TERM

# Start streaming
stream_audio
sleep 2
stream_video

echo ""
echo "🎬 Stream is LIVE!"
echo "⏰ Will run for ${DURATION_HOURS} hours"
echo ""

# Wait for FFmpeg to finish
wait $FFMPEG_PID

echo "⏰ Duration reached, shutting down..."
