#!/bin/bash

echo "=== FCM Notification System Verification ==="
echo ""

# Check if firebase-admin is installed
echo "1. Checking firebase-admin installation..."
if npm list firebase-admin > /dev/null 2>&1; then
    echo "✅ firebase-admin package is installed"
else
    echo "❌ firebase-admin package is NOT installed"
    echo "   Run: npm install firebase-admin"
    exit 1
fi
echo ""

# Check if .env file exists
echo "2. Checking .env file..."
if [ -f ".env" ]; then
    echo "✅ .env file exists"
    
    # Check for Firebase variables
    if grep -q "FIREBASE_PROJECT_ID" .env; then
        echo "✅ FIREBASE_PROJECT_ID is set"
    else
        echo "❌ FIREBASE_PROJECT_ID is missing from .env"
    fi
    
    if grep -q "FIREBASE_SERVICE_ACCOUNT" .env; then
        echo "✅ FIREBASE_SERVICE_ACCOUNT is set"
    else
        echo "⚠️  FIREBASE_SERVICE_ACCOUNT is missing from .env"
        echo "   This is required for production deployments"
    fi
else
    echo "❌ .env file does NOT exist"
    echo "   Create one from .env.example"
fi
echo ""

# Check server.js has Firebase code
echo "3. Checking server.js has Firebase integration..."
if grep -q "firebase-admin" server.js; then
    echo "✅ Firebase Admin SDK is initialized in server.js"
else
    echo "❌ Firebase Admin SDK is NOT initialized in server.js"
fi

if grep -q "sendFCMNotificationToTeacher" server.js; then
    echo "✅ Notification sending functions are implemented"
else
    echo "❌ Notification sending functions are NOT implemented"
fi
echo ""

# Check teacher model has fcmToken field
echo "4. Checking Teacher model has fcmToken field..."
if grep -q "fcmToken" server.js; then
    echo "✅ Teacher model includes fcmToken field"
else
    echo "❌ Teacher model does NOT include fcmToken field"
fi
echo ""

echo "=== Verification Summary ==="
echo "All checks completed. Follow the guide in FCM_QUICK_START_TEACHER.md to complete setup."
echo ""
echo "Next Steps:"
echo "1. Get Firebase Service Account from console.firebase.google.com"
echo "2. Add credentials to .env file"
echo "3. Run: npm install && npm start"
echo "4. Test with: POST /api/test/send-notification endpoint"
