// Vercel serverless function for checking QR authentication status
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

// MongoDB connection with caching
let cachedConnection = null;

async function connectToDatabase() {
  if (cachedConnection && mongoose.connection.readyState === 1) {
    return cachedConnection;
  }

  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';
  
  try {
    cachedConnection = await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
    });
    return cachedConnection;
  } catch (error) {
    console.error('MongoDB connection error:', error);
    throw error;
  }
}

// WebSession Schema
const WebSessionSchema = new mongoose.Schema({
  sessionId: { type: String, required: true, unique: true },
  userId: { type: mongoose.Schema.Types.ObjectId, refPath: 'userModel' },
  userModel: { type: String, enum: ['Teacher', 'Admin'] },
  userType: { type: String, enum: ['teacher', 'admin'], required: true },
  deviceId: String,
  isActive: { type: Boolean, default: false },
  expiresAt: { type: Date, required: true },
  teacherId: String,
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' },
  ipAddress: String,
  userAgent: String,
  lastActivity: { type: Date, default: Date.now },
  createdAt: { type: Date, default: Date.now },
});

const WebSession = mongoose.models.WebSession || mongoose.model('WebSession', WebSessionSchema);

// Teacher Schema (minimal for population)
const TeacherSchema = new mongoose.Schema({
  name: String,
  email: String,
  phone: String,
  teacherId: String,
  status: String,
  companyIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }],
}, { collection: 'teachers' });

const Teacher = mongoose.models.Teacher || mongoose.model('Teacher', TeacherSchema);

// Admin Schema (minimal for population)
const AdminSchema = new mongoose.Schema({
  name: String,
  email: String,
}, { collection: 'admins' });

const Admin = mongoose.models.Admin || mongoose.model('Admin', AdminSchema);

module.exports = async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow GET
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Connect to database
    await connectToDatabase();
    
    const { sessionId } = req.query;
    
    if (!sessionId) {
      return res.status(400).json({ error: 'Session ID is required' });
    }
    
    const session = await WebSession.findOne({
      sessionId,
      expiresAt: { $gt: new Date() },
    }).populate('userId');
    
    if (!session) {
      return res.status(404).json({ 
        authenticated: false, 
        error: 'Session not found or expired' 
      });
    }
    
    if (session.isActive && session.userId) {
      // Session is authenticated
      const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
      
      console.log('=== JWT Token Generation (check-auth.js) ===');
      console.log('JWT_SECRET exists:', !!process.env.JWT_SECRET);
      console.log('JWT_SECRET length:', jwtSecret.length);
      console.log('Using JWT_SECRET for signing');
      
      const token = jwt.sign(
        {
          sessionId: session.sessionId,
          userId: session.userId._id,
          teacherId: session.userId.teacherId,
          email: session.userId.email,
          userType: session.userType,
        },
        jwtSecret,
        { expiresIn: '24h' }
      );
      
      console.log('✓ Token generated successfully');
      
      return res.status(200).json({
        authenticated: true,
        success: true,
        user: {
          _id: session.userId._id,
          name: session.userId.name,
          email: session.userId.email,
          teacherId: session.userId.teacherId,
          phone: session.userId.phone,
          status: session.userId.status,
          companyIds: session.userId.companyIds,
        },
        session: {
          sessionId: session.sessionId,
          isActive: session.isActive,
          userType: session.userType,
        },
        token,
      });
    }
    
    // Not authenticated yet
    return res.status(200).json({ authenticated: false });
  } catch (error) {
    console.error('Error checking auth status:', error);
    return res.status(500).json({ 
      error: 'Failed to check authentication status',
      message: error.message 
    });
  }
};
