#!/bin/bash

echo "🔍 QR Code Format Issue - Troubleshooting Script"
echo "=================================================="
echo ""

# Check if backend server is running locally
echo "1. Checking for local backend server..."
if pgrep -f "node.*backend/server.js" > /dev/null; then
    echo "✅ Local backend server is running"
    echo "   💡 You need to RESTART it to apply the fix!"
    echo ""
    echo "   Run these commands:"
    echo "   cd backend"
    echo "   pkill -f 'node.*server.js'"
    echo "   node server.js"
    echo ""
else
    echo "❌ No local backend server found"
    echo "   You're probably using Vercel deployment"
    echo ""
fi

echo "2. Checking Vercel deployment status..."
echo "   🌐 Your backend URL: https://teacher-eight-chi.vercel.app"
echo ""
echo "   The code has been pushed to GitHub, but Vercel needs to redeploy."
echo ""
echo "   Options:"
echo "   A) Wait 2-5 minutes for automatic deployment"
echo "   B) Force redeploy from Vercel dashboard"
echo "   C) Check deployment logs at: https://vercel.com/dashboard"
echo ""

echo "3. Testing current QR format..."
echo "   Testing the /api/web-session/generate-qr endpoint..."
echo ""

# Test the endpoint
RESPONSE=$(curl -s -X POST https://teacher-eight-chi.vercel.app/api/web-session/generate-qr \
  -H "Content-Type: application/json" \
  -d '{"userType":"teacher"}' 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "   ✅ Endpoint is reachable"
    
    # Try to decode the QR code data (if jq is available)
    if command -v jq &> /dev/null; then
        QR_DATA=$(echo "$RESPONSE" | jq -r '.qrCode' 2>/dev/null | sed 's/data:image\/png;base64,//' | base64 -d 2>/dev/null)
        echo "   Response received (see below for details)"
        echo ""
        echo "   📊 Backend Response:"
        echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    else
        echo "   Response received but cannot parse (install jq for details)"
    fi
else
    echo "   ❌ Cannot reach endpoint"
    echo "   Check your internet connection"
fi

echo ""
echo "4. What the QR code SHOULD contain:"
echo "   ✅ Correct format:"
echo '   {"type":"web-auth","sessionId":"...","expiresAt":1234567890,"userType":"teacher"}'
echo ""
echo "   ❌ Old (wrong) format:"
echo '   {"sessionId":"...","userType":"teacher","timestamp":1234567890}'
echo ""

echo "5. Quick Fix Options:"
echo ""
echo "   Option A: Wait for Vercel auto-deployment (2-5 minutes)"
echo "   ✓ No action needed, just wait"
echo ""
echo "   Option B: Run local backend server"
echo "   ✓ cd backend && node server.js"
echo "   ✓ Update ApiService.baseUrl to http://localhost:3004"
echo ""
echo "   Option C: Force Vercel redeploy"
echo "   ✓ Go to https://vercel.com/dashboard"
echo "   ✓ Find your project"
echo "   ✓ Click 'Redeploy'"
echo ""

echo "6. Verify the fix:"
echo "   After backend is updated, generate a NEW QR code on web interface"
echo "   Then scan it with the app - you should see:"
echo '   "Parsed QR JSON: {type: web-auth, ...}"'
echo ""

echo "=================================================="
echo "For more help, see QR_FORMAT_FIX.md"
