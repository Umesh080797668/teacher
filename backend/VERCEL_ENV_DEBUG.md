# 🔍 VERCEL ENVIRONMENT VARIABLES TROUBLESHOOTING

## Current Status: ❌ MongoDB Still Disconnected

**Local works ✅ | Vercel fails ❌**

## 📋 Step-by-Step Verification & Fix

---

## 1️⃣ VERIFY: Are Environment Variables Set in Vercel?

### Method A: Check Vercel Dashboard
1. Go to: https://vercel.com/dashboard
2. Find project: **teacher-eight-chi**
3. Click: **Settings** → **Environment Variables**
4. **Verify you see these 3 variables:**
   - ✅ `MONGODB_URI`
   - ✅ `EMAIL_USER`
   - ✅ `EMAIL_PASS`

### Method B: Check via Vercel CLI (if installed)
```bash
vercel env ls --project teacher-eight-chi
```

---

## 2️⃣ VERIFY: Are Variables Set for ALL Environments?

For each variable, make sure **ALL THREE** checkboxes are checked:
- ✅ **Production**
- ✅ **Preview**
- ✅ **Development**

**If any are missing, click "Edit" and check them!**

---

## 3️⃣ VERIFY: Redeploy After Adding Variables

**CRITICAL:** Environment variables only apply to **NEW deployments**.

After adding variables:
1. Go to **Deployments** tab
2. Click **⋯** on latest deployment
3. Click **"Redeploy"**
4. Wait 1-2 minutes

---

## 4️⃣ VERIFY: Check Deployment Logs

1. Go to **Deployments** tab
2. Click on the latest deployment
3. Click **"View Function Logs"**
4. Look for these messages:
   ```
   ✅ MongoDB URI present: true
   ✅ Connecting to MongoDB...
   ✅ MongoDB connected successfully
   ```

   If you see:
   ```
   ❌ MongoDB URI present: false
   ❌ MongoDB connection error
   ```

   → **Environment variables are not loaded!**

---

## 5️⃣ TEST: Use Our Verification Script

```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance/backend"
./verify-deployment.sh
```

---

## 🔧 COMMON MISTAKES & FIXES

### ❌ Mistake 1: Wrong Project
**Problem:** Added variables to old project instead of `teacher-eight-chi`
**Fix:** Check you're in the right project

### ❌ Mistake 2: Missing Environment Checkboxes
**Problem:** Variables only set for "Production" but not "Preview"/"Development"
**Fix:** Edit each variable and check ALL THREE boxes

### ❌ Mistake 3: Didn't Redeploy
**Problem:** Added variables but didn't redeploy
**Fix:** Always redeploy after adding environment variables

### ❌ Mistake 4: Wrong Variable Names
**Problem:** Typos in variable names (case-sensitive!)
**Fix:** Must be exactly:
- `MONGODB_URI` (not `mongo_uri` or `MONGODB_URL`)
- `EMAIL_USER` (not `email_user`)
- `EMAIL_PASS` (not `email_pass`)

### ❌ Mistake 5: Wrong Project Name
**Problem:** Deployed to different Vercel project
**Fix:** Verify the URL is `teacher-eight-chi.vercel.app`

---

## 🚀 QUICK FIX CHECKLIST

- [ ] Go to correct Vercel project: `teacher-eight-chi`
- [ ] Settings → Environment Variables
- [ ] Verify 3 variables exist with exact names
- [ ] Edit each variable → check ALL environment boxes
- [ ] Save changes
- [ ] Deployments tab → Redeploy latest deployment
- [ ] Wait 2 minutes
- [ ] Test: `curl https://teacher-eight-chi.vercel.app/api/health`
- [ ] Should show: `"mongoStatus": "connected"`

---

## 🆘 ADVANCED TROUBLESHOOTING

### If Still Not Working:

1. **Delete and Recreate Variables:**
   - Delete all 3 variables
   - Add them again with correct names and all environments checked

2. **Check Vercel Project Connection:**
   ```bash
   cd backend
   vercel link
   ```
   Make sure it's linked to `teacher-eight-chi`

3. **Force Redeploy:**
   ```bash
   cd backend
   vercel --prod
   ```

4. **Check MongoDB Atlas:**
   - Network Access: Should have `0.0.0.0/0`
   - Database User: `imantha` should have read/write access

---

## 📞 SUPPORT

If you still can't get it working:

1. **Share deployment logs** (the function logs from Vercel)
2. **Confirm project name** you're deploying to
3. **Screenshot** of your Environment Variables page

---

## 🎯 FINAL TEST

After following all steps, run:
```bash
curl https://teacher-eight-chi.vercel.app/api/health
```

**Expected result:**
```json
{
  "status": "OK",
  "mongoStatus": "connected"
}
```

**If you see "disconnected", the environment variables are still not set correctly!**

---

**Remember:** Local works because you have `.env` file. Vercel needs variables set in dashboard!