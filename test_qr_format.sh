#!/bin/bash

echo "🔍 Testing QR Code Format on Deployed Backend"
echo "=============================================="
echo ""

echo "1. Generating QR code from backend..."
RESPONSE=$(curl -s -X POST https://teacher-eight-chi.vercel.app/api/web-session/generate-qr \
  -H "Content-Type: application/json" \
  -d '{"userType":"teacher"}')

echo "   Response keys:"
echo "$RESPONSE" | jq 'keys'
echo ""

SESSION_ID=$(echo "$RESPONSE" | jq -r '.sessionId')
QR_CODE=$(echo "$RESPONSE" | jq -r '.qrCode')

echo "   Session ID: $SESSION_ID"
echo ""

# Try to decode the QR code (requires zbarimg)
if command -v zbarimg &> /dev/null; then
    echo "2. Decoding QR code data..."
    # Save QR code to temp file
    echo "$QR_CODE" | sed 's/data:image\/png;base64,//' | base64 -d > /tmp/qr_test.png
    
    # Decode QR
    QR_DATA=$(zbarimg -q --raw /tmp/qr_test.png 2>/dev/null)
    echo "   QR Data: $QR_DATA"
    echo ""
    
    # Parse and pretty print
    echo "   Parsed QR JSON:"
    echo "$QR_DATA" | jq '.'
    echo ""
    
    # Check for type field
    HAS_TYPE=$(echo "$QR_DATA" | jq -r '.type' 2>/dev/null)
    if [ "$HAS_TYPE" = "web-auth" ]; then
        echo "   ✅ QR code has correct 'type: web-auth' field!"
    else
        echo "   ❌ QR code missing 'type' field or has wrong value: $HAS_TYPE"
        echo ""
        echo "   This means the backend QR generation hasn't been updated yet."
        echo "   Vercel needs to redeploy with the latest changes."
    fi
    
    rm -f /tmp/qr_test.png
else
    echo "2. Cannot decode QR - zbarimg not installed"
    echo "   Install with: sudo apt-get install zbar-tools"
    echo ""
    echo "   OR check the backend logs when generating QR:"
    echo "   The console.log should show: 'Generated QR code data: {\"type\":\"web-auth\",...}'"
fi

echo ""
echo "3. Solution:"
echo "   - Wait 2-5 minutes for Vercel to auto-deploy"
echo "   - OR force redeploy from Vercel dashboard"
echo "   - After deployment, REFRESH the web interface page"
echo "   - Generate a NEW QR code"
echo "   - Scan the new QR code with mobile app"
echo ""
echo "=============================================="
