# 🚨 URGENT: Set Environment Variables in New Vercel Project

## Current Status: ❌ MongoDB Still Disconnected

Your new backend URL `https://teacher-eight-chi.vercel.app` is running but **MongoDB is still disconnected**.

## 🔧 IMMEDIATE FIX: Add Environment Variables

### Step 1: Go to New Vercel Project
1. Visit: **https://vercel.com/dashboard**
2. Find your new project: **teacher-eight-chi** (or whatever the new project name is)
3. Click on it

### Step 2: Add Environment Variables
1. Click **Settings** tab (top right)
2. Click **Environment Variables** (left sidebar)
3. Click **"Add New"** button

### Step 3: Add These Variables (Copy-Paste)

**Variable 1:**
```
Name: MONGODB_URI
Value: mongodb+srv://umesh:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority&appName=teacher
Environments: ✅ Production ✅ Preview ✅ Development
```

**Variable 2:**
```
Name: EMAIL_USER
Value: umeshbandara08@gmail.com
Environments: ✅ Production ✅ Preview ✅ Development
```

**Variable 3:**
```
Name: EMAIL_PASS
Value: qfxr vmms ieek cjsz
Environments: ✅ Production ✅ Preview ✅ Development
```

### Step 4: Redeploy
After adding all variables:
- Go to **Deployments** tab
- Click the **three dots (⋯)** on the latest deployment
- Click **"Redeploy"**

### Step 5: Verify Fix
Run this command after redeployment:
```bash
curl https://teacher-eight-chi.vercel.app/api/health
```

Should show:
```json
{
  "status": "OK",
  "mongoStatus": "connected"  ← This should say "connected"!
}
```

---

## 📋 Checklist

- [ ] Found new Vercel project (teacher-eight-chi)
- [ ] Added MONGODB_URI for all environments
- [ ] Added EMAIL_USER for all environments
- [ ] Added EMAIL_PASS for all environments
- [ ] Clicked "Save" for each variable
- [ ] Redeployed the application
- [ ] Waited 1-2 minutes for deployment
- [ ] Tested with curl command above

---

## 🆘 If Still Not Working

1. **Check deployment logs:**
   - Vercel → Deployments → Click latest deployment → View Function Logs
   - Look for: `MongoDB URI present: true`

2. **Verify environment variables are saved:**
   - Settings → Environment Variables
   - Should see all 3 variables listed

3. **Make sure you redeployed AFTER adding variables**
   - Variables only apply to NEW deployments

---

## 📞 Your New Backend URL
https://teacher-eight-chi.vercel.app

## 🏥 Health Check Endpoint
https://teacher-eight-chi.vercel.app/api/health

---

**CRITICAL:** Do NOT proceed with the Flutter app until MongoDB shows "connected"! The app will crash if the database isn't working.