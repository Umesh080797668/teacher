# 🚀 FIX: Vercel MongoDB Connection Issue

## Current Problem
✅ MongoDB works locally  
✅ IP `0.0.0.0/0` is whitelisted  
❌ Vercel deployment shows: `"mongoStatus":"disconnected"`

**Root Cause:** Environment variables are NOT set in Vercel

---

## 🎯 SOLUTION: Add Environment Variables to Vercel

### Step-by-Step Instructions:

#### 1️⃣ Open Vercel Dashboard
Go to: **https://vercel.com**

Login and find your project: **backend**

#### 2️⃣ Navigate to Settings
- Click on your **backend** project
- Click **Settings** tab (top right)
- Click **Environment Variables** (left sidebar)

#### 3️⃣ Add These 3 Variables

Click **"Add New"** for each variable:

**Variable 1:**
```
Name: MONGODB_URI
Value: mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority&appName=teacher
Environments: ✅ Production ✅ Preview ✅ Development (SELECT ALL!)
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

⚠️ **IMPORTANT:** Make sure to check ALL THREE environment checkboxes (Production, Preview, Development) for EACH variable!

#### 4️⃣ Redeploy Your Application

After adding all variables:
- Go to **Deployments** tab
- Find the latest deployment
- Click the **three dots (⋯)** menu
- Click **"Redeploy"**

⏱️ Wait 1-2 minutes for deployment to complete

#### 5️⃣ Verify It's Fixed

Run this command in terminal:
```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance/backend"
./verify-deployment.sh
```

Or test manually:
```bash
curl https://teacher-ebon.vercel.app/api/health
```

You should see:
```json
{
  "status": "OK",
  "mongoStatus": "connected"  ← Should say "connected"!
}
```

---

## 📸 Visual Guide

### Where to find Environment Variables in Vercel:
```
Vercel Dashboard
  └─ Your Project (backend)
      └─ Settings (top tab)
          └─ Environment Variables (left sidebar)
              └─ "Add New" button
```

### What it should look like after adding:
```
✅ MONGODB_URI    |  Production, Preview, Development
✅ EMAIL_USER     |  Production, Preview, Development  
✅ EMAIL_PASS     |  Production, Preview, Development
```

---

## 🔍 Why This Happens

1. **.env files are NOT deployed** to Vercel (they're in `.gitignore`)
2. Environment variables must be set in Vercel's dashboard
3. After adding env vars, you MUST redeploy for them to take effect
4. This is a security feature - sensitive data shouldn't be in git

---

## ✅ Checklist

Before running verify script:

- [ ] Logged into Vercel dashboard
- [ ] Found backend project
- [ ] Added MONGODB_URI (with ALL 3 checkboxes)
- [ ] Added EMAIL_USER (with ALL 3 checkboxes)
- [ ] Added EMAIL_PASS (with ALL 3 checkboxes)
- [ ] Clicked "Save" for each variable
- [ ] Triggered redeploy from Deployments tab
- [ ] Waited for deployment to complete (green checkmark)

---

## 🆘 Still Not Working?

1. **Check deployment logs:**
   - Vercel → Deployments → Click latest deployment → View Function Logs
   - Look for: `MongoDB URI present: true`

2. **Verify environment variables are saved:**
   - Settings → Environment Variables
   - Should see all 3 variables listed

3. **Make sure you redeployed AFTER adding variables**
   - Variables only apply to NEW deployments
   - Old deployments won't have them

4. **Test connection string separately:**
   ```bash
   node -e "require('mongoose').connect('YOUR_URI').then(() => console.log('✅ OK')).catch(e => console.error('❌', e.message))"
   ```

---

## 📞 Your Deployment URL
https://teacher-ebon.vercel.app

## 🏥 Health Check Endpoint
https://teacher-ebon.vercel.app/api/health

---

**After following these steps, your MongoDB connection should work perfectly on Vercel!** 🎉
