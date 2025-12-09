#!/bin/bash

echo "🔍 Testing MongoDB connection on Vercel..."
echo ""

# Test health endpoint
echo "📡 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s https://teacher-ebon.vercel.app/api/health)

if [ $? -eq 0 ]; then
    echo "✅ Health endpoint responded"
    echo "$HEALTH_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    mongo_status = data.get('mongoStatus', 'unknown')
    if mongo_status == 'connected':
        print('✅ MongoDB is CONNECTED!')
    else:
        print('❌ MongoDB status:', mongo_status)
except:
    print('❌ Invalid JSON response')
    print('Response:', sys.stdin.read())
"
else
    echo "❌ Health endpoint failed"
fi

echo ""
echo "🔐 Testing login endpoint..."

# Test login with wrong credentials
LOGIN_RESPONSE=$(curl -s -X POST https://teacher-ebon.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}')

if [ $? -eq 0 ]; then
    echo "✅ Login endpoint responded"
    echo "$LOGIN_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    error = data.get('error', '')
    if 'Invalid email or password' in error:
        print('✅ Login validation working correctly!')
    elif 'Database connection unavailable' in error:
        print('❌ MongoDB still not connected')
    elif 'error' in data:
        print('⚠️  Unexpected error:', error)
    else:
        print('❓ Unexpected response:', data)
except:
    print('❌ Invalid JSON response')
    print('Response:', sys.stdin.read())
"
else
    echo "❌ Login endpoint failed"
fi

echo ""
echo "📋 Summary:"
echo "- If MongoDB shows 'connected' and login shows 'Invalid email or password', you're all set!"
echo "- If MongoDB shows 'disconnected', check Vercel environment variables"
echo "- If you see 500 errors, there might be other issues"