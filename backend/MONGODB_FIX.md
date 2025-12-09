# MongoDB Connection Test Script

## ✅ Your MongoDB URI Works!

I tested your connection string locally and it connects successfully:
```
mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?appName=teacher
```

## 🔧 Fix Vercel Environment Variables

The issue is that the `MONGODB_URI` is not set correctly in Vercel. Here's how to fix it:

### Step 1: Go to Vercel Dashboard
1. Open https://vercel.com/dashboard
2. Click on your project (should be named something like "teacher" or "teacher-attendance")

### Step 2: Set Environment Variable
1. Click on the **Settings** tab
2. Click on **Environment Variables** in the left sidebar
3. Click **Add New**
4. Enter:
   - **Name**: `MONGODB_URI`
   - **Value**: `mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?appName=teacher`
   - **Environment**: Check all three (Production, Preview, Development)
5. Click **Save**

### Step 3: Redeploy
1. Go to the **Deployments** tab
2. Click on the latest deployment
3. Click the **⋯** (three dots) menu
4. Click **Redeploy**

OR trigger a new deployment by pushing a commit:
```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance"
git commit --allow-empty -m "Trigger redeploy after MongoDB URI fix"
git push origin main
```

### Step 4: Test Connection

Wait 2-3 minutes for deployment, then test:

```bash
# Check health endpoint
curl https://teacher-eight-chi.vercel.app/api/health
```

Should show:
```json
{
  "status": "OK",
  "message": "Server is running",
  "timestamp": "2025-12-09T...",
  "mongoStatus": "connected"
}
```

```bash
# Test login with wrong credentials
curl -X POST https://teacher-eight-chi.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}'
```

Should show:
```json
{
  "error": "Invalid email or password"
}
```

## 🔍 Troubleshooting

### If still showing "disconnected":

1. **Check Vercel Environment Variables**:
   - Make sure the variable name is exactly `MONGODB_URI` (case sensitive)
   - Make sure the value is copied exactly as shown above
   - Make sure it's set for Production environment

2. **Check Vercel Logs**:
   - Go to Vercel Dashboard → Your Project → Deployments
   - Click on latest deployment → Functions tab
   - Look for MongoDB connection errors

3. **Verify MongoDB Atlas**:
   - Go to https://cloud.mongodb.com/
   - Make sure your cluster is running (not paused)
   - Check Network Access allows 0.0.0.0/0

### Common Issues:

- **Wrong environment**: Make sure MONGODB_URI is set for Production
- **Extra spaces**: Copy the URI exactly without extra spaces
- **Case sensitivity**: Variable name must be `MONGODB_URI` (all caps)
- **Cluster paused**: MongoDB Atlas might pause free clusters after inactivity

## 🚀 Quick Test

After setting the environment variable and redeploying, run this command:

```bash
curl https://teacher-eight-chi.vercel.app/api/health | python3 -c "import sys, json; data=json.load(sys.stdin); print('✅ Connected!' if data.get('mongoStatus') == 'connected' else '❌ Still disconnected')"
```

If it shows "✅ Connected!", then your login should work properly!