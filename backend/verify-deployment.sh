#!/bin/bash

echo "🔍 Verifying Vercel Deployment..."
echo "=================================="
echo ""

# Test health endpoint
echo "1️⃣ Testing Health Endpoint..."
HEALTH=$(curl -s https://teacher-eight-chi.vercel.app/api/health)
echo "Response: $HEALTH"
echo ""

# Check MongoDB status
MONGO_STATUS=$(echo $HEALTH | grep -o '"mongoStatus":"[^"]*"' | cut -d'"' -f4)
echo "📊 MongoDB Status: $MONGO_STATUS"
echo ""

if [ "$MONGO_STATUS" = "connected" ]; then
    echo "✅ SUCCESS! MongoDB is connected!"
    echo ""
    echo "Your backend is working correctly!"
else
    echo "❌ FAILED! MongoDB is disconnected"
    echo ""
    echo "📝 To Fix:"
    echo "1. Go to: https://vercel.com/dashboard"
    echo "2. Find project: teacher-eight-chi"
    echo "3. Click: Settings → Environment Variables"
    echo "4. Add these variables for ALL environments:"
    echo ""
    echo "   MONGODB_URI = mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority&appName=teacher"
    echo "   EMAIL_USER = umeshbandara08@gmail.com"
    echo "   EMAIL_PASS = qfxr vmms ieek cjsz"
    echo ""
    echo "5. Redeploy from Deployments tab"
    echo ""
fi

echo "=================================="
