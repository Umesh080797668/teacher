// Vercel serverless function for generating QR codes
const mongoose = require('mongoose');
const QRCode = require('qrcode');
const { v4: uuidv4 } = require('uuid');

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
  createdAt: { type: Date, default: Date.now },
});

WebSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const WebSession = mongoose.models.WebSession || mongoose.model('WebSession', WebSessionSchema);

module.exports = async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
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
    
    const { userType = 'teacher' } = req.body;
    const sessionId = uuidv4();
    const expiresAt = new Date(Date.now() + (5 * 60 * 1000)); // 5 minutes
    
    // Create web session
    const webSession = new WebSession({
      sessionId,
      userType,
      isActive: false, // Will be activated when scanned
      expiresAt,
    });
    
    await webSession.save();
    
    // Generate QR code
    const qrData = JSON.stringify({
      sessionId,
      userType,
      timestamp: Date.now(),
    });
    
    const qrCode = await QRCode.toDataURL(qrData);
    
    return res.status(200).json({
      sessionId,
      qrCode,
      expiresAt: expiresAt.getTime(),
    });
  } catch (error) {
    console.error('Error generating QR code:', error);
    return res.status(500).json({ 
      error: 'Failed to generate QR code',
      message: error.message 
    });
  }
};
