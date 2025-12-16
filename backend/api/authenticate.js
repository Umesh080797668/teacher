// Vercel serverless function for authenticating QR codes (mobile app endpoint)
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

// Teacher Schema
const TeacherSchema = new mongoose.Schema({
  name: String,
  email: String,
  phone: String,
  teacherId: String,
  status: String,
  companyIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }],
}, { collection: 'teachers' });

const Teacher = mongoose.models.Teacher || mongoose.model('Teacher', TeacherSchema);

module.exports = async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Connect to database
    await connectToDatabase();
    
    // Parse body if needed (Vercel sometimes doesn't auto-parse)
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (e) {
        body = {};
      }
    }
    
    const { sessionId, teacherId, deviceId } = body || {};
    
    console.log('=== Web Session Authentication Request ===');
    console.log('Session ID:', sessionId);
    console.log('Teacher ID:', teacherId);
    console.log('Device ID:', deviceId);
    console.log('Request timestamp:', new Date().toISOString());
    
    // Validate input
    if (!sessionId || !teacherId) {
      console.log('ERROR: Missing required fields');
      console.log('sessionId present:', !!sessionId);
      console.log('teacherId present:', !!teacherId);
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required fields' 
      });
    }
    
    // Find the teacher by teacherId field (not MongoDB _id)
    console.log('Looking for teacher in database...');
    const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
    
    if (!teacher) {
      console.log('ERROR: Teacher not found for teacherId:', teacherId);
      return res.status(404).json({ 
        success: false, 
        message: 'Teacher not found' 
      });
    }
    
    console.log('✓ Teacher found:', teacher.name, '(ID:', teacher.teacherId, ')');
    
    // Check if this device already has an active session for this teacher
    const existingSession = await WebSession.findOne({
      teacherId: teacher.teacherId,
      deviceId: deviceId,
      isActive: true,
      expiresAt: { $gt: new Date() },
    });
    
    if (existingSession) {
      console.log('✓ Found existing session for this device, updating it');
      console.log('Existing session ID:', existingSession.sessionId);
      
      // Update the existing session instead of creating new one
      existingSession.lastActivity = new Date();
      existingSession.ipAddress = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || '').split(',')[0].trim() || 'unknown';
      existingSession.userAgent = req.headers['user-agent'] || 'unknown';
      await existingSession.save();
      
      // Now find and update the new session that was just scanned
      const newSession = await WebSession.findOne({
        sessionId,
        expiresAt: { $gt: new Date() },
      });
      
      if (newSession) {
        // Activate the new scanned session as well
        newSession.userId = teacher._id;
        newSession.userModel = 'Teacher';
        newSession.teacherId = teacher.teacherId;
        newSession.isActive = true;
        newSession.deviceId = deviceId || 'mobile-app';
        newSession.ipAddress = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || '').split(',')[0].trim() || 'unknown';
        newSession.userAgent = req.headers['user-agent'] || 'unknown';
        newSession.lastActivity = new Date();
        await newSession.save();
        console.log('✓ New scanned session also activated');
      }
      
      // Generate JWT token for the mobile app
      const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
      
      console.log('=== JWT Token Generation (mobile auth - existing session) ===');
      console.log('JWT_SECRET exists:', !!process.env.JWT_SECRET);
      console.log('JWT_SECRET length:', jwtSecret.length);
      
      const token = jwt.sign(
        {
          userId: teacher._id.toString(),
          teacherId: teacher.teacherId,
          email: teacher.email,
          companyIds: teacher.companyIds,
          userType: 'teacher',
        },
        jwtSecret,
        { expiresIn: '24h' }
      );
      
      console.log('✓ JWT token generated for teacher:', teacher.teacherId);
      
      return res.json({
        success: true,
        message: 'Authentication successful (existing session updated)',
        sessionId: existingSession.sessionId,
        token,
        teacher: {
          id: teacher._id,
          name: teacher.name,
          email: teacher.email,
          companyIds: teacher.companyIds,
        },
      });
    }
    
    // Find the web session
    console.log('Looking for session in database...');
    const session = await WebSession.findOne({
      sessionId,
      expiresAt: { $gt: new Date() },
    });
    
    if (!session) {
      console.log('ERROR: Session not found or expired');
      console.log('Searched for sessionId:', sessionId);
      console.log('Current time:', new Date().toISOString());
      return res.status(404).json({ 
        success: false, 
        message: 'Session not found or expired' 
      });
    }
    
    console.log('✓ Session found:', session.sessionId);
    console.log('Session details:', {
      sessionId: session.sessionId,
      companyId: session.companyId,
      isActive: session.isActive,
      currentUserId: session.userId,
      currentDeviceId: session.deviceId,
      expiresAt: session.expiresAt,
    });
    
    // Check if session is already authenticated with a different device
    if (session.isActive && session.userId && session.deviceId) {
      console.log('⚠ Session already authenticated!');
      console.log('Current device:', session.deviceId);
      console.log('Requesting device:', deviceId);
      
      if (session.deviceId !== deviceId) {
        console.log('WARN: Session already authenticated on different device - allowing re-authentication');
      } else {
        console.log('✓ Same device attempting to re-authenticate');
      }
    }
    
    console.log('Teacher details:', {
      _id: teacher._id,
      name: teacher.name,
      email: teacher.email,
      teacherId: teacher.teacherId,
      status: teacher.status,
      companyIds: teacher.companyIds,
    });
    
    // Add companyId to teacher's array if not already present
    console.log('=== COMPANY ASSOCIATION LOGIC ===');
    if (session.companyId) {
      console.log('Session has companyId:', session.companyId.toString());
      
      if (!teacher.companyIds) {
        teacher.companyIds = [];
        console.log('✓ Initializing companyIds array for teacher');
      } else {
        console.log('Teacher current companyIds:', teacher.companyIds.map(id => id.toString()));
      }
      
      const companyIdStr = session.companyId.toString();
      const hasCompany = teacher.companyIds.some(id => id.toString() === companyIdStr);
      console.log('Does teacher already have this company?', hasCompany);
      
      if (!hasCompany) {
        console.log('➜ Adding company to teacher:', companyIdStr);
        teacher.companyIds.push(session.companyId);
        
        try {
          await teacher.save();
          console.log(`✓✓✓ SUCCESS: Teacher ${teacherId} added to company ${companyIdStr}`);
          console.log(`✓ Teacher now belongs to ${teacher.companyIds.length} compan${teacher.companyIds.length === 1 ? 'y' : 'ies'}`);
          console.log('✓ Updated companyIds:', teacher.companyIds.map(id => id.toString()));
        } catch (saveError) {
          console.error('❌ ERROR saving teacher with new companyId:', saveError);
          throw saveError;
        }
      } else {
        console.log(`✓ Teacher ${teacherId} already belongs to company ${companyIdStr}`);
      }
      console.log('Final teacher companies:', teacher.companyIds.map(id => id.toString()));
    } else {
      console.log('⚠ No companyId in session (teacher login without company)');
    }
    console.log('=== END COMPANY ASSOCIATION LOGIC ===');
    
    // Update session with teacher info and device metadata
    console.log('Updating session with authentication details...');
    session.userId = teacher._id;
    session.userModel = 'Teacher';
    session.teacherId = teacher.teacherId;
    session.isActive = true;
    session.deviceId = deviceId || 'mobile-app';
    session.ipAddress = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || '').split(',')[0].trim() || 'unknown';
    session.userAgent = req.headers['user-agent'] || 'unknown';
    session.lastActivity = new Date();
    
    await session.save();
    
    console.log('✓ SUCCESS: Session updated and activated');
    console.log('Final session state:', {
      sessionId: session.sessionId,
      userId: session.userId,
      isActive: session.isActive,
      teacherId: session.teacherId,
      companyId: session.companyId,
      deviceId: session.deviceId,
      ipAddress: session.ipAddress,
    });
    
    // Generate JWT token for the mobile app
    const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
    
    console.log('=== JWT Token Generation (mobile auth) ===');
    console.log('JWT_SECRET exists:', !!process.env.JWT_SECRET);
    console.log('JWT_SECRET length:', jwtSecret.length);
    
    const token = jwt.sign(
      {
        userId: teacher._id.toString(),
        teacherId: teacher.teacherId,
        email: teacher.email,
        companyIds: teacher.companyIds,
        userType: 'teacher',
      },
      jwtSecret,
      { expiresIn: '24h' }
    );
    
    console.log('✓ JWT token generated for teacher:', teacher.teacherId);
    
    return res.status(200).json({
      success: true,
      message: 'Authentication successful',
      sessionId,
      token,
      teacher: {
        id: teacher._id,
        name: teacher.name,
        email: teacher.email,
        companyIds: teacher.companyIds,
      },
    });
  } catch (error) {
    console.error('❌ ERROR in web-session authentication:', error);
    console.error('Error stack:', error.stack);
    return res.status(500).json({ 
      success: false, 
      message: 'Authentication failed: ' + error.message 
    });
  }
};
