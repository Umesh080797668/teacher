# Troubleshooting Guide - Login 500 Error

## Issue
Getting "An error occurred during login" message with 500 Internal Server Error when attempting to login with wrong or correct credentials.

## Root Cause
The issue was related to MongoDB connection handling in Vercel's serverless environment and insufficient error handling in the login endpoint.

## Fixes Applied

### 1. **Serverless MongoDB Connection** ✅
- Implemented connection caching for serverless environment
- Added connection reuse to avoid timeout issues
- Added proper connection state checking before database queries

### 2. **Enhanced Error Handling** ✅
- Added MongoDB connection state validation before login attempts
- Separated error types (400, 401, 403, 500, 503)
- Added comprehensive logging for debugging
- Wrapped bcrypt comparison in try-catch to handle encryption errors

### 3. **Improved Error Messages** ✅
- **400**: Email and password validation errors
- **401**: Invalid email or password
- **403**: Account is not active
- **500**: Authentication/server errors
- **503**: Database connection unavailable

## Deployment Status

The fixes have been pushed to GitHub and will auto-deploy to Vercel.

**Deployment URL**: https://teacher-eight-chi.vercel.app

## Testing Steps

### 1. Wait for Deployment (2-3 minutes)
Check deployment status: https://vercel.com/dashboard

### 2. Test Health Endpoint
```bash
curl https://teacher-eight-chi.vercel.app/api/health
```
Expected response:
```json
{
  "status": "OK",
  "message": "Server is running",
  "timestamp": "2025-12-09T...",
  "mongoStatus": "connected"
}
```

### 3. Test Login with Invalid Credentials
```bash
curl -X POST https://teacher-eight-chi.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"wrong@email.com","password":"wrongpass"}'
```
Expected response (401):
```json
{
  "error": "Invalid email or password"
}
```

### 4. Test Login with Valid Credentials
Use your registered email and password from the mobile app.

## Environment Variables to Check on Vercel

Make sure these are set in your Vercel project settings:

1. **MONGODB_URI** - Your MongoDB connection string
2. **EMAIL_USER** - Gmail account for sending emails
3. **EMAIL_PASS** - Gmail app password

## Common Issues & Solutions

### Issue: Still getting 500 error
**Solution**: 
- Check Vercel logs: https://vercel.com/[your-project]/logs
- Verify MONGODB_URI is set correctly in Vercel environment variables
- Ensure MongoDB database allows connections from Vercel's IP addresses

### Issue: "Database connection unavailable" (503)
**Solution**:
- Check if MongoDB Atlas is running
- Verify MongoDB network access settings allow connections from anywhere (0.0.0.0/0)
- Check if MONGODB_URI includes the correct username, password, and database name

### Issue: "Invalid email or password" for valid credentials
**Solution**:
- Check if teacher account exists in database
- Verify password was hashed with bcrypt during registration
- Check teacher status is "active" in database

## Local Testing

To test locally before deployment:

```bash
cd backend
npm install
node server.js
```

Then test with:
```bash
curl -X POST http://localhost:3004/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpass"}'
```

## Need More Help?

Check the server logs in Vercel dashboard under:
**Your Project → Deployments → [Latest] → Functions Logs**

The enhanced logging will show exactly where the error occurs:
- "Login request received"
- "MongoDB not connected" (if DB issue)
- "Attempting login for email: ..."
- "Database query completed, teacher found: true/false"
- "Password comparison completed, valid: true/false"
