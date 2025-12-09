# Fix MongoDB Connection on Vercel

## Current Status
✅ Server is running on Vercel
❌ MongoDB connection is failing
✅ Error handling is working correctly (showing "Database connection unavailable")

## How to Fix

### Step 1: Set MongoDB URI in Vercel

1. Go to https://vercel.com/dashboard
2. Click on your project (likely named `teacher-attendance` or similar)
3. Go to **Settings** tab
4. Click on **Environment Variables** in the left sidebar
5. Add a new environment variable:
   - **Name**: `MONGODB_URI`
   - **Value**: Your MongoDB connection string (see format below)
   - **Environment**: Check all (Production, Preview, Development)
6. Click **Save**

### Step 2: Get MongoDB Connection String

If you're using **MongoDB Atlas**:

1. Go to https://cloud.mongodb.com/
2. Click **Connect** on your cluster
3. Choose **Connect your application**
4. Copy the connection string, it should look like:
   ```
   mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority
   ```
5. Replace `<password>` with your actual database password
6. Replace `<database>` with `teacher_attendance_mobile`

Example:
```
mongodb+srv://myuser:myP@ssw0rd@cluster0.abc123.mongodb.net/teacher_attendance_mobile?retryWrites=true&w=majority
```

### Step 3: Configure MongoDB Atlas Network Access

1. In MongoDB Atlas, go to **Network Access** (left sidebar)
2. Click **Add IP Address**
3. Choose **Allow Access from Anywhere** (0.0.0.0/0)
4. Click **Confirm**

**Note**: For production, you should restrict to Vercel's IPs, but for testing, allow from anywhere.

### Step 4: Redeploy on Vercel

After setting the environment variable:

1. Go to your Vercel project **Deployments** tab
2. Click on the latest deployment
3. Click the **⋯** (three dots) menu
4. Click **Redeploy**

OR simply push another commit:
```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance"
git commit --allow-empty -m "Trigger Vercel redeploy"
git push origin main
```

### Step 5: Test the Connection

Wait 2-3 minutes for deployment, then test:

```bash
# Check health endpoint
curl https://teacher-ebon.vercel.app/api/health

# Should show: "mongoStatus": "connected"
```

```bash
# Test login
curl -X POST https://teacher-ebon.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}'

# Should show: "Invalid email or password" (401) instead of 500 error
```

## Alternative: Use Local MongoDB for Testing

If you want to test locally first:

1. Create a `.env` file in the backend folder:
   ```env
   MONGODB_URI=mongodb://localhost:27017/teacher_attendance_mobile
   EMAIL_USER=your-email@gmail.com
   EMAIL_PASS=your-app-password
   ```

2. Make sure MongoDB is running locally:
   ```bash
   sudo systemctl start mongod
   ```

3. Run the server locally:
   ```bash
   cd backend
   npm install
   node server.js
   ```

4. Test locally:
   ```bash
   curl http://localhost:3004/api/health
   ```

## Troubleshooting

### Issue: Still shows "disconnected"
- Double-check the MONGODB_URI is exactly correct (no spaces, correct password)
- Verify MongoDB Atlas cluster is running (not paused)
- Check MongoDB Atlas allows connections from 0.0.0.0/0

### Issue: "Authentication failed" in MongoDB
- Password in connection string might be wrong
- Username might not have permissions
- Create a new database user in MongoDB Atlas with read/write permissions

### Issue: Connection string format error
Make sure it follows this exact format:
```
mongodb+srv://<user>:<pass>@<cluster>.mongodb.net/<dbname>?retryWrites=true&w=majority
```

## Need Help?

Check Vercel function logs for detailed error messages:
1. Go to Vercel Dashboard → Your Project
2. Click **Deployments** → Latest deployment
3. Click **Functions** tab
4. Click on any function to see logs
5. Look for "MongoDB connection error" messages
