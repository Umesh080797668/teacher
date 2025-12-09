# 🔧 UPDATE VERCEL ENVIRONMENT VARIABLE

## Current Issue: Incomplete MongoDB Connection String

**MongoDB Atlas gave you:**
```
mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/?appName=teacher
```

**But you need this complete version:**
```
mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority&appName=teacher
```

## 📝 What Changed

| Part | Atlas Default | What You Need |
|------|---------------|---------------|
| Database | Missing | `/teacher_attendance_mobile` |
| Parameters | `?appName=teacher` | `?retryWrites=true&w=majority&appName=teacher` |

## 🚀 UPDATE IN VERCEL

### Step 1: Go to Vercel Dashboard
- Visit: https://vercel.com/dashboard
- Find project: **teacher-eight-chi**
- Click: **Settings** → **Environment Variables**

### Step 2: Edit MONGODB_URI
- Find the `MONGODB_URI` variable
- Click **"Edit"**
- **Replace the value** with:

```
mongodb+srv://imantha:imanthaumesh@teacher.vnkyd3n.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority&appName=teacher
```

### Step 3: Ensure All Environments
- ✅ **Production** checked
- ✅ **Preview** checked
- ✅ **Development** checked

### Step 4: Save & Redeploy
- Click **"Save"**
- Go to **Deployments** tab
- Click **⋯** on latest deployment
- Click **"Redeploy"**
- Wait 1-2 minutes

## 🧪 TEST AFTER UPDATE

```bash
# Test health
curl https://teacher-eight-chi.vercel.app/api/health

# Should now show:
{
  "status": "OK",
  "mongoStatus": "connected"
}
```

## 📋 WHY THESE PARAMETERS MATTER

- **`/teacher_attendance_mobile`** - Specifies which database to connect to
- **`retryWrites=true`** - Automatically retry failed writes (important for serverless)
- **`w=majority`** - Wait for majority of nodes to acknowledge writes
- **`appName=teacher`** - Application identifier for monitoring

## ⚠️ IMPORTANT

**The connection string from MongoDB Atlas dashboard is incomplete for your use case.** You need to add the database name and connection parameters for serverless environments.

## 🎯 FINAL CHECKLIST

- [ ] Updated `MONGODB_URI` in Vercel with complete connection string
- [ ] All environments checked (Production, Preview, Development)
- [ ] Redeployed after updating
- [ ] Tested with health endpoint
- [ ] MongoDB shows "connected"

---

**After updating the connection string and redeploying, your MongoDB should connect successfully!** 🚀