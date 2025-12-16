#!/bin/bash

# Restart Backend Server Script
# This script stops any running backend server and starts a new one

echo "🛑 Stopping existing backend server..."
pkill -f "node.*backend/server.js" || true
pkill -f "node.*server.js" || true
sleep 2

echo "🚀 Starting backend server..."
cd "$(dirname "$0")/backend"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

echo "✅ Starting server on port 3004..."
nohup node server.js > server.log 2>&1 &
echo "Server started with PID $!"

