# Backend Deployment - Database Connection Troubleshooting

## Issue: Database Connection Works Locally But Fails on Hosted Platform

### Root Causes & Solutions

---

## 1. ✅ **Environment Variables Not Configured** (MOST COMMON)

### Problem
Your `.env` file is **NOT deployed** to the hosting platform. Environment variables must be set separately.

### Solution - For Vercel:
1. Go to your Vercel project dashboard
2. Navigate to **Settings** → **Environment Variables**
3. Add the following variables:

```
MONGODB_URI=mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority&appName=teacher
EMAIL_USER=umeshbandara08@gmail.com
EMAIL_PASS=qfxr vmms ieek cjsz
```

4. **Redeploy** your application after adding variables

### Solution - For Other Platforms:
- **Heroku**: Settings → Config Vars
- **Railway**: Variables tab
- **Render**: Environment tab
- **Netlify**: Site settings → Environment variables

---

## 2. ✅ **MongoDB Network Access Restrictions**

### Problem
MongoDB Atlas blocks connections from unknown IP addresses. Serverless platforms use dynamic IPs.

### Solution:
1. Go to [MongoDB Atlas](https://cloud.mongodb.com/)
2. Select your cluster → **Network Access**
3. Click **"Add IP Address"**
4. Choose **"Allow Access from Anywhere"** → This adds `0.0.0.0/0`
5. Click **"Confirm"**

**Note:** For production, you can add specific IP ranges provided by your hosting platform for better security.

---

## 3. ✅ **Connection String Format**

### Updated Connection String
Your connection string has been updated to include recommended parameters:

```
mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority&appName=teacher
```

**Parameters explained:**
- `retryWrites=true`: Automatically retry failed writes
- `w=majority`: Wait for majority of nodes to acknowledge writes
- `appName=teacher`: Application identifier

---

## 4. ✅ **Database User Permissions**

### Verify Your MongoDB User:
1. Go to MongoDB Atlas → **Database Access**
2. Find user `imantha`
3. Ensure it has **"Read and write to any database"** or at least access to `teacher_attendance_mobile`

---

## 5. ✅ **Password Special Characters**

### Problem
If your password contains special characters (`@`, `#`, `$`, etc.), they must be URL-encoded.

### Your Password
Currently: `imanthaumesh` (no special characters - ✅ OK)

If you change it to include special characters, use URL encoding:
- `@` → `%40`
- `#` → `%23`
- `$` → `%24`
- `/` → `%2F`

---

## 6. ✅ **Mongoose Version Compatibility**

Your `package.json` shows: `"mongoose": "^8.0.3"` ✅

This version is compatible with serverless environments.

---

## 7. ✅ **Connection Timeout Settings**

Updated `server.js` with improved settings:

```javascript
serverSelectionTimeoutMS: 10000,  // Increased to 10s
socketTimeoutMS: 45000,
maxPoolSize: 10,
minPoolSize: 1,
```

---

## Debugging Steps

### Step 1: Check Environment Variables
Add this temporary endpoint to check if env vars are loaded:

```javascript
app.get('/debug/env', (req, res) => {
  res.json({
    hasMongoUri: !!process.env.MONGODB_URI,
    nodeEnv: process.env.NODE_ENV,
    // Never log the actual connection string in production!
  });
});
```

### Step 2: Check Logs
View your deployment logs:
- **Vercel**: Project → Deployments → Click deployment → View Logs
- Look for:
  - `MongoDB URI present: true` (should be true)
  - `MongoDB connected successfully`
  - Any error messages

### Step 3: Test Connection
Access your health check endpoint:
```
https://your-app.vercel.app/health
```

Should return:
```json
{
  "status": "OK",
  "mongoStatus": "connected"
}
```

---

## Quick Checklist

Before redeploying, verify:

- [ ] Environment variables set in hosting platform dashboard
- [ ] MongoDB Network Access allows `0.0.0.0/0`
- [ ] Database user has correct permissions
- [ ] Connection string includes `retryWrites=true&w=majority`
- [ ] After setting env vars, you **redeployed** the application
- [ ] Check deployment logs for connection errors

---

## Common Hosting Platform Instructions

### Vercel Deployment:
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
cd backend
vercel --prod
```

### Heroku Deployment:
```bash
# Set environment variables
heroku config:set MONGODB_URI="mongodb+srv://..."
heroku config:set EMAIL_USER="..."
heroku config:set EMAIL_PASS="..."

# Deploy
git push heroku main
```

---

## Still Having Issues?

1. **Check MongoDB Atlas Status**: Visit [status.cloud.mongodb.com](https://status.cloud.mongodb.com/)
2. **Test Connection String Locally**:
   ```bash
   cd backend
   node -e "require('mongoose').connect('YOUR_CONNECTION_STRING').then(() => console.log('OK')).catch(err => console.error(err))"
   ```

3. **Check Deployment Logs** for specific error messages

---

## Contact Support

If issues persist after following all steps:
1. Export your deployment logs
2. Check MongoDB Atlas logs (Cluster → Metrics → Access)
3. Verify network connectivity from your host to MongoDB Atlas
