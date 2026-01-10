const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
const http = require('http');
const socketIo = require('socket.io');
const QRCode = require('qrcode');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
const cloudinary = require('cloudinary').v2;
const admin = require('firebase-admin');
require('dotenv').config();

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

// Initialize Firebase Admin SDK
// Try to initialize with credentials from environment variable
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase Admin SDK initialized with service account credentials');
  } catch (error) {
    console.error('Failed to initialize Firebase with service account:', error.message);
    // Try to use default credentials (useful for local development or Cloud Run)
    try {
      admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'eduverse-teacher-app'
      });
      console.log('Firebase Admin SDK initialized with default credentials');
    } catch (err) {
      console.error('Failed to initialize Firebase Admin SDK:', err.message);
    }
  }
} else {
  // Use default credentials (Application Default Credentials)
  try {
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'eduverse-teacher-app'
    });
    console.log('Firebase Admin SDK initialized with Application Default Credentials');
  } catch (error) {
    console.error('Failed to initialize Firebase Admin SDK:', error.message);
  }
}

const app = express();

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: true,
    credentials: true,
  }
});
const PORT = process.env.PORT || 3004;

// Trust proxy for correct IP addresses (important for Vercel deployment)
app.set('trust proxy', true);

// Middleware
app.use(cors({
  origin: true, // Allow all origins
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Additional CORS headers for Vercel
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Credentials', 'true');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  next();
});

app.use(express.json());

// Configure multer for file uploads (store in memory, don't save to disk)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept only image files
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg'];
    const isImageMime = file.mimetype && file.mimetype.startsWith('image/');
    const ext = path.extname(file.originalname).toLowerCase();
    const isImageExt = allowedExtensions.includes(ext);
    
    if (isImageMime || isImageExt) {
      cb(null, true);
    } else {
      console.log('Rejected file:', file.originalname, 'mimetype:', file.mimetype, 'ext:', ext);
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

// Handle OPTIONS requests explicitly
app.options('*', cors());

// Database connection middleware - ensure connection before processing requests
app.use(async (req, res, next) => {
  // Skip for health and debug endpoints that don't need DB
  if (req.path === '/api/health' || req.path === '/api/debug/env') {
    return next();
  }
  
  try {
    await connectToDatabase();
    next();
  } catch (error) {
    console.error('Failed to connect to database:', error);
    res.status(503).json({ 
      error: 'Database connection failed',
      message: error.message 
    });
  }
});

// Email transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});

// Helper function to format date with timezone awareness
function formatDateWithTimezone(date) {
  if (!date) return null;
  // Store both UTC and local formatted string
  return {
    isoString: date.toISOString(),
    timestamp: date.getTime(),
    dateString: date.toLocaleString('en-US', { 
      year: 'numeric', 
      month: '2-digit', 
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    })
  };
}

// MongoDB connection with connection reuse for serverless
let cachedConnection = null;
let connectionPromise = null;

async function connectToDatabase() {
  // If connection is already established and ready, return immediately
  if (cachedConnection && mongoose.connection.readyState === 1) {
    console.log('Using cached database connection');
    return cachedConnection;
  }

  // If a connection is already in progress, wait for it
  if (connectionPromise) {
    console.log('Connection in progress, waiting...');
    return connectionPromise;
  }

  // Create new connection promise
  connectionPromise = (async () => {
    try {
      const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';
      console.log('Connecting to MongoDB...');
      console.log('MongoDB URI present:', !!process.env.MONGODB_URI); // Debug log

      // Retry loop to handle transient network issues on serverless platforms
      const maxAttempts = 3;
      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          console.log(`MongoDB connect attempt ${attempt}/${maxAttempts}`);
          
          // Connect to MongoDB
          await mongoose.connect(mongoUri, {
            // Allow extra time for server selection and TLS handshake on cold starts
            serverSelectionTimeoutMS: 60000,
            connectTimeoutMS: 45000,
            socketTimeoutMS: 60000,
            // Keep pool small for serverless to avoid too many concurrent sockets
            maxPoolSize: 5,
            minPoolSize: 0,
            // Prefer IPv4 where possible
            family: 4,
            // Don't buffer commands while connecting
            bufferCommands: false,
          });

          // Wait for connection to be fully ready
          if (mongoose.connection.readyState !== 1) {
            console.log('Waiting for connection to be ready...');
            await new Promise((resolve, reject) => {
              const timeout = setTimeout(() => {
                reject(new Error('Connection ready timeout'));
              }, 10000);
              
              mongoose.connection.once('connected', () => {
                clearTimeout(timeout);
                resolve();
              });
              
              // If already connected, resolve immediately
              if (mongoose.connection.readyState === 1) {
                clearTimeout(timeout);
                resolve();
              }
            });
          }

          cachedConnection = mongoose.connection;
          console.log('MongoDB connected successfully, readyState:', mongoose.connection.readyState);
          return cachedConnection;
        } catch (error) {
          console.error(`MongoDB connection error on attempt ${attempt}:`, error && error.message ? error.message : error);
          // Log topology if available for deeper insight
          if (error && error.reason) {
            console.error('Topology reason:', error.reason);
          }
          if (attempt < maxAttempts) {
            const backoff = Math.pow(2, attempt) * 1000; // exponential backoff
            console.log(`Retrying MongoDB connection in ${backoff}ms...`);
            await new Promise(res => setTimeout(res, backoff));
          } else {
            console.error('All MongoDB connection attempts failed');
            throw error;
          }
        }
      }
    } finally {
      connectionPromise = null;
    }
  })();

  return connectionPromise;
}

// Initialize connection - REMOVED for Vercel
// connectToDatabase();

// Handle MongoDB connection errors after initial connection
mongoose.connection.on('error', err => {
  console.error('MongoDB connection error:', err);
  cachedConnection = null;
});

mongoose.connection.on('disconnected', () => {
  console.log('MongoDB disconnected');
  cachedConnection = null;
});

mongoose.connection.on('connected', () => {
  console.log('MongoDB connected');
});

// Timezone utility - Convert UTC timestamps to Asia/Colombo (UTC+5:30)
const getLocalizedDate = (utcDate) => {
  if (!utcDate) return null;
  const date = new Date(utcDate);
  // Asia/Colombo is UTC+5:30
  const offset = 5.5 * 60 * 60 * 1000; // 5:30 hours in milliseconds
  return new Date(date.getTime() + offset);
};

// Models
const ClassSchema = new mongoose.Schema({
  name: { type: String, required: true },
  teacherId: { type: mongoose.Schema.Types.ObjectId, ref: 'Teacher', required: true },
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }, // Company/Admin association
}, { timestamps: true });

ClassSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    return ret;
  }
});

const StudentSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: String,
  studentId: { type: String, unique: true },
  classId: { type: mongoose.Schema.Types.ObjectId, ref: 'Class' },
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }, // Company/Admin association
  isRestricted: { type: Boolean, default: false },
  restrictedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' },
  restrictedAt: { type: Date },
  restrictionReason: { type: String },
}, { timestamps: true });

StudentSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    if (ret.restrictedAt) ret.restrictedAt = getLocalizedDate(ret.restrictedAt);
    return ret;
  }
});

const AttendanceSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Student', required: true },
  classId: { type: mongoose.Schema.Types.ObjectId, ref: 'Class' }, // Made optional for migration
  date: { type: Date, required: true },
  session: { type: String, default: 'daily' }, // Changed default to 'daily'
  status: { type: String, enum: ['present', 'absent', 'late'], required: true },
  month: { type: Number, required: true },
  year: { type: Number, required: true },
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }, // Company/Admin association
}, { timestamps: true });

AttendanceSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    if (ret.date) ret.date = getLocalizedDate(ret.date);
    return ret;
  }
});

const PaymentSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Student', required: true },
  classId: { type: mongoose.Schema.Types.ObjectId, ref: 'Class', required: true },
  amount: { type: Number, required: true },
  type: { type: String, enum: ['full', 'half', 'free'], required: true },
  date: { type: Date, default: Date.now },
  month: { type: Number, min: 1, max: 12 }, // Month field (1-12)
  year: { type: Number }, // Year field for historical payment tracking
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }, // Company/Admin association
}, { timestamps: true });

// Apply timezone conversion on JSON serialization
PaymentSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) {
      ret.createdAt = getLocalizedDate(ret.createdAt);
    }
    if (ret.updatedAt) {
      ret.updatedAt = getLocalizedDate(ret.updatedAt);
    }
    if (ret.date) {
      ret.date = getLocalizedDate(ret.date);
    }
    return ret;
  }
});

const TeacherSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: { type: String },
  password: { type: String, required: true },
  teacherId: { type: String, unique: true },
  status: { type: String, enum: ['active', 'inactive'], default: 'inactive' },
  profilePicture: { type: String }, // Profile picture path
  companyIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }], // Multiple companies - added when QR scanned
  subscriptionType: { type: String, enum: ['monthly', 'yearly', 'free'], default: 'free' },
  subscriptionStartDate: { type: Date },
  subscriptionExpiryDate: { type: Date },
  subscriptionStatus: { type: String, enum: ['none', 'pending', 'active', 'expired', 'rejected'], default: 'none' },
  isFirstLogin: { type: Boolean, default: true },
  lastSubscriptionWarningDate: { type: Date },
  isRestricted: { type: Boolean, default: false },
  restrictedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' },
  restrictedAt: { type: Date },
  restrictionReason: { type: String },
  fcmToken: { type: String }, // Firebase Cloud Messaging token for push notifications
}, { timestamps: true });

TeacherSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    if (ret.subscriptionStartDate) ret.subscriptionStartDate = getLocalizedDate(ret.subscriptionStartDate);
    if (ret.subscriptionExpiryDate) ret.subscriptionExpiryDate = getLocalizedDate(ret.subscriptionExpiryDate);
    if (ret.lastSubscriptionWarningDate) ret.lastSubscriptionWarningDate = getLocalizedDate(ret.lastSubscriptionWarningDate);
    if (ret.restrictedAt) ret.restrictedAt = getLocalizedDate(ret.restrictedAt);
    return ret;
  }
});

const EmailVerificationSchema = new mongoose.Schema({
  email: { type: String, required: true },
  code: { type: String, required: true },
  expiresAt: { type: Date, required: true },
}, { timestamps: true });

EmailVerificationSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    if (ret.expiresAt) ret.expiresAt = getLocalizedDate(ret.expiresAt);
    return ret;
  }
});

// Add TTL index to automatically delete expired codes
EmailVerificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const PasswordResetSchema = new mongoose.Schema({
  email: { type: String, required: true },
  resetCode: { type: String, required: true },
  expiresAt: { type: Date, required: true },
}, { timestamps: true });

PasswordResetSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    if (ret.expiresAt) ret.expiresAt = getLocalizedDate(ret.expiresAt);
    return ret;
  }
});

// Add TTL index to automatically delete expired reset codes
PasswordResetSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

// Web Session Schema for QR code authentication
const WebSessionSchema = new mongoose.Schema({
  sessionId: { type: String, required: true, unique: true },
  userId: { type: mongoose.Schema.Types.ObjectId, refPath: 'userModel' },
  userModel: { type: String, enum: ['Teacher', 'Admin'] },
  userType: { type: String, enum: ['admin', 'teacher'], required: true },
  deviceId: { type: String }, // Optional - set when QR is scanned
  isActive: { type: Boolean, default: false },
  expiresAt: { type: Date, required: true },
  teacherId: { type: String }, // Store teacherId for easy lookup
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }, // Company/Admin who generated the QR
  ipAddress: { type: String }, // IP address of the device
  userAgent: { type: String }, // User agent string
  lastActivity: { type: Date, default: Date.now }, // Last activity timestamp
}, { timestamps: true });

WebSessionSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    if (ret.expiresAt) ret.expiresAt = getLocalizedDate(ret.expiresAt);
    if (ret.lastActivity) ret.lastActivity = getLocalizedDate(ret.lastActivity);
    return ret;
  }
});

// Add TTL index to automatically delete expired sessions
WebSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

// Admin Schema for admin users
const AdminSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  name: { type: String, required: true },
  companyName: { type: String, required: true },
  role: { type: String, enum: ['admin', 'super-admin'], default: 'admin' },
  fcmToken: { type: String }, // Firebase Cloud Messaging token for push notifications
}, { timestamps: true });

AdminSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    return ret;
  }
});

// Problem Report Schema for user-submitted issues
const ProblemReportSchema = new mongoose.Schema({
  userEmail: { type: String, required: true },
  issueDescription: { type: String, required: true },
  appVersion: { type: String },
  device: { type: String }, // Platform: iOS or Android
  deviceName: { type: String }, // Device model name: eg. Samsung S20 plus
  teacherId: { type: String },
  studentId: { type: String },
  userType: { type: String, enum: ['teacher', 'student'], required: true },
  images: [{
    url: { type: String }, // Cloudinary URL
    publicId: { type: String } // Cloudinary public ID for deletion
  }],
}, { timestamps: true });

ProblemReportSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    return ret;
  }
});

// Feature Request Schema for user-submitted feature requests
const FeatureRequestSchema = new mongoose.Schema({
  userEmail: { type: String, required: true },
  featureDescription: { type: String, required: true },
  bidPrice: { type: Number, required: true },
  appVersion: { type: String },
  device: { type: String }, // Platform: iOS or Android
  deviceName: { type: String }, // Device model name: eg. Samsung S20 plus
  teacherId: { type: String },
  studentId: { type: String },
  userType: { type: String, enum: ['teacher', 'student'], required: true },
  status: { type: String, enum: ['pending', 'reviewed', 'in-progress', 'completed', 'rejected'], default: 'pending' },
}, { timestamps: true });

FeatureRequestSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    return ret;
  }
});

// Payment Proof Schema for subscription payment proofs
const PaymentProofSchema = new mongoose.Schema({
  userEmail: { type: String, required: true },
  subscriptionType: { type: String, enum: ['monthly', 'yearly'], required: true },
  amount: { type: String, required: true },
  paymentProofUrl: { type: String, required: true }, // Cloudinary URL
  paymentProofPublicId: { type: String, required: true }, // Cloudinary public ID for deletion
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
  reviewedBy: { type: String }, // Admin email who reviewed it
  reviewedAt: { type: Date },
  reviewNotes: { type: String },
  rejectionReason: { type: String }, // Specific reason for rejection
}, { timestamps: true });

PaymentProofSchema.set('toJSON', {
  transform: function(doc, ret) {
    if (ret.createdAt) ret.createdAt = getLocalizedDate(ret.createdAt);
    if (ret.updatedAt) ret.updatedAt = getLocalizedDate(ret.updatedAt);
    if (ret.reviewedAt) ret.reviewedAt = getLocalizedDate(ret.reviewedAt);
    return ret;
  }
});

AttendanceSchema.index({ studentId: 1, year: 1, month: 1 });

const Student = mongoose.models.Student || mongoose.model('Student', StudentSchema);
const Attendance = mongoose.models.Attendance || mongoose.model('Attendance', AttendanceSchema);
const Class = mongoose.models.Class || mongoose.model('Class', ClassSchema);
const Payment = mongoose.models.Payment || mongoose.model('Payment', PaymentSchema);
const Teacher = mongoose.models.Teacher || mongoose.model('Teacher', TeacherSchema);
const EmailVerification = mongoose.models.EmailVerification || mongoose.model('EmailVerification', EmailVerificationSchema);
const PasswordReset = mongoose.models.PasswordReset || mongoose.model('PasswordReset', PasswordResetSchema);
const WebSession = mongoose.models.WebSession || mongoose.model('WebSession', WebSessionSchema);
const Admin = mongoose.models.Admin || mongoose.model('Admin', AdminSchema);
const ProblemReport = mongoose.models.ProblemReport || mongoose.model('ProblemReport', ProblemReportSchema);
const PaymentProof = mongoose.models.PaymentProof || mongoose.model('PaymentProof', PaymentProofSchema);
const FeatureRequest = mongoose.models.FeatureRequest || mongoose.model('FeatureRequest', FeatureRequestSchema);

// Store for pending QR sessions and connected sockets
const pendingQRSessions = new Map(); // sessionId -> { timestamp, userType }
const connectedSockets = new Map(); // sessionId -> socket.id

// WebSocket connection handling
io.on('connection', (socket) => {
  console.log('New WebSocket connection:', socket.id);

  // Web client requests QR code
  socket.on('request-qr', async ({ userType, companyId }) => {
    try {
      const { v4: uuidv4 } = await import('uuid');
      const sessionId = uuidv4();
      const expiresAt = Date.now() + (5 * 60 * 1000); // 5 minutes
      
      console.log('QR Request received:', { userType, companyId });

      // Create WebSession in DB to store companyId
      if (companyId) {
        try {
          const webSession = new WebSession({
            sessionId,
            userType: userType || 'teacher',
            isActive: false,
            expiresAt: new Date(expiresAt),
            companyId: new mongoose.Types.ObjectId(companyId),
          });
          await webSession.save();
          console.log('Created WebSession in DB for QR code');
        } catch (dbError) {
          console.error('Error creating WebSession in DB:', dbError);
        }
      }
      
      pendingQRSessions.set(sessionId, {
        timestamp: Date.now(),
        expiresAt,
        userType: userType || 'teacher',
        socketId: socket.id,
        companyId
      });

      // Generate QR code
      const qrData = JSON.stringify({
        sessionId,
        timestamp: Date.now(),
        expiresAt,
        type: 'web-auth',
        companyId // Include companyId in QR data
      });

      const qrCodeDataUrl = await QRCode.toDataURL(qrData);

      socket.emit('qr-generated', {
        sessionId,
        qrCode: qrCodeDataUrl,
        expiresAt,
      });

      // Auto-cleanup expired session
      setTimeout(async () => {
        if (pendingQRSessions.has(sessionId)) {
          pendingQRSessions.delete(sessionId);
          socket.emit('qr-expired', { sessionId });
          
          // Also cleanup DB session
          try {
            await WebSession.deleteOne({ sessionId });
          } catch (e) {
            console.error('Error cleaning up expired WebSession:', e);
          }
        }
      }, 5 * 60 * 1000);

      console.log('QR code generated for session:', sessionId);
    } catch (error) {
      console.error('Error generating QR code:', error);
      socket.emit('error', { message: 'Failed to generate QR code' });
    }
  });

  // Mobile app scans QR and sends authentication
  socket.on('authenticate-qr', async ({ sessionId, teacherId, deviceId }) => {
    try {
      console.log('=== Socket Authentication Request ===');
      console.log('Session ID:', sessionId);
      console.log('Teacher ID:', teacherId);
      console.log('Device ID:', deviceId);
      console.log('Socket ID:', socket.id);
      
      const pendingSession = pendingQRSessions.get(sessionId);
      
      if (!pendingSession) {
        console.log('ERROR: Session not found in pending sessions');
        socket.emit('auth-failed', { message: 'Invalid or expired session' });
        return;
      }

      console.log('Pending session found:', {
        sessionId,
        userType: pendingSession.userType,
        socketId: pendingSession.socketId,
        expiresAt: new Date(pendingSession.expiresAt).toISOString(),
      });

      if (Date.now() > pendingSession.expiresAt) {
        console.log('ERROR: Session expired');
        pendingQRSessions.delete(sessionId);
        socket.emit('auth-failed', { message: 'Session expired' });
        return;
      }

      // Find teacher
      console.log('Looking for teacher...');
      const teacher = await Teacher.findOne({ teacherId });
      
      if (!teacher) {
        console.log('ERROR: Teacher not found');
        socket.emit('auth-failed', { message: 'Teacher not found' });
        return;
      }

      console.log('✓ Teacher found:', teacher.name, '(ID:', teacher.teacherId, ')');

      if (teacher.status !== 'active') {
        console.log('ERROR: Teacher account inactive');
        socket.emit('auth-failed', { message: 'Teacher account is inactive' });
        return;
      }

      // Get the WebSession to retrieve companyId
      console.log('Looking for web session...');
      let webSession = await WebSession.findOne({ sessionId });
      
      if (!webSession) {
        console.log('Web session not found in DB');
        
        // Fallback: Create session if we have info in pendingSession
        if (pendingSession && pendingSession.companyId) {
          console.log('Creating WebSession from pending session data');
          try {
            webSession = new WebSession({
              sessionId,
              userType: pendingSession.userType,
              isActive: false,
              expiresAt: new Date(pendingSession.expiresAt),
              companyId: new mongoose.Types.ObjectId(pendingSession.companyId),
            });
            await webSession.save();
            console.log('✓ WebSession created on-the-fly');
          } catch (err) {
            console.error('Error creating fallback session:', err);
            socket.emit('auth-failed', { message: 'Session creation failed' });
            return;
          }
        } else {
          console.log('ERROR: Web session not found and cannot be recreated');
          socket.emit('auth-failed', { message: 'Session not found' });
          return;
        }
      }

      console.log('✓ Web session found');
      console.log('Session details:', {
        sessionId: webSession.sessionId,
        companyId: webSession.companyId,
        isActive: webSession.isActive,
        currentUserId: webSession.userId,
        currentDeviceId: webSession.deviceId,
      });

      // Check if session is already authenticated
      if (webSession.isActive && webSession.userId && webSession.deviceId) {
        console.log('⚠ Session already authenticated!');
        console.log('Current device:', webSession.deviceId);
        console.log('Requesting device:', deviceId);
        
        if (webSession.deviceId !== deviceId) {
          console.log('ERROR: Session authenticated on different device');
          socket.emit('auth-failed', { 
            message: 'Session already authenticated on another device',
            details: {
              currentDevice: webSession.deviceId,
              requestingDevice: deviceId,
            }
          });
          return;
        } else {
          console.log('✓ Same device attempting to re-authenticate');
        }
      }

      // Add companyId to teacher's array if not already present
      if (webSession.companyId) {
        if (!teacher.companyIds) {
          teacher.companyIds = [];
          console.log('Initializing companyIds array');
        }
        
        const companyIdStr = webSession.companyId.toString();
        const hasCompany = teacher.companyIds.some(id => id.toString() === companyIdStr);
        
        if (!hasCompany) {
          console.log('Adding company to teacher:', companyIdStr);
          teacher.companyIds.push(webSession.companyId);
          try {
            await teacher.save();
            console.log(`✓ Teacher ${teacherId} added to company ${companyIdStr}`);
          } catch (saveError) {
            console.error('Error saving teacher with new companyId:', saveError);
          }
        } else {
          console.log(`✓ Teacher ${teacherId} already belongs to company ${companyIdStr}`);
        }
      } else {
        console.warn('⚠ No companyId found in WebSession - Teacher will not be linked to company');
      }

      // Update web session with user info
      console.log('Updating session with authentication details...');
      webSession.userId = teacher._id;
      webSession.userModel = 'Teacher';
      webSession.deviceId = deviceId || socket.id;
      webSession.isActive = true;
      webSession.expiresAt = new Date(Date.now() + (24 * 60 * 60 * 1000)); // 24 hours
      webSession.teacherId = teacher.teacherId;
      await webSession.save();

      console.log('✓ Session updated');

      // Generate JWT token
      const token = jwt.sign(
        {
          sessionId,
          userId: teacher._id,
          teacherId: teacher.teacherId,
          userType: pendingSession.userType,
          companyIds: teacher.companyIds,
        },
        process.env.JWT_SECRET || 'your-secret-key',
        { expiresIn: '24h' }
      );

      // Notify web client
      const webSocketId = pendingSession.socketId;
      console.log('Notifying web client at socket:', webSocketId);
      io.to(webSocketId).emit('authenticated', {
        success: true,
        user: {
          _id: teacher._id,
          name: teacher.name,
          email: teacher.email,
          teacherId: teacher.teacherId,
          status: teacher.status,
          companyIds: teacher.companyIds,
        },
        session: webSession,
        token,
      });

      // Notify mobile app
      console.log('Notifying mobile app');
      socket.emit('auth-success', {
        message: 'Successfully authenticated',
        sessionId,
      });

      // Store connected socket
      connectedSockets.set(sessionId, webSocketId);
      pendingQRSessions.delete(sessionId);

      console.log('✓ Authentication successful for session:', sessionId);
    } catch (error) {
      console.error('❌ Error authenticating QR:', error);
      console.error('Error stack:', error.stack);
      socket.emit('auth-failed', { message: 'Authentication failed' });
    }
  });

  // Disconnect session
  socket.on('disconnect-session', async ({ sessionId }) => {
    try {
      console.log('Disconnecting session:', sessionId);
      
      // Find the session first to get details for cleanup
      const webSession = await WebSession.findOne({ sessionId });
      
      if (webSession) {
        // Deactivate session but KEEP the company association in teacher's companyIds
        // The teacher remains associated with the company even after session ends
        // This allows them to appear in the company's teacher list for future logins
        webSession.isActive = false;
        await webSession.save();
        console.log('✓ Session deactivated');
        
        if (webSession.userModel === 'Teacher' && webSession.userId && webSession.companyId) {
          const teacher = await Teacher.findById(webSession.userId);
          console.log(`Teacher ${teacher?.teacherId} remains associated with company ${webSession.companyId}`);
          console.log('Company association preserved for future logins');
        }
      } else {
        console.log('Session not found for disconnect:', sessionId);
      }
      
      const webSocketId = connectedSockets.get(sessionId);
      if (webSocketId) {
        io.to(webSocketId).emit('session-disconnected', { sessionId });
        connectedSockets.delete(sessionId);
      }

      socket.emit('disconnect-success', { sessionId });
    } catch (error) {
      console.error('Error disconnecting session:', error);
    }
  });

  socket.on('disconnect', async () => {
    console.log('WebSocket disconnected:', socket.id);
    
    // Clean up any sessions associated with this socket and mark them inactive
    for (const [sessionId, socketId] of connectedSockets.entries()) {
      if (socketId === socket.id) {
        connectedSockets.delete(sessionId);
        
        try {
          // Find and update the session to inactive
          const WebSession = mongoose.model('WebSession');
          const updatedSession = await WebSession.findOneAndUpdate(
            { sessionId },
            { isActive: false },
            { new: true }
          );
          
          if (updatedSession) {
            console.log('Marked session inactive due to disconnect:', sessionId);
            // Notify all connected clients about the session disconnect
            io.emit('session-disconnected', { sessionId });
          }
        } catch (error) {
          console.error('Error updating session on disconnect:', error);
        }
      }
    }
  });
});

// Database connection middleware
app.use(async (req, res, next) => {
  try {
    await connectToDatabase();
    next();
  } catch (error) {
    console.error('Database connection failed in middleware:', error);
    res.status(500).json({ error: 'Database connection failed' });
  }
});

// Utility function to send FCM notification to teacher
async function sendFCMNotificationToTeacher(teacherId, title, body, data = {}) {
  try {
    const teacher = await Teacher.findById(teacherId);
    
    if (!teacher || !teacher.fcmToken) {
      console.log(`No FCM token found for teacher ${teacherId}`);
      return false;
    }

    const messaging = admin.messaging();
    const message = {
      notification: {
        title: title,
        body: body
      },
      data: {
        ...data,
        timestamp: new Date().toISOString()
      },
      token: teacher.fcmToken
    };

    const response = await messaging.send(message);
    console.log(`FCM notification sent to teacher ${teacher.email}:`, response);
    return true;
  } catch (error) {
    console.error('Error sending FCM notification:', error);
    return false;
  }
}

// Utility function to send FCM notification to multiple teachers
async function sendFCMNotificationToTeachers(teacherIds, title, body, data = {}) {
  const results = [];
  
  for (const teacherId of teacherIds) {
    const result = await sendFCMNotificationToTeacher(teacherId, title, body, data);
    results.push({ teacherId, success: result });
  }
  
  return results;
}

// Utility function to send FCM notification to admin
async function sendFCMNotificationToAdmin(adminId, title, body, data = {}) {
  try {
    const admin_user = await Admin.findById(adminId);
    
    if (!admin_user || !admin_user.fcmToken) {
      console.log(`No FCM token found for admin ${adminId}`);
      return false;
    }

    const messaging = admin.messaging();
    const message = {
      notification: {
        title: title,
        body: body
      },
      data: {
        ...data,
        timestamp: new Date().toISOString()
      },
      token: admin_user.fcmToken
    };

    const response = await messaging.send(message);
    console.log(`FCM notification sent to admin ${admin_user.email}:`, response);
    return true;
  } catch (error) {
    console.error('Error sending FCM notification to admin:', error);
    return false;
  }
}

// Utility function to send FCM notification to student
async function sendFCMNotificationToStudent(studentId, title, body, data = {}) {
  try {
    const student = await Student.findById(studentId);
    
    if (!student || !student.fcmToken) {
      console.log(`No FCM token found for student ${studentId}`);
      return false;
    }

    const messaging = admin.messaging();
    const message = {
      notification: {
        title: title,
        body: body
      },
      data: {
        ...data,
        timestamp: new Date().toISOString()
      },
      token: student.fcmToken
    };

    const response = await messaging.send(message);
    console.log(`FCM notification sent to student ${student.email}:`, response);
    return true;
  } catch (error) {
    console.error('Error sending FCM notification to student:', error);
    return false;
  }
}

// Utility function to send FCM notification to multiple students
async function sendFCMNotificationToStudents(studentIds, title, body, data = {}) {
  const results = [];
  for (const studentId of studentIds) {
    const result = await sendFCMNotificationToStudent(studentId, title, body, data);
    results.push(result);
  }
  return results;
}

// Middleware to verify JWT token
const verifyToken = (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
    
    console.log('=== Token Verification (server.js) ===');
    console.log('Endpoint:', req.method, req.path);
    console.log('Token present:', !!token);
    console.log('JWT_SECRET exists:', !!process.env.JWT_SECRET);
    console.log('JWT_SECRET length:', jwtSecret.length);
    console.log('JWT_SECRET (first 10 chars):', jwtSecret.substring(0, 10) + '...');
    
    if (!token) {
      console.log('❌ No token provided');
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, jwtSecret);
    console.log('✓ Token verified successfully');
    console.log('Decoded token:', {
      userId: decoded.userId,
      teacherId: decoded.teacherId,
      email: decoded.email,
      iat: new Date(decoded.iat * 1000).toISOString(),
      exp: decoded.exp ? new Date(decoded.exp * 1000).toISOString() : 'No expiration'
    });
    
    req.user = decoded;
    next();
  } catch (error) {
    console.error('❌ Token verification error:', error.message);
    if (error.name === 'TokenExpiredError') {
      console.log('Token expired at:', error.expiredAt);
      return res.status(401).json({ error: 'Token expired', expired: true });
    }
    if (error.name === 'JsonWebTokenError') {
      console.log('Invalid token signature or format');
      return res.status(401).json({ error: 'Invalid token' });
    }
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Routes
// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    message: 'Server is running',
    timestamp: new Date().toISOString(),
    mongoStatus: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

// Debug endpoint to check environment variables (safe - no sensitive data)
app.get('/api/debug/env', (req, res) => {
  res.json({
    hasMongoUri: !!process.env.MONGODB_URI,
    hasEmailUser: !!process.env.EMAIL_USER,
    hasEmailPass: !!process.env.EMAIL_PASS,
    hasCloudinaryCloudName: !!process.env.CLOUDINARY_CLOUD_NAME,
    hasCloudinaryApiKey: !!process.env.CLOUDINARY_API_KEY,
    hasCloudinaryApiSecret: !!process.env.CLOUDINARY_API_SECRET,
    nodeEnv: process.env.NODE_ENV,
    mongoUriLength: process.env.MONGODB_URI ? process.env.MONGODB_URI.length : 0,
    mongoUriStartsWith: process.env.MONGODB_URI ? process.env.MONGODB_URI.substring(0, 20) + '...' : null
  });
});

// Debug endpoint for MongoDB connection details
app.get('/api/debug/mongodb', (req, res) => {
  res.json({
    readyState: mongoose.connection.readyState,
    readyStateText: ['disconnected', 'connected', 'connecting', 'disconnecting'][mongoose.connection.readyState] || 'unknown',
    name: mongoose.connection.name,
    host: mongoose.connection.host,
    port: mongoose.connection.port,
    db: mongoose.connection.db ? mongoose.connection.db.databaseName : null,
    mongoUriPresent: !!process.env.MONGODB_URI,
    mongoUriLength: process.env.MONGODB_URI ? process.env.MONGODB_URI.length : 0
  });
});

// Students
app.get('/api/students', verifyToken, async (req, res) => {
  try {
    console.log('GET /api/students called');
    console.log('MongoDB connection state:', mongoose.connection.readyState);
    const { teacherId, classId } = req.query;

    let query = {};
    
    // Filter by classId if provided
    if (classId) {
      console.log('Filtering students for classId:', classId);
      query.classId = new mongoose.Types.ObjectId(classId);
      console.log('Query for classId filter:', query);
    } else if (teacherId) {
      // Find teacher by teacherId string and get their classes
      console.log('Filtering students for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        const classIds = classes.map(c => c._id);
        query.classId = { $in: classIds };
        console.log('Found', classIds.length, 'classes for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty array');
        return res.json([]);
      }
    }

    const students = await Student.find(query);
    console.log('Found students count:', students.length);

    // Convert to plain objects and ensure classId is a string
    const result = students.map(student => {
      const obj = student.toObject();
      if (obj.classId && obj.classId._id) {
        obj.classId = obj.classId._id.toString();
      } else if (obj.classId && typeof obj.classId === 'object') {
        obj.classId = obj.classId.toString();
      }
      return obj;
    });

    console.log('Returning students:', result.length);
    res.json(result);
  } catch (error) {
    console.error('Error fetching students:', error);
    res.status(500).json({ error: 'Failed to fetch students', details: error.message });
  }
});

app.post('/api/students', verifyToken, async (req, res) => {
  try {
    const { name, email, studentId, classId } = req.body;
    
    // Auto-generate studentId if not provided
    let finalStudentId = studentId;
    if (!finalStudentId) {
      // Generate a unique student ID based on timestamp and random number
      const timestamp = Date.now().toString().slice(-6);
      const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
      finalStudentId = `STU${timestamp}${random}`;
      
      // Check if it already exists, if so, regenerate
      let existingStudent = await Student.findOne({ studentId: finalStudentId });
      while (existingStudent) {
        const newRandom = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
        finalStudentId = `STU${timestamp}${newRandom}`;
        existingStudent = await Student.findOne({ studentId: finalStudentId });
      }
    }
    
    // Convert classId to ObjectId if it's a string
    let classObjectId = classId;
    if (classId && typeof classId === 'string' && classId.match(/^[0-9a-fA-F]{24}$/)) {
      classObjectId = new mongoose.Types.ObjectId(classId);
    }
    
    const student = new Student({ name, email, studentId: finalStudentId, classId: classObjectId });
    await student.save();
    res.status(201).json(student);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create student' });
  }
});

app.get('/api/students/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    console.log('GET /api/students/:id called with id:', id);
    
    // Validate ObjectId format
    if (!id.match(/^[0-9a-fA-F]{24}$/)) {
      return res.status(400).json({ error: 'Invalid student ID format' });
    }
    
    const student = await Student.findById(id);
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }
    
    console.log('Student found:', student);
    res.json(student);
  } catch (error) {
    console.error('Error fetching student:', error);
    res.status(500).json({ error: 'Failed to fetch student', details: error.message });
  }
});

app.put('/api/students/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    // Convert classId to ObjectId if it's a string
    if (updateData.classId && typeof updateData.classId === 'string' && updateData.classId.match(/^[0-9a-fA-F]{24}$/)) {
      updateData.classId = new mongoose.Types.ObjectId(updateData.classId);
    }
    
    const updatedStudent = await Student.findByIdAndUpdate(id, updateData, { new: true });
    if (!updatedStudent) {
      return res.status(404).json({ error: 'Student not found' });
    }
    res.json(updatedStudent);
  } catch (error) {
    console.error('Error updating student:', error);
    res.status(500).json({ error: 'Failed to update student', details: error.message });
  }
});

app.delete('/api/students/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const deletedStudent = await Student.findByIdAndDelete(id);
    if (!deletedStudent) {
      return res.status(404).json({ error: 'Student not found' });
    }
    res.json({ message: 'Student deleted successfully' });
  } catch (error) {
    console.error('Error deleting student:', error);
    res.status(500).json({ error: 'Failed to delete student', details: error.message });
  }
});

// Attendance
app.get('/api/attendance', verifyToken, async (req, res) => {
  try {
    const { studentId, month, year, teacherId } = req.query;
    let query = {};
    if (studentId) query.studentId = studentId;
    if (month) query.month = parseInt(month);
    if (year) query.year = parseInt(year);

    if (teacherId) {
      // Find teacher by teacherId string and get their students
      console.log('Filtering attendance for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        const classIds = classes.map(c => c._id);
        const students = await Student.find({ classId: { $in: classIds } });
        const studentIds = students.map(s => s._id);
        query.studentId = { $in: studentIds };
        console.log('Found', studentIds.length, 'students for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty array');
        return res.json([]);
      }
    }

    const attendance = await Attendance.find(query)
      .populate('studentId', 'name studentId')
      .populate('classId', 'name')
      .sort({ date: -1 });
    
    // Convert the populated attendance records to include studentId as string
    const result = attendance.map(record => {
      const obj = record.toObject();
      
      // If studentId is populated (object), extract the studentId string
      if (obj.studentId && typeof obj.studentId === 'object' && obj.studentId.studentId) {
        obj.studentId = obj.studentId.studentId; // Use the student's ID string
      } else if (obj.studentId && typeof obj.studentId === 'object' && obj.studentId._id) {
        obj.studentId = obj.studentId._id.toString(); // Fallback to ObjectId string
      }
      
      return obj;
    });
    
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch attendance' });
  }
});

app.post('/api/attendance', verifyToken, async (req, res) => {
  try {
    const { studentId, date, session = 'daily', status } = req.body;
    console.log('POST /api/attendance received:', { studentId, date, session, status });
    
    // Convert studentId to ObjectId if it's a string
    let studentObjectId = studentId;
    if (typeof studentId === 'string' && studentId.match(/^[0-9a-fA-F]{24}$/)) {
      studentObjectId = new mongoose.Types.ObjectId(studentId);
      console.log('Converted studentId to ObjectId:', studentObjectId);
    } else {
      console.log('studentId is not a valid ObjectId string:', studentId);
    }
    
    // Get student to retrieve classId
    const student = await Student.findById(studentObjectId);
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }
    
    if (!student.classId) {
      return res.status(400).json({ error: 'Student is not assigned to any class' });
    }
    
    const attendanceDate = new Date(date);
    console.log('Parsed date:', attendanceDate);
    
    // Check if status is empty (meaning unmark/delete)
    if (!status || status.trim() === '') {
      // Delete existing attendance record using the same date logic as batch query
      const year = attendanceDate.getFullYear();
      const month = attendanceDate.getMonth() + 1;
      const day = attendanceDate.getDate();
      
      const deleteResult = await Attendance.deleteOne({
        studentId: studentObjectId,
        year: year,
        month: month,
        session,
        $expr: { $eq: [{ $dayOfMonth: '$date' }, day] }
      });
      
      if (deleteResult.deletedCount > 0) {
        console.log('Deleted attendance record for student:', studentId, 'on', attendanceDate);
        return res.status(200).json({ 
          message: 'Attendance record deleted successfully',
          deleted: true,
          studentId: studentObjectId,
          date: attendanceDate,
          session
        });
      } else {
        console.log('No attendance record found to delete for student:', studentId, 'on', attendanceDate);
        // Return success even if no record exists (idempotent deletion)
        return res.status(200).json({ 
          message: 'No attendance record to delete (already unmarked)',
          deleted: false,
          studentId: studentObjectId,
          date: attendanceDate,
          session
        });
      }
    }
    
    // For marking/updating attendance
    // Check if record already exists using the same date logic as batch query
    const year = attendanceDate.getFullYear();
    const month = attendanceDate.getMonth() + 1;
    const day = attendanceDate.getDate();
    
    const existingAttendance = await Attendance.findOne({
      studentId: studentObjectId,
      year: year,
      month: month,
      session,
      $expr: { $eq: [{ $dayOfMonth: '$date' }, day] }
    });
    
    if (existingAttendance) {
      // Update existing record
      existingAttendance.status = status;
      existingAttendance.month = attendanceDate.getMonth() + 1;
      existingAttendance.year = attendanceDate.getFullYear();
      await existingAttendance.save();
      console.log('Updated attendance:', existingAttendance);
      res.status(200).json(existingAttendance);
    } else {
      // Create new record
      const attendance = new Attendance({
        studentId: studentObjectId,
        classId: student.classId,
        date: attendanceDate,
        session,
        status,
        month: attendanceDate.getMonth() + 1,
        year: attendanceDate.getFullYear(),
      });
      console.log('Saving new attendance:', attendance);
      await attendance.save();
      res.status(201).json(attendance);
    }
  } catch (error) {
    console.error('Error handling attendance record:', error);
    res.status(500).json({ error: 'Failed to handle attendance record', details: error.message });
  }
});

// Batch get attendance for multiple students on a specific date
app.post('/api/attendance/batch', verifyToken, async (req, res) => {
  try {
    const { studentIds, date } = req.body;
    
    if (!studentIds || !Array.isArray(studentIds) || studentIds.length === 0) {
      return res.status(400).json({ error: 'studentIds must be a non-empty array' });
    }
    
    if (!date) {
      return res.status(400).json({ error: 'date is required' });
    }
    
    const attendanceDate = new Date(date);
    const year = attendanceDate.getFullYear();
    const month = attendanceDate.getMonth() + 1;
    const day = attendanceDate.getDate();
    
    console.log('Batch attendance request for', studentIds.length, 'students on', date);
    
    // Convert studentIds to ObjectIds
    const objectIds = studentIds.map(id => {
      if (typeof id === 'string' && id.match(/^[0-9a-fA-F]{24}$/)) {
        return new mongoose.Types.ObjectId(id);
      }
      return id;
    });
    
    // Find all attendance records for these students on this date
    const attendance = await Attendance.find({
      studentId: { $in: objectIds },
      year: year,
      month: month,
      $expr: { $eq: [{ $dayOfMonth: '$date' }, day] }
    });
    
    console.log('Found', attendance.length, 'attendance records');
    
    // Create a map of studentId -> attendance status for quick lookup
    const attendanceMap = {};
    attendance.forEach(record => {
      const studentId = record.studentId.toString();
      attendanceMap[studentId] = record.status;
    });
    
    res.json(attendanceMap);
  } catch (error) {
    console.error('Error fetching batch attendance:', error);
    res.status(500).json({ error: 'Failed to fetch batch attendance', details: error.message });
  }
});

// Classes
app.get('/api/classes', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.query;
    let query = {};

    console.log('GET /api/classes called with teacherId:', teacherId);

    if (teacherId) {
      // Find teacher by teacherId string and get their _id
      console.log('Looking for teacher with teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      console.log('Teacher found:', !!teacher, teacher ? teacher._id : null);
      if (teacher) {
        query.teacherId = teacher._id;
        console.log('Query:', query);
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty array');
        return res.json([]); // Return empty array instead of 404
      }
    }

    console.log('Executing Class.find with query:', query);
    const classes = await Class.find(query);
    console.log('Found classes:', classes.length);
    res.json(classes);
  } catch (error) {
    console.error('Error fetching classes:', error);
    res.status(500).json({ error: 'Failed to fetch classes' });
  }
});

app.post('/api/classes', verifyToken, async (req, res) => {
  try {
    const { name, teacherId } = req.body;
    
    // Find teacher by teacherId string
    const teacher = await Teacher.findOne({ teacherId });
    if (!teacher) {
      return res.status(400).json({ error: 'Teacher not found' });
    }
    
    const classObj = new Class({ name, teacherId: teacher._id });
    await classObj.save();
    res.status(201).json(classObj);
  } catch (error) {
    console.error('Error creating class:', error);
    res.status(500).json({ error: 'Failed to create class' });
  }
});

app.get('/api/classes/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    console.log('GET /api/classes/:id called with id:', id);
    
    // Validate ObjectId format
    if (!id.match(/^[0-9a-fA-F]{24}$/)) {
      return res.status(400).json({ error: 'Invalid class ID format' });
    }
    
    const classObj = await Class.findById(id);
    if (!classObj) {
      return res.status(404).json({ error: 'Class not found' });
    }
    
    console.log('Class found:', classObj);
    res.json(classObj);
  } catch (error) {
    console.error('Error fetching class:', error);
    res.status(500).json({ error: 'Failed to fetch class', details: error.message });
  }
});

app.put('/api/classes/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { name } = req.body;
    const updatedClass = await Class.findByIdAndUpdate(id, { name }, { new: true });
    if (!updatedClass) {
      return res.status(404).json({ error: 'Class not found' });
    }
    res.status(200).json(updatedClass);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update class' });
  }
});

app.delete('/api/classes/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    await Class.findByIdAndDelete(id);
    res.status(200).json({ message: 'Class deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete class' });
  }
});

// Student endpoints for mobile app
app.post('/api/student/login', async (req, res) => {
  try {
    const { studentNumber, email } = req.body;

    if (!studentNumber || !email) {
      return res.status(400).json({ 
        error: 'Student number and email are required',
        success: false 
      });
    }

    // Find student by studentId (studentNumber) and email
    const student = await Student.findOne({ 
      studentId: studentNumber.trim(),
      email: email.trim().toLowerCase()
    }).populate('classId', 'name');

    if (!student) {
      return res.status(404).json({ 
        error: 'Student not found. Please check your student number and email.',
        success: false 
      });
    }

    // Return student info
    res.json({
      success: true,
      student: {
        id: student._id,
        name: student.name,
        email: student.email,
        studentId: student.studentId,
        classId: student.classId?._id,
        className: student.classId?.name,
        companyId: student.companyId
      }
    });
  } catch (error) {
    console.error('Error in student login:', error);
    res.status(500).json({ 
      error: 'Login failed. Please try again.',
      success: false 
    });
  }
});


// Student restriction check middleware
const checkStudentRestriction = async (req, res, next) => {
  try {
    // Get studentId from either query params (GET) or body (POST/PUT/DELETE)
    const studentId = req.query.studentId || req.body.studentId;
    
    if (!studentId) {
      return res.status(400).json({ error: 'Student ID is required' });
    }

    // Find the student
    const student = await Student.findById(studentId);
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Check if student is restricted
    if (student.isRestricted) {
      return res.status(403).json({ 
        error: 'Student access restricted',
        message: 'This student has been restricted and cannot perform this action'
      });
    }

    next();
  } catch (error) {
    console.error('Student restriction check error:', error.message);
    res.status(500).json({ error: 'Internal server error' });
  }
};

app.get('/api/student/attendance', checkStudentRestriction, async (req, res) => {
  try {
    const { studentId, month, year } = req.query;

    if (!studentId) {
      return res.status(400).json({ 
        error: 'Student ID is required',
        success: false 
      });
    }

    // Convert studentId to ObjectId if it's a string
    let studentObjectId = studentId;
    if (typeof studentId === 'string' && studentId.match(/^[0-9a-fA-F]{24}$/)) {
      studentObjectId = new mongoose.Types.ObjectId(studentId);
    }

    // Verify student exists
    const student = await Student.findById(studentObjectId);
    if (!student) {
      return res.status(404).json({ 
        error: 'Student not found',
        success: false 
      });
    }

    // Build query
    let query = { studentId: studentObjectId };
    if (month) query.month = parseInt(month);
    if (year) query.year = parseInt(year);

    // Get attendance records
    const attendance = await Attendance.find(query)
      .populate('studentId', 'name studentId')
      .populate('classId', 'name')
      .sort({ date: -1, createdAt: -1 });

    res.json({
      success: true,
      attendance: attendance
    });
  } catch (error) {
    console.error('Error fetching student attendance:', error);
    res.status(500).json({ 
      error: 'Failed to load attendance records',
      success: false 
    });
  }
});

app.get('/api/student/payments', checkStudentRestriction, async (req, res) => {
  try {
    const { studentId, month, year } = req.query;

    if (!studentId) {
      return res.status(400).json({ 
        error: 'Student ID is required',
        success: false 
      });
    }

    // Convert studentId to ObjectId if it's a string
    let studentObjectId = studentId;
    if (typeof studentId === 'string' && studentId.match(/^[0-9a-fA-F]{24}$/)) {
      studentObjectId = new mongoose.Types.ObjectId(studentId);
    }

    // Verify student exists
    const student = await Student.findById(studentObjectId);
    if (!student) {
      return res.status(404).json({ 
        error: 'Student not found',
        success: false 
      });
    }

    // Build query
    let query = { studentId: studentObjectId };
    if (month) query.month = parseInt(month);
    if (year) {
      const yearNum = parseInt(year);
      const startDate = new Date(yearNum, 0, 1);
      const endDate = new Date(yearNum + 1, 0, 1);
      query.date = { $gte: startDate, $lt: endDate };
    }

    // Get payment records
    const payments = await Payment.find(query)
      .populate('classId', 'name')
      .sort({ date: -1, createdAt: -1 });

    res.json({
      success: true,
      payments: payments
    });
  } catch (error) {
    console.error('Error fetching student payments:', error);
    res.status(500).json({ 
      error: 'Failed to load payment records',
      success: false 
    });
  }
});

app.get('/api/student/status', checkStudentRestriction, async (req, res) => {
  try {
    const { studentId } = req.query;

    if (!studentId) {
      return res.status(400).json({ 
        error: 'Student ID is required',
        success: false 
      });
    }

    // Get student with class info
    const student = await Student.findById(studentId)
      .populate('classId', 'name')
      .populate('companyId', 'name');

    if (!student) {
      return res.status(404).json({ 
        error: 'Student not found',
        success: false 
      });
    }

    // Get recent attendance count (last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const recentAttendance = await Attendance.find({
      studentId: studentId,
      date: { $gte: thirtyDaysAgo }
    });

    const presentCount = recentAttendance.filter(a => a.status === 'present').length;
    const totalCount = recentAttendance.length;
    const attendanceRate = totalCount > 0 ? (presentCount / totalCount * 100).toFixed(1) : 0;

    res.json({
      success: true,
      student: {
        id: student._id,
        name: student.name,
        email: student.email,
        studentId: student.studentId,
        classId: student.classId?._id,
        className: student.classId?.name,
        companyId: student.companyId?._id,
        companyName: student.companyId?.name,
        status: 'active', // Could be enhanced with more status logic
        recentAttendance: {
          total: totalCount,
          present: presentCount,
          rate: parseFloat(attendanceRate)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching student status:', error);
    res.status(500).json({ 
      error: 'Failed to load student status',
      success: false 
    });
  }
});

// Payments
app.get('/api/payments', verifyToken, async (req, res) => {
  try {
    const { classId, studentId, teacherId } = req.query;
    let query = {};
    // Normalize classId to ObjectId if provided
    let classObjectId = null;
    if (classId) {
      if (typeof classId === 'string' && classId.match(/^[0-9a-fA-F]{24}$/)) {
        classObjectId = new mongoose.Types.ObjectId(classId);
        query.classId = classObjectId;
      } else {
        // keep as-is (could be other form) or reject
        console.log('Invalid classId format in payments query:', classId);
        return res.status(400).json({ error: 'Invalid classId format' });
      }
    }
    if (studentId) query.studentId = studentId;

    if (teacherId) {
      // Find teacher by teacherId string and get their classes
      console.log('Filtering payments for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        const classIds = classes.map(c => c._id.toString());

        // If a specific classId was requested, ensure it belongs to this teacher
        if (classObjectId) {
          if (!classIds.includes(classObjectId.toString())) {
            console.log('Requested classId does not belong to teacher:', classObjectId.toString());
            return res.json([]);
          }
          // query.classId already set to the specific classObjectId
        } else {
          // No specific class requested — restrict to all classes this teacher owns
          query.classId = { $in: classIds };
        }
        console.log('Found', classIds.length, 'classes for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty array');
        return res.json([]);
      }
    }

    const payments = await Payment.find(query).sort({ date: -1 });
    
    // Populate student and class names
    const paymentsWithDetails = await Promise.all(payments.map(async (payment) => {
      const student = await Student.findById(payment.studentId);
      const classDoc = await Class.findById(payment.classId);
      
      return {
        ...payment.toObject(),
        studentName: student ? student.name : 'Unknown Student',
        className: classDoc ? classDoc.name : 'Unknown Class'
      };
    }));
    
    res.json(paymentsWithDetails);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch payments' });
  }
});

app.post('/api/payments', verifyToken, async (req, res) => {
  try {
    const { studentId, classId, amount, type, date } = req.body;
    
    // Convert IDs to ObjectId if they're strings
    let studentObjectId = studentId;
    let classObjectId = classId;
    
    if (typeof studentId === 'string' && studentId.match(/^[0-9a-fA-F]{24}$/)) {
      studentObjectId = new mongoose.Types.ObjectId(studentId);
    }
    if (typeof classId === 'string' && classId.match(/^[0-9a-fA-F]{24}$/)) {
      classObjectId = new mongoose.Types.ObjectId(classId);
    }
    
    // Use provided date or current date for when the payment was recorded
    let paymentDate;
    if (date) {
      paymentDate = new Date(date);
    } else {
      paymentDate = new Date();
    }
    
    const payment = new Payment({ 
      studentId: studentObjectId, 
      classId: classObjectId, 
      amount, 
      type, 
      date: paymentDate 
    });
    await payment.save();
    res.status(201).json(payment);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create payment' });
  }
});

app.delete('/api/payments/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    await Payment.findByIdAndDelete(id);
    res.status(200).json({ message: 'Payment deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete payment' });
  }
});

// Subscription Activation
app.post('/api/auth/activate-subscription', async (req, res) => {
  try {
    const { email, subscriptionType } = req.body;

    if (!email || !subscriptionType) {
      return res.status(400).json({ error: 'Email and subscription type are required' });
    }

    if (!['monthly', 'yearly'].includes(subscriptionType)) {
      return res.status(400).json({ error: 'Invalid subscription type. Must be monthly or yearly' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const teacher = await Teacher.findOne({ email: normalizedEmail });

    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    // Calculate new expiry date
    const now = new Date();
    let expiryDate;

    if (subscriptionType === 'monthly') {
      expiryDate = new Date(now);
      expiryDate.setMonth(expiryDate.getMonth() + 1);
    } else if (subscriptionType === 'yearly') {
      expiryDate = new Date(now);
      expiryDate.setFullYear(expiryDate.getFullYear() + 1);
    }

    // Update teacher subscription
    teacher.subscriptionType = subscriptionType;
    teacher.subscriptionStartDate = now;
    teacher.subscriptionExpiryDate = expiryDate;
    teacher.status = 'active'; // Reactivate if was inactive

    await teacher.save();

    // Send FCM notification to teacher
    await sendFCMNotificationToTeacher(
      teacher._id,
      'Subscription Activated! 🎉',
      `Your ${subscriptionType} subscription has been activated. Valid until ${expiryDate.toLocaleDateString()}`,
      {
        type: 'subscription_activated',
        subscriptionType: subscriptionType,
        expiryDate: expiryDate.toISOString()
      }
    ).catch(err => console.log('FCM notification failed:', err));

    res.json({
      message: 'Subscription activated successfully',
      subscriptionType: teacher.subscriptionType,
      subscriptionExpiryDate: teacher.subscriptionExpiryDate,
      status: teacher.status
    });
  } catch (error) {
    console.error('Error activating subscription:', error);
    res.status(500).json({ error: 'Failed to activate subscription' });
  }
});

// Submit Payment Proof
app.post('/api/auth/submit-payment-proof', upload.single('paymentProof'), async (req, res) => {
  try {
    const { userEmail, subscriptionType } = req.body;

    console.log('Payment Proof Submission:', {
      userEmail,
      subscriptionType,
      hasFile: !!req.file
    });

    if (!userEmail || !subscriptionType) {
      return res.status(400).json({ error: 'User email and subscription type are required' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'Payment proof image is required' });
    }

    // Validate subscription type
    if (!['monthly', 'yearly'].includes(subscriptionType)) {
      return res.status(400).json({ error: 'Invalid subscription type. Must be monthly or yearly' });
    }

    // First, verify that the teacher exists before processing payment
    const teacher = await Teacher.findOne({ email: userEmail });
    if (!teacher) {
      console.log('Teacher not found with email:', userEmail);
      return res.status(404).json({ error: 'Teacher email not found in the system. Please ensure you are using the correct email address.' });
    }

    // Get subscription amount
    const amount = subscriptionType === 'monthly' ? 'LKR 1,000' : 'LKR 8,000';

    // Upload image to Cloudinary
    const uploadResult = await new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder: 'payment-proofs',
          public_id: `payment_proof_${userEmail}_${Date.now()}`,
          resource_type: 'image'
        },
        (error, result) => {
          if (error) reject(error);
          else resolve(result);
        }
      );
      uploadStream.end(req.file.buffer);
    });

    // Save payment proof to database with Cloudinary URL
    const paymentProof = new PaymentProof({
      userEmail,
      subscriptionType,
      amount,
      paymentProofUrl: uploadResult.secure_url,
      paymentProofPublicId: uploadResult.public_id
    });
    await paymentProof.save();
    
    // Update teacher subscription status to pending (teacher already verified to exist)
    teacher.subscriptionStatus = 'pending';
    await teacher.save();

    console.log(`Payment proof submitted successfully for ${userEmail} (${subscriptionType}) - Cloudinary URL: ${uploadResult.secure_url}`);

    res.json({
      message: 'Payment proof submitted successfully! Your payment will be reviewed and your account will be activated within 24 hours.',
      subscriptionType,
      amount
    });

  } catch (error) {
    console.error('Error submitting payment proof:', error);
    res.status(500).json({ error: 'Failed to submit payment proof' });
  }
});

// Super admin verification middleware
const verifySuperAdmin = async (req, res, next) => {
  try {
    // First verify the token
    const token = req.headers.authorization?.replace('Bearer ', '');
    const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, jwtSecret);
    req.user = decoded;
    
    // Check if user is super-admin
    const admin = await Admin.findById(decoded.userId);
    if (!admin || admin.role !== 'super-admin') {
      return res.status(403).json({ error: 'Super admin access required' });
    }
    
    next();
  } catch (error) {
    console.error('Super admin verification error:', error.message);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Teacher verification middleware
const verifyTeacher = async (req, res, next) => {
  try {
    // First verify the token
    const token = req.headers.authorization?.replace('Bearer ', '');
    const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, jwtSecret);
    req.user = decoded;
    
    // Check if user is teacher
    if (decoded.userType !== 'teacher') {
      return res.status(403).json({ error: 'Teacher access required' });
    }
    
    next();
  } catch (error) {
    console.error('Teacher verification error:', error.message);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// GET payment proofs for admin review
app.get('/api/admin/payment-proofs', verifySuperAdmin, async (req, res) => {
  try {
    const paymentProofs = await PaymentProof.find().sort({ createdAt: -1 });
    // Format dates for all payment proofs
    const formattedProofs = paymentProofs.map(proof => {
      const proofObj = proof.toObject();
      proofObj.createdAt = formatDateWithTimezone(new Date(proof.createdAt));
      proofObj.updatedAt = formatDateWithTimezone(new Date(proof.updatedAt));
      if (proof.reviewedAt) {
        proofObj.reviewedAt = formatDateWithTimezone(new Date(proof.reviewedAt));
      }
      return proofObj;
    });
    res.json(formattedProofs);
  } catch (error) {
    console.error('Error fetching payment proofs:', error);
    res.status(500).json({ error: 'Failed to fetch payment proofs' });
  }
});

// GET payment proof image
app.get('/api/admin/payment-proofs/:id/image', verifySuperAdmin, async (req, res) => {
  try {
    const paymentProof = await PaymentProof.findById(req.params.id);
    if (!paymentProof) {
      return res.status(404).json({ error: 'Payment proof not found' });
    }

    // Redirect to Cloudinary URL
    res.redirect(paymentProof.paymentProofUrl);
  } catch (error) {
    console.error('Error fetching payment proof image:', error);
    res.status(500).json({ error: 'Failed to fetch payment proof image' });
  }
});

// POST approve/reject payment proof
app.post('/api/admin/payment-proofs/:id/review', verifySuperAdmin, async (req, res) => {
  try {
    const { action, notes, adminEmail, rejectionReason } = req.body; // action: 'approve' or 'reject'

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Invalid action. Must be approve or reject' });
    }

    const paymentProof = await PaymentProof.findById(req.params.id);
    if (!paymentProof) {
      return res.status(404).json({ error: 'Payment proof not found' });
    }

    if (paymentProof.status !== 'pending') {
      return res.status(400).json({ error: 'Payment proof has already been reviewed' });
    }

    // Update payment proof status
    paymentProof.status = action === 'approve' ? 'approved' : 'rejected';
    paymentProof.reviewedBy = adminEmail;
    paymentProof.reviewedAt = new Date();
    paymentProof.reviewNotes = notes || '';
    paymentProof.rejectionReason = action === 'reject' ? (rejectionReason || notes) : undefined;
    await paymentProof.save();

    // If approved, activate the teacher's account and set subscription
    if (action === 'approve') {
      const teacher = await Teacher.findOne({ email: paymentProof.userEmail });
      if (teacher) {
        teacher.status = 'active';
        teacher.subscriptionStatus = 'active';
        teacher.subscriptionType = paymentProof.subscriptionType;
        teacher.subscriptionStartDate = new Date();
        
        // Set expiry date based on subscription type
        const expiryDate = new Date();
        if (paymentProof.subscriptionType === 'monthly') {
          expiryDate.setMonth(expiryDate.getMonth() + 1);
        } else if (paymentProof.subscriptionType === 'yearly') {
          expiryDate.setFullYear(expiryDate.getFullYear() + 1);
        }
        teacher.subscriptionExpiryDate = expiryDate;
        teacher.isFirstLogin = false;
        
        await teacher.save();

        // Send FCM notification to teacher
        await sendFCMNotificationToTeacher(
          teacher._id,
          'Subscription Approved! 🎉',
          `Your payment proof has been approved. Your ${paymentProof.subscriptionType} subscription is now active!`,
          {
            type: 'subscription_approved',
            subscriptionType: paymentProof.subscriptionType,
            expiryDate: expiryDate.toISOString()
          }
        ).catch(err => console.log('FCM notification failed:', err));

        // Send confirmation email to teacher
        const mailOptions = {
          from: process.env.EMAIL_USER,
          to: paymentProof.userEmail,
          subject: 'Subscription Activated - Teacher Attendance App',
          html: `
            <h2>Subscription Activated!</h2>
            <p>Dear Teacher,</p>
            <p>Your payment proof has been reviewed and approved. Your account has been activated successfully.</p>
            <p><strong>Subscription Details:</strong></p>
            <ul>
              <li>Type: ${paymentProof.subscriptionType}</li>
              <li>Amount: ${paymentProof.amount}</li>
              <li>Valid Until: ${expiryDate.toLocaleDateString()}</li>
            </ul>
            <p>You can now start using the Teacher Attendance App with full features.</p>
            <br>
            <p>Best regards,<br>Teacher Attendance App Team</p>
          `
        };

        transporter.sendMail(mailOptions).catch(error => {
          console.error('Error sending activation email:', error);
        });
      }
    } else {
      // If rejected, update teacher subscription status to rejected
      const teacher = await Teacher.findOne({ email: paymentProof.userEmail });
      if (teacher) {
        teacher.subscriptionStatus = 'rejected';
        teacher.status = 'inactive';
        await teacher.save();

        // Send FCM notification to teacher about rejection
        await sendFCMNotificationToTeacher(
          teacher._id,
          'Payment Proof Rejected',
          `Your payment proof was not approved. Reason: ${rejectionReason || notes || 'Please resubmit with correct details'}`,
          {
            type: 'subscription_rejected',
            reason: rejectionReason || notes || 'No reason provided'
          }
        ).catch(err => console.log('FCM notification failed:', err));
      }
      
      // Delete the image from Cloudinary
      try {
        await cloudinary.uploader.destroy(paymentProof.paymentProofPublicId);
        console.log(`Deleted rejected payment proof from Cloudinary: ${paymentProof.paymentProofPublicId}`);
      } catch (cloudinaryError) {
        console.error('Error deleting image from Cloudinary:', cloudinaryError);
      }

      // Send rejection email with reason
      const mailOptions = {
        from: process.env.EMAIL_USER,
        to: paymentProof.userEmail,
        subject: 'Payment Proof Rejected - Teacher Attendance App',
        html: `
          <h2>Payment Proof Review</h2>
          <p>Dear Teacher,</p>
          <p>Your payment proof has been reviewed but was not approved.</p>
          <p><strong>Reason for Rejection:</strong> ${rejectionReason || notes || 'No specific reason provided'}</p>
          <p><strong>Subscription Details:</strong></p>
          <ul>
            <li>Type: ${paymentProof.subscriptionType}</li>
            <li>Amount: ${paymentProof.amount}</li>
          </ul>
          <p>Please submit a new payment proof with the correct information.</p>
          <br>
          <p>Best regards,<br>Teacher Attendance App Team</p>
        `
      };

      transporter.sendMail(mailOptions).catch(error => {
        console.error('Error sending rejection email:', error);
      });
    }

    res.json({
      message: `Payment proof ${action}d successfully`,
      paymentProof: {
        id: paymentProof._id,
        status: paymentProof.status,
        reviewedBy: paymentProof.reviewedBy,
        reviewedAt: paymentProof.reviewedAt,
        reviewNotes: paymentProof.reviewNotes,
        rejectionReason: paymentProof.rejectionReason
      }
    });

  } catch (error) {
    console.error('Error reviewing payment proof:', error);
    res.status(500).json({ error: 'Failed to review payment proof' });
  }
});

// Teachers
app.get('/api/teachers', verifyToken, async (req, res) => {
  const debugLog = [];
  try {
    const { status, companyId } = req.query;
    debugLog.push(`[TEACHERS API] GET /api/teachers called at ${new Date().toISOString()}`);
    debugLog.push(`[TEACHERS API] Query params: status=${status}, companyId=${companyId}`);
    console.log('=== GET /api/teachers ===');
    console.log('Query params:', { status, companyId });

    let query = {};
    if (status) {
      query.status = status;
      debugLog.push(`[TEACHERS API] Filtering by status: ${status}`);
    }
    
    // Filter by companyId if provided (for multi-tenant support)
    // Teachers can belong to multiple companies, so check if companyId is in the array
    if (companyId) {
      // Use $in operator to check if companyId exists in the companyIds array
      query.companyIds = { $in: [companyId] };
      debugLog.push(`[TEACHERS API] Filtering by companyId: ${companyId}`);
      debugLog.push(`[TEACHERS API] Using $in operator to search in companyIds array`);
      console.log('Filtering teachers by companyId:', companyId);
    } else {
      debugLog.push(`[TEACHERS API] No companyId filter - will return ALL teachers`);
    }
    
    debugLog.push(`[TEACHERS API] MongoDB query: ${JSON.stringify(query)}`);
    console.log('Executing Teacher.find with query:', JSON.stringify(query));
    
    const teachers = await Teacher.find(query);
    debugLog.push(`[TEACHERS API] Found ${teachers.length} teachers`);
    console.log(`Found ${teachers.length} teachers for company ${companyId || 'all'}`);
    
    // Log teacher details for debugging
    if (teachers.length > 0) {
      const teacherDetails = teachers.map(t => ({
        _id: t._id.toString(),
        teacherId: t.teacherId,
        name: t.name,
        email: t.email,
        companyIds: t.companyIds ? t.companyIds.map(id => id.toString()) : [],
        companyIdsCount: t.companyIds ? t.companyIds.length : 0
      }));
      debugLog.push(`[TEACHERS API] Teachers details: ${JSON.stringify(teacherDetails, null, 2)}`);
      console.log('Teachers found:', teacherDetails);
    } else {
      debugLog.push(`[TEACHERS API] No teachers found matching query`);
      
      // Additional debugging: count all teachers
      const totalTeachers = await Teacher.countDocuments({});
      debugLog.push(`[TEACHERS API] Total teachers in database: ${totalTeachers}`);
      console.log(`Total teachers in database: ${totalTeachers}`);
      
      if (companyId && totalTeachers > 0) {
        // Check if any teacher has this companyId
        const teachersWithCompany = await Teacher.find({ companyIds: companyId });
        debugLog.push(`[TEACHERS API] Teachers with exact companyId match: ${teachersWithCompany.length}`);
        console.log(`Teachers with companyId ${companyId}:`, teachersWithCompany.length);
        
        // List all teachers with their companyIds
        const allTeachers = await Teacher.find({}).select('teacherId name companyIds');
        debugLog.push(`[TEACHERS API] All teachers in DB:`);
        allTeachers.forEach(t => {
          const companies = t.companyIds ? t.companyIds.map(id => id.toString()) : [];
          debugLog.push(`  - ${t.teacherId} (${t.name}): companies=[${companies.join(', ')}]`);
          console.log(`  Teacher ${t.teacherId}:`, companies);
        });
      }
    }
    
    // Send debug logs in response headers (encoded for HTTP header safety)
    const debugHeader = Buffer.from(debugLog.join('\n')).toString('base64');
    res.setHeader('X-Debug-Log', debugHeader);
    
    res.json(teachers);
  } catch (error) {
    console.error('Error fetching teachers:', error);
    debugLog.push(`[TEACHERS API] ERROR: ${error.message}`);
    const debugHeader = Buffer.from(debugLog.join('\n')).toString('base64');
    res.setHeader('X-Debug-Log', debugHeader);
    res.status(500).json({ error: 'Failed to fetch teachers' });
  }
});

app.get('/api/teachers/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Try to find by teacherId first, then by _id if that fails
    let teacher = await Teacher.findOne({ teacherId: id }).select('-password');
    
    // If not found by teacherId, try by _id (only if id looks like a valid ObjectId)
    if (!teacher && id.match(/^[0-9a-fA-F]{24}$/)) {
      teacher = await Teacher.findById(id).select('-password');
    }
    
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    res.json(teacher);
  } catch (error) {
    console.error('Error fetching teacher:', error);
    res.status(500).json({ error: 'Failed to fetch teacher', message: error.message });
  }
});

app.post('/api/teachers', verifyToken, async (req, res) => {
  try {
    const { name, email, phone, password, teacherId, status = 'inactive' } = req.body;
    
    // Auto-generate teacherId if not provided
    let finalTeacherId = teacherId;
    if (!finalTeacherId) {
      // Generate a unique teacher ID based on timestamp and random number
      const timestamp = Date.now().toString().slice(-6);
      const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
      finalTeacherId = `TCH${timestamp}${random}`;
      
      // Check if it already exists, if so, regenerate
      let existingTeacher = await Teacher.findOne({ teacherId: finalTeacherId });
      while (existingTeacher) {
        const newRandom = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
        finalTeacherId = `TCH${timestamp}${newRandom}`;
        existingTeacher = await Teacher.findOne({ teacherId: finalTeacherId });
      }
    }
    
    // Hash the password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    
    // Create teacher WITHOUT companyId - will be added when they scan QR
    const teacher = new Teacher({ 
      name, 
      email, 
      phone, 
      password: hashedPassword, 
      teacherId: finalTeacherId, 
      status,
      companyIds: [] // Initialize empty array
    });
    await teacher.save();
    res.status(201).json(teacher);
  } catch (error) {
    console.error('Error creating teacher:', error);
    res.status(500).json({ error: 'Failed to create teacher' });
  }
});

app.put('/api/teachers/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, phone, password, status, profilePicture } = req.body;
    
    console.log('Update teacher request - ID:', id);
    console.log('Update data received:', { name, email, phone, status, profilePicture });
    
    // Prepare update object
    const updateData = { name, email, phone, status };
    
    // Add profilePicture to update data if provided
    if (profilePicture !== undefined) {
      updateData.profilePicture = profilePicture;
      console.log('ProfilePicture added to update:', profilePicture);
    }
    
    // Hash password if provided
    if (password) {
      const saltRounds = 10;
      updateData.password = await bcrypt.hash(password, saltRounds);
    }
    
    console.log('Final update data:', updateData);
    
    // Try to find and update by teacherId first, then by _id if that fails
    let updatedTeacher = await Teacher.findOneAndUpdate(
      { teacherId: id }, 
      updateData, 
      { new: true }
    );
    
    // If not found by teacherId, try by _id
    if (!updatedTeacher) {
      updatedTeacher = await Teacher.findByIdAndUpdate(id, updateData, { new: true });
    }
    
    if (!updatedTeacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    
    console.log('Teacher updated successfully:', updatedTeacher.toObject());
    res.status(200).json(updatedTeacher);
  } catch (error) {
    console.error('Error updating teacher:', error);
    res.status(500).json({ error: 'Failed to update teacher' });
  }
});

app.put('/api/teachers/:id/status', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!['active', 'inactive'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status. Must be active or inactive' });
    }
    
    const updatedTeacher = await Teacher.findByIdAndUpdate(id, { status }, { new: true });
    if (!updatedTeacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    res.status(200).json(updatedTeacher);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update teacher status' });
  }
});

app.delete('/api/teachers/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    console.log('DELETE /api/teachers/:id called with id:', id);
    
    // Find the teacher first to get their information
    const teacher = await Teacher.findById(id);
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    
    console.log('Deleting teacher:', teacher.name, teacher.email);
    
    // Delete the teacher
    await Teacher.findByIdAndDelete(id);
    
    // Clean up active sessions for this teacher
    try {
      // Find and delete any active web sessions for this teacher
      const WebSession = mongoose.model('WebSession');
      const deletedSessions = await WebSession.deleteMany({ userId: teacher._id });
      console.log(`Cleaned up ${deletedSessions.deletedCount} active web sessions for teacher ${teacher.name}`);
      
      // Also clean up any socket connections if they exist
      // This would require additional logic to disconnect active sockets
    } catch (sessionError) {
      console.error('Error cleaning up sessions:', sessionError);
      // Don't fail the deletion if session cleanup fails
    }
    
    res.status(200).json({ 
      message: 'Teacher deleted successfully',
      teacherName: teacher.name 
    });
  } catch (error) {
    console.error('Error deleting teacher:', error);
    res.status(500).json({ error: 'Failed to delete teacher', details: error.message });
  }
});

// GET teacher status
app.get('/api/teachers/:id/status', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const teacher = await Teacher.findById(id);
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    res.json({ status: teacher.status });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch teacher status' });
  }
});

// PUT activate teacher
app.put('/api/teachers/:id/activate', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const updatedTeacher = await Teacher.findByIdAndUpdate(id, { status: 'active' }, { new: true });
    if (!updatedTeacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    res.json(updatedTeacher);
  } catch (error) {
    res.status(500).json({ error: 'Failed to activate teacher' });
  }
});

// POST submit problem report with optional images
app.post('/api/reports/problem', verifyToken, upload.array('images', 5), async (req, res) => {
  try {
    const { userEmail, issueDescription, appVersion, device, deviceName, teacherId, studentId, userType } = req.body;
    if (!userEmail || !issueDescription || !userType) {
      return res.status(400).json({ error: 'userEmail, issueDescription, and userType are required' });
    }

    // Validate userType
    if (!['teacher', 'student'].includes(userType)) {
      return res.status(400).json({ error: 'userType must be either teacher or student' });
    }

    // Handle image uploads to Cloudinary
    let images = [];
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        try {
          const result = await new Promise((resolve, reject) => {
            const uploadStream = cloudinary.uploader.upload_stream(
              {
                folder: 'problem-reports',
                resource_type: 'auto',
              },
              (error, result) => {
                if (error) reject(error);
                else resolve(result);
              }
            );
            uploadStream.end(file.buffer);
          });

          images.push({
            url: result.secure_url,
            publicId: result.public_id
          });
        } catch (error) {
          console.error('Error uploading image to Cloudinary:', error);
          // Continue with other images even if one fails
        }
      }
    }

    // Save the report to database
    const report = new ProblemReport({
      userEmail,
      issueDescription,
      appVersion,
      device,
      deviceName,
      teacherId,
      studentId,
      userType,
      images
    });
    await report.save();

    res.status(201).json({ 
      message: 'Problem report submitted successfully',
      reportId: report._id,
      images: images.length
    });
  } catch (error) {
    console.error('Error submitting problem report:', error);
    res.status(500).json({ error: 'Failed to submit problem report' });
  }
});

// DELETE image from problem report
app.delete('/api/reports/problem/:reportId/image/:publicId', verifyToken, async (req, res) => {
  try {
    const { reportId, publicId } = req.params;

    // Delete from Cloudinary
    try {
      await cloudinary.uploader.destroy(publicId);
    } catch (error) {
      console.error('Error deleting image from Cloudinary:', error);
    }

    // Update the report in database
    const report = await ProblemReport.findByIdAndUpdate(
      reportId,
      { $pull: { images: { publicId: publicId } } },
      { new: true }
    );

    if (!report) {
      return res.status(404).json({ error: 'Report not found' });
    }

    res.json({ message: 'Image deleted successfully', report });
  } catch (error) {
    console.error('Error deleting image:', error);
    res.status(500).json({ error: 'Failed to delete image' });
  }
});

// POST submit feature request
app.post('/api/reports/feature-request', verifyToken, async (req, res) => {
  try {
    const { userEmail, featureDescription, bidPrice, appVersion, device, deviceName, teacherId, studentId, userType } = req.body;
    if (!userEmail || !featureDescription || !bidPrice || !userType) {
      return res.status(400).json({ error: 'userEmail, featureDescription, bidPrice, and userType are required' });
    }

    // Validate userType
    if (!['teacher', 'student'].includes(userType)) {
      return res.status(400).json({ error: 'userType must be either teacher or student' });
    }

    // Validate bidPrice
    const price = parseFloat(bidPrice);
    if (isNaN(price) || price < 0) {
      return res.status(400).json({ error: 'bidPrice must be a valid positive number' });
    }

    // Save the feature request to database
    const featureRequest = new FeatureRequest({
      userEmail,
      featureDescription,
      bidPrice: price,
      appVersion,
      device,
      deviceName,
      teacherId,
      studentId,
      userType,
      status: 'pending'
    });
    await featureRequest.save();

    res.status(201).json({ message: 'Feature request submitted successfully' });
  } catch (error) {
    console.error('Error submitting feature request:', error);
    res.status(500).json({ error: 'Failed to submit feature request' });
  }
});

// GET problem reports
app.get('/api/reports/problems', verifySuperAdmin, async (req, res) => {
  try {
    const reports = await ProblemReport.find().sort({ createdAt: -1 });
    // Format dates for all reports
    const formattedReports = reports.map(report => {
      const reportObj = report.toObject();
      reportObj.createdAt = formatDateWithTimezone(new Date(report.createdAt));
      reportObj.updatedAt = formatDateWithTimezone(new Date(report.updatedAt));
      return reportObj;
    });
    res.json(formattedReports);
  } catch (error) {
    console.error('Error fetching problem reports:', error);
    res.status(500).json({ error: 'Failed to fetch problem reports' });
  }
});

// GET feature requests (super admin only)
app.get('/api/reports/feature-requests', verifySuperAdmin, async (req, res) => {
  try {
    const requests = await FeatureRequest.find().sort({ createdAt: -1 });
    // Format dates for all requests
    const formattedRequests = requests.map(request => {
      const requestObj = request.toObject();
      requestObj.createdAt = formatDateWithTimezone(new Date(request.createdAt));
      requestObj.updatedAt = formatDateWithTimezone(new Date(request.updatedAt));
      return requestObj;
    });
    res.json(formattedRequests);
  } catch (error) {
    console.error('Error fetching feature requests:', error);
    res.status(500).json({ error: 'Failed to fetch feature requests' });
  }
});

app.get('/api/reports/attendance-summary', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.query;
    const today = new Date();
    // Use local dates for consistent date filtering to match how attendance is stored
    const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const endOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);

    let studentQuery = {};
    let attendanceQuery = { date: { $gte: startOfDay, $lt: endOfDay } };

    if (teacherId) {
      // Find teacher by teacherId string and get their students
      console.log('Filtering attendance summary for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        const classIds = classes.map(c => c._id);
        const students = await Student.find({ classId: { $in: classIds } });
        const studentIds = students.map(s => s._id);
        studentQuery._id = { $in: studentIds };
        attendanceQuery.studentId = { $in: studentIds };
        console.log('Found', studentIds.length, 'students for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning zeros');
        return res.json({
          totalStudents: 0,
          presentToday: 0,
          absentToday: 0,
          lateToday: 0
        });
      }
    }

    // Total students
    const totalStudents = await Student.countDocuments(studentQuery);

    // Today's attendance
    const todayAttendance = await Attendance.find(attendanceQuery);

    const presentToday = todayAttendance.filter(a => a.status === 'present').length;
    const absentToday = todayAttendance.filter(a => a.status === 'absent').length;
    const lateToday = todayAttendance.filter(a => a.status === 'late').length;

    res.json({
      totalStudents,
      presentToday,
      absentToday,
      lateToday
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch attendance summary' });
  }
});

app.get('/api/reports/student-reports', verifyToken, async (req, res) => {
  try {
    const { teacherId, month, year, classId } = req.query;

    let studentQuery = {};

    // If classId is provided, prefer filtering by that single class (but validate format)
    let classObjectId = null;
    if (classId) {
      if (typeof classId === 'string' && classId.match(/^[0-9a-fA-F]{24}$/)) {
        classObjectId = new mongoose.Types.ObjectId(classId);
        studentQuery.classId = classObjectId;
      } else {
        console.log('Invalid classId provided to student-reports:', classId);
        return res.status(400).json({ error: 'Invalid classId format' });
      }
    }

    if (teacherId) {
      // Find teacher by teacherId string and get their classes
      console.log('Filtering student reports for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        const classIds = classes.map(c => c._id.toString());

        // If a specific classId was provided, ensure it belongs to this teacher
        if (classObjectId) {
          if (!classIds.includes(classObjectId.toString())) {
            console.log('Requested classId does not belong to teacher:', classObjectId.toString());
            return res.json([]);
          }
          // studentQuery.classId already set to the specific class
        } else {
          // No specific class requested — filter to all classes for this teacher
          studentQuery.classId = { $in: classIds };
        }

        console.log('Found', classIds.length, 'classes for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty array');
        return res.json([]);
      }
    }

    const students = await Student.find(studentQuery);
    const reports = [];

    for (const student of students) {
      let attendanceQuery = { studentId: student._id };
      if (month) attendanceQuery.month = parseInt(month);
      if (year) attendanceQuery.year = parseInt(year);

      const attendanceRecords = await Attendance.find(attendanceQuery);
      const totalRecords = attendanceRecords.length;
      const presentCount = attendanceRecords.filter(a => a.status === 'present').length;
      const absentCount = attendanceRecords.filter(a => a.status === 'absent').length;
      const lateCount = attendanceRecords.filter(a => a.status === 'late').length;

      const attendanceRate = totalRecords > 0 ? (presentCount / totalRecords) * 100 : 0;

      // Get class name
      const classDoc = await Class.findById(student.classId);

      reports.push({
        studentId: student._id,
        studentName: student.name,
        classId: student.classId,
        className: classDoc ? classDoc.name : 'Unknown Class',
        totalRecords,
        presentCount,
        absentCount,
        lateCount,
        attendanceRate
      });
    }

    res.json(reports);
  } catch (error) {
    console.error('Error in student-reports:', error);
    res.status(500).json({ error: 'Failed to fetch student reports' });
  }
});

app.get('/api/reports/monthly-stats', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.query;

    let studentIds = null;
    if (teacherId) {
      // Find teacher by teacherId string and get their students
      console.log('Filtering monthly stats for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        const classIds = classes.map(c => c._id);
        const students = await Student.find({ classId: { $in: classIds } });
        studentIds = students.map(s => s._id);
        console.log('Found', studentIds.length, 'students for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty array');
        return res.json([]);
      }
    }

    let pipeline = [
      {
        $group: {
          _id: { year: '$year', month: '$month' },
          presentCount: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          absentCount: { $sum: { $cond: [{ $eq: ['$status', 'absent'] }, 1, 0] } },
          lateCount: { $sum: { $cond: [{ $eq: ['$status', 'late'] }, 1, 0] } },
          totalRecords: { $sum: 1 }
        }
      },
      {
        $project: {
          year: '$_id.year',
          month: '$_id.month',
          presentCount: 1,
          absentCount: 1,
          lateCount: 1,
          totalRecords: 1,
          averageRate: {
            $cond: {
              if: { $gt: ['$totalRecords', 0] },
              then: { $multiply: [{ $divide: ['$presentCount', '$totalRecords'] }, 100] },
              else: 0
            }
          }
        }
      },
      { $sort: { year: -1, month: -1 } },
      { $limit: 12 }
    ];

    // Add match stage if filtering by teacher
    if (studentIds) {
      pipeline.unshift({
        $match: { studentId: { $in: studentIds } }
      });
    }

    const monthlyStats = await Attendance.aggregate(pipeline);

    res.json(monthlyStats);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch monthly stats' });
  }
});

// Monthly earnings by class - allows teacher to check how much each class earned each month
app.get('/api/reports/monthly-earnings-by-class', verifyToken, async (req, res) => {
  try {
    const { teacherId, year, month } = req.query;

    if (!teacherId) {
      return res.status(400).json({ error: 'teacherId is required' });
    }

    // Find teacher by teacherId string
    const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
    if (!teacher) {
      console.log('Teacher not found for teacherId:', teacherId);
      return res.json([]);
    }

    // Get all classes for this teacher
    const classes = await Class.find({ teacherId: teacher._id });
    
    const earningsReports = [];

    for (const classDoc of classes) {
      // Get all students in this class
      const students = await Student.find({ classId: classDoc._id });
      const studentIds = students.map(s => s._id);

      // Build payment query for this class
      let paymentQuery = { 
        classId: classDoc._id,
        studentId: { $in: studentIds }
      };

      // Add date filters if provided
      if (year && month) {
        const startDate = new Date(parseInt(year), parseInt(month) - 1, 1);
        const endDate = new Date(parseInt(year), parseInt(month), 0, 23, 59, 59);
        paymentQuery.date = { $gte: startDate, $lte: endDate };
      } else if (year) {
        const startDate = new Date(parseInt(year), 0, 1);
        const endDate = new Date(parseInt(year), 11, 31, 23, 59, 59);
        paymentQuery.date = { $gte: startDate, $lte: endDate };
      }

      // Get all payments for this class
      const payments = await Payment.find(paymentQuery);

      // Calculate total earnings
      const totalEarnings = payments.reduce((sum, payment) => sum + (payment.amount || 0), 0);

      // Group by month if no specific month provided
      const monthlyBreakdown = {};
      payments.forEach(payment => {
        if (payment.date) {
          const paymentDate = new Date(payment.date);
          const paymentMonth = payment.month || (paymentDate.getMonth() + 1);
          const monthKey = `${paymentDate.getFullYear()}-${String(paymentMonth).padStart(2, '0')}`;
          
          if (!monthlyBreakdown[monthKey]) {
            monthlyBreakdown[monthKey] = {
              year: paymentDate.getFullYear(),
              month: paymentMonth,
              amount: 0,
              paymentCount: 0
            };
          }
          
          monthlyBreakdown[monthKey].amount += payment.amount || 0;
          monthlyBreakdown[monthKey].paymentCount += 1;
        }
      });

      earningsReports.push({
        classId: classDoc._id.toString(),
        className: classDoc.name,
        studentCount: students.length,
        totalEarnings: totalEarnings,
        paymentCount: payments.length,
        monthlyBreakdown: Object.values(monthlyBreakdown).sort((a, b) => {
          if (a.year !== b.year) return b.year - a.year;
          return b.month - a.month;
        })
      });
    }

    // Sort by total earnings descending
    earningsReports.sort((a, b) => b.totalEarnings - a.totalEarnings);

    res.json(earningsReports);
  } catch (error) {
    console.error('Error in monthly-earnings-by-class:', error);
    res.status(500).json({ error: 'Failed to fetch monthly earnings by class' });
  }
});

// Daily attendance by class
app.get('/api/reports/daily-by-class', verifyToken, async (req, res) => {
  try {
    const { teacherId, date } = req.query;
    
    // Use today if no date provided
    const targetDate = date ? new Date(date) : new Date();
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    let classQuery = {};
    if (teacherId) {
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        classQuery.teacherId = teacher._id;
      } else {
        return res.json([]);
      }
    }

    const classes = await Class.find(classQuery);
    const reports = [];

    for (const classObj of classes) {
      const students = await Student.find({ classId: classObj._id });
      const studentIds = students.map(s => s._id);
      
      const todayAttendance = await Attendance.find({
        studentId: { $in: studentIds },
        date: { $gte: startOfDay, $lt: endOfDay }
      });

      const presentCount = todayAttendance.filter(a => a.status === 'present').length;
      const absentCount = todayAttendance.filter(a => a.status === 'absent').length;
      const lateCount = todayAttendance.filter(a => a.status === 'late').length;
      const totalStudents = students.length;
      const attendanceRate = totalStudents > 0 ? ((presentCount + lateCount) / totalStudents) * 100 : 0;

      reports.push({
        classId: classObj._id,
        className: classObj.name,
        totalStudents,
        presentCount,
        absentCount,
        lateCount,
        attendanceRate
      });
    }

    res.json(reports);
  } catch (error) {
    console.error('Error fetching daily attendance by class:', error);
    res.status(500).json({ error: 'Failed to fetch daily attendance by class' });
  }
});

// Monthly stats by class
app.get('/api/reports/monthly-by-class', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.query;

    let classQuery = {};
    if (teacherId) {
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        classQuery.teacherId = teacher._id;
      } else {
        return res.json([]);
      }
    }

    const classes = await Class.find(classQuery);
    const reports = [];

    for (const classObj of classes) {
      const students = await Student.find({ classId: classObj._id });
      const studentIds = students.map(s => s._id);

      if (studentIds.length === 0) {
        continue;
      }

      // Get attendance records grouped by year, month, and date
      const dailyPipeline = [
        {
          $match: { studentId: { $in: studentIds } }
        },
        {
          $group: {
            _id: {
              year: '$year',
              month: '$month',
              date: '$date'
            },
            presentCount: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
            absentCount: { $sum: { $cond: [{ $eq: ['$status', 'absent'] }, 1, 0] } },
            lateCount: { $sum: { $cond: [{ $eq: ['$status', 'late'] }, 1, 0] } },
            totalRecorded: { $sum: 1 }
          }
        },
        {
          $project: {
            _id: 0,
            year: '$_id.year',
            month: '$_id.month',
            date: '$_id.date',
            presentCount: 1,
            absentCount: 1,
            lateCount: 1,
            totalRecorded: 1
          }
        },
        { $sort: { year: -1, month: -1, date: -1 } }
      ];

      const dailyStats = await Attendance.aggregate(dailyPipeline);

      // Group daily stats by month
      const monthlyStatsMap = {};
      dailyStats.forEach(stat => {
        const monthKey = `${stat.year}-${stat.month}`;
        if (!monthlyStatsMap[monthKey]) {
          monthlyStatsMap[monthKey] = {
            year: stat.year,
            month: stat.month,
            conductedDays: [],
            totalDays: 0
          };
        }
        monthlyStatsMap[monthKey].conductedDays.push({
          date: stat.date,
          presentCount: stat.presentCount,
          absentCount: stat.absentCount,
          lateCount: stat.lateCount,
          totalRecorded: stat.totalRecorded
        });
        monthlyStatsMap[monthKey].totalDays++;
      });

      // Convert to array and limit to last 12 months
      const monthlyStats = Object.values(monthlyStatsMap)
        .sort((a, b) => {
          if (b.year !== a.year) return b.year - a.year;
          return b.month - a.month;
        })
        .slice(0, 12);

      reports.push({
        classId: classObj._id,
        className: classObj.name,
        totalStudents: students.length,
        monthlyStats
      });
    }

    res.json(reports);
  } catch (error) {
    console.error('Error fetching monthly stats by class:', error);
    res.status(500).json({ error: 'Failed to fetch monthly stats by class' });
  }
});

// Get detailed student attendance for a specific class and month
app.get('/api/reports/class-student-details', verifyToken, async (req, res) => {
  try {
    const { classId, month, year } = req.query;

    if (!classId || !month || !year) {
      return res.status(400).json({ error: 'classId, month, and year are required' });
    }

    // Convert classId to ObjectId if it's a string
    let classObjectId = classId;
    if (typeof classId === 'string' && classId.match(/^[0-9a-fA-F]{24}$/)) {
      classObjectId = new mongoose.Types.ObjectId(classId);
    }

    // Get all students in the class
    const students = await Student.find({ classId: classObjectId });

    if (students.length === 0) {
      return res.json({
        className: '',
        totalStudents: 0,
        studentsDetails: []
      });
    }

    // Get class name
    const classObj = await Class.findById(classObjectId);
    const className = classObj ? classObj.name : 'Unknown Class';

    // Get all attendance records for this class in the specified month
    const studentIds = students.map(s => s._id);
    const attendanceRecords = await Attendance.find({
      studentId: { $in: studentIds },
      month: parseInt(month),
      year: parseInt(year)
    });

    // Calculate statistics for each student
    const studentsDetails = students.map(student => {
      const studentAttendance = attendanceRecords.filter(a => 
        a.studentId.toString() === student._id.toString()
      );

      const presentCount = studentAttendance.filter(a => a.status === 'present').length;
      const absentCount = studentAttendance.filter(a => a.status === 'absent').length;
      const lateCount = studentAttendance.filter(a => a.status === 'late').length;
      const totalClasses = studentAttendance.length;
      const attendanceRate = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0;

      return {
        studentId: student._id,
        studentName: student.name,
        studentIdNumber: student.studentId,
        presentCount,
        absentCount,
        lateCount,
        totalClasses,
        attendanceRate
      };
    }).sort((a, b) => b.attendanceRate - a.attendanceRate); // Sort by attendance rate descending

    res.json({
      className,
      totalStudents: students.length,
      month: parseInt(month),
      year: parseInt(year),
      studentsDetails
    });
  } catch (error) {
    console.error('Error fetching class student details:', error);
    res.status(500).json({ error: 'Failed to fetch class student details' });
  }
});

// Home Dashboard Endpoints
app.get('/api/home/stats', verifyToken, async (req, res) => {
  try {
    // Ensure database connection is fully ready
    await connectToDatabase();
    
    // Additional safety check for readyState
    if (mongoose.connection.readyState !== 1) {
      console.error('MongoDB not ready, readyState:', mongoose.connection.readyState);
      return res.status(503).json({ error: 'Database not ready' });
    }
    
    const { teacherId } = req.query;

    let classIds = null;
    let studentIds = null;
    if (teacherId) {
      // Find teacher by teacherId string and get their classes and students
      console.log('Filtering home stats for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        classIds = classes.map(c => c._id);
        const students = await Student.find({ classId: { $in: classIds } });
        studentIds = students.map(s => s._id);
        console.log('Found', classIds.length, 'classes and', studentIds.length, 'students for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning default stats');
        return res.json({
          totalStudents: 0,
          todayAttendancePercentage: 0.0,
          totalClasses: 0,
          paymentStatusPercentage: 0.0,
          studentsTrend: '0',
          attendanceTrend: '0%',
          classesTrend: '0',
          paymentTrend: '0%',
          studentsPositive: true,
          attendancePositive: true,
          classesPositive: true,
          paymentPositive: true,
        });
      }
    }

    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    // Get total students
    const totalStudents = studentIds ? studentIds.length : await Student.countDocuments();

    // Get total classes
    const totalClasses = classIds ? classIds.length : await Class.countDocuments();

    // Calculate today's attendance - Use local dates to match how attendance is stored
    const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const endOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
    let todayAttendanceQuery = {
      date: {
        $gte: startOfToday,
        $lt: endOfToday
      }
    };
    if (studentIds) {
      todayAttendanceQuery.studentId = { $in: studentIds };
    }
    const todayAttendance = await Attendance.find(todayAttendanceQuery);
    const presentCount = todayAttendance.filter(a => a.status.toLowerCase() === 'present').length;
    const todayAttendancePercentage = todayAttendance.length > 0 ? (presentCount / todayAttendance.length * 100) : 0.0;

    // Calculate yesterday's attendance for trend - Use local dates
    const startOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate());
    const endOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate() + 1);
    let yesterdayAttendanceQuery = {
      date: {
        $gte: startOfYesterday,
        $lt: endOfYesterday
      }
    };
    if (studentIds) {
      yesterdayAttendanceQuery.studentId = { $in: studentIds };
    }
    const yesterdayAttendance = await Attendance.find(yesterdayAttendanceQuery);
    const yesterdayPresentCount = yesterdayAttendance.filter(a => a.status.toLowerCase() === 'present').length;
    const yesterdayAttendancePercentage = yesterdayAttendance.length > 0 ? (yesterdayPresentCount / yesterdayAttendance.length * 100) : 0.0;

    const attendanceDiff = todayAttendancePercentage - yesterdayAttendancePercentage;
    const attendanceTrend = `${attendanceDiff >= 0 ? '+' : ''}${attendanceDiff.toFixed(1)}%`;
    const attendancePositive = attendanceDiff >= 0;

    // Calculate payment status (students who have paid this month)
    const currentMonth = today.getMonth();
    const currentYear = today.getFullYear();
    let monthPaymentsQuery = {
      date: {
        $gte: new Date(currentYear, currentMonth, 1),
        $lt: new Date(currentYear, currentMonth + 1, 1)
      }
    };
    if (classIds) {
      monthPaymentsQuery.classId = { $in: classIds };
    }
    const monthPayments = await Payment.find(monthPaymentsQuery);
    const uniquePayingStudents = new Set(monthPayments.map(p => p.studentId.toString())).size;
    const paymentStatusPercentage = totalStudents > 0 ? (uniquePayingStudents / totalStudents * 100) : 0.0;

    // Calculate last month's payment for trend
    const lastMonth = currentMonth === 0 ? 11 : currentMonth - 1;
    const lastMonthYear = currentMonth === 0 ? currentYear - 1 : currentYear;
    let lastMonthPaymentsQuery = {
      date: {
        $gte: new Date(lastMonthYear, lastMonth, 1),
        $lt: new Date(lastMonthYear, lastMonth + 1, 1)
      }
    };
    if (classIds) {
      lastMonthPaymentsQuery.classId = { $in: classIds };
    }
    const lastMonthPayments = await Payment.find(lastMonthPaymentsQuery);
    const lastMonthPayingStudents = new Set(lastMonthPayments.map(p => p.studentId.toString())).size;
    const lastMonthPaymentPercentage = totalStudents > 0 ? (lastMonthPayingStudents / totalStudents * 100) : 0.0;

    const paymentDiff = paymentStatusPercentage - lastMonthPaymentPercentage;
    const paymentTrend = `${paymentDiff >= 0 ? '+' : ''}${paymentDiff.toFixed(1)}%`;
    const paymentPositive = paymentDiff >= 0;

    // Calculate student trend (simple indicator)
    const studentsTrend = totalStudents > 10
      ? `+${Math.round(totalStudents * 0.05)}`
      : totalStudents > 5
      ? `+${Math.round(totalStudents * 0.1)}`
      : `+${totalStudents}`;
    const studentsPositive = true;

    // Calculate classes trend (simple indicator based on total)
    const classesTrend = totalClasses > 5
      ? '+1'
      : totalClasses > 0
      ? `+${totalClasses}`
      : '0';
    const classesPositive = totalClasses > 0;

    res.json({
      totalStudents,
      todayAttendancePercentage,
      totalClasses,
      paymentStatusPercentage,
      studentsTrend,
      attendanceTrend,
      classesTrend,
      paymentTrend,
      studentsPositive,
      attendancePositive,
      classesPositive,
      paymentPositive,
    });
  } catch (error) {
    console.error('Error fetching home stats:', error);
    
    // Check if it's a Mongoose buffer commands error
    if (error.message && error.message.includes('bufferCommands')) {
      console.error('MongoDB connection not ready when query attempted');
      console.error('Connection readyState:', mongoose.connection.readyState);
      return res.status(503).json({ 
        error: 'Database connection not ready', 
        message: 'Please try again in a moment' 
      });
    }
    
    res.status(500).json({ error: 'Failed to fetch home stats', message: error.message });
  }
});

app.get('/api/home/activities', verifyToken, async (req, res) => {
  try {
    // Ensure database connection is fully ready
    await connectToDatabase();
    
    // Additional safety check for readyState
    if (mongoose.connection.readyState !== 1) {
      console.error('MongoDB not ready, readyState:', mongoose.connection.readyState);
      return res.status(503).json({ error: 'Database not ready' });
    }
    
    const { teacherId } = req.query;

    let classIds = null;
    let studentIds = null;
    if (teacherId) {
      // Find teacher by teacherId string and get their classes and students
      console.log('Filtering home activities for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        classIds = classes.map(c => c._id);
        const students = await Student.find({ classId: { $in: classIds } });
        studentIds = students.map(s => s._id);
        console.log('Found', classIds.length, 'classes and', studentIds.length, 'students for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty activities');
        return res.json([]);
      }
    }

    const activities = [];

    // Get recent attendance records (last 2 unique dates)
    let attendanceQuery = {};
    if (studentIds) {
      attendanceQuery.studentId = { $in: studentIds };
    }

    const recentAttendance = await Attendance.find(attendanceQuery)
      .sort({ date: -1 })
      .limit(50); // Get more to group by date

    const attendanceByDate = {};
    for (const record of recentAttendance) {
      const dateKey = record.date.toISOString().split('T')[0];
      if (!attendanceByDate[dateKey]) {
        attendanceByDate[dateKey] = [];
      }
      attendanceByDate[dateKey].push(record);
    }

    const sortedDates = Object.keys(attendanceByDate).sort().reverse().slice(0, 2);

    for (const dateKey of sortedDates) {
      const dateAttendance = attendanceByDate[dateKey];
      const date = new Date(dateKey);
      const createdAt = dateAttendance[0].createdAt || date;

      activities.push({
        id: `attendance_${dateKey}`,
        type: 'attendance',
        title: 'Attendance Marked',
        subtitle: `Attendance recorded for ${dateAttendance.length} students`,
        timestamp: createdAt,
      });
    }

    // Get recently added students (last 2)
    let studentsQuery = {};
    if (classIds) {
      studentsQuery.classId = { $in: classIds };
    }

    const recentStudents = await Student.find(studentsQuery)
      .sort({ createdAt: -1 })
      .limit(2);

    for (const student of recentStudents) {
      activities.push({
        id: `student_${student._id}`,
        type: 'student',
        title: 'New Student Added',
        subtitle: `${student.name} has been registered`,
        timestamp: student.createdAt || new Date(),
      });
    }

    // Get recent payments (last 1)
    let paymentsQuery = {};
    if (classIds) {
      paymentsQuery.classId = { $in: classIds };
    }

    const recentPayment = await Payment.findOne(paymentsQuery)
      .sort({ date: -1 });

    if (recentPayment) {
      activities.push({
        id: `payment_${recentPayment._id}`,
        type: 'payment',
        title: 'Payment Received',
        subtitle: `Payment of Rs.${recentPayment.amount.toFixed(2)} received`,
        timestamp: recentPayment.date,
      });
    }

    // Get recently added classes (last 2)
    let classesQuery = {};
    if (teacherId) {
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        classesQuery.teacherId = teacher._id;
      }
    }

    const recentClasses = await Class.find(classesQuery)
      .sort({ createdAt: -1 })
      .limit(2);

    for (const classItem of recentClasses) {
      activities.push({
        id: `class_${classItem._id}`,
        type: 'class',
        title: 'New Class Added',
        subtitle: `${classItem.name} has been created`,
        timestamp: classItem.createdAt || new Date(),
      });
    }

    // Sort by timestamp descending and return top 3
    activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    res.json(activities.slice(0, 3));
  } catch (error) {
    console.error('Error fetching home activities:', error);
    
    // Check if it's a Mongoose buffer commands error
    if (error.message && error.message.includes('bufferCommands')) {
      console.error('MongoDB connection not ready when query attempted');
      console.error('Connection readyState:', mongoose.connection.readyState);
      return res.status(503).json({ 
        error: 'Database connection not ready', 
        message: 'Please try again in a moment' 
      });
    }
    
    res.status(500).json({ error: 'Failed to fetch home activities', message: error.message });
  }
});

// Email Verification Routes
app.post('/api/auth/send-verification-code', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    
    // Generate 5-digit code
    const code = Math.floor(10000 + Math.random() * 90000).toString();
    
    // Set expiration time (10 minutes from now)
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    
    // Save verification code
    await EmailVerification.findOneAndUpdate(
      { email },
      { code, expiresAt },
      { upsert: true, new: true }
    );
    
    // Send email
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Verify Your Email - Teacher Attendance App',
      html: `
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Email Verification</title>
          <style>
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              margin: 0;
              padding: 0;
              background-color: #f8fafc;
            }
            .container {
              max-width: 600px;
              margin: 0 auto;
              background-color: #ffffff;
              border-radius: 16px;
              overflow: hidden;
              box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
            }
            .header {
              background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 50%, #A855F7 100%);
              padding: 40px 30px;
              text-align: center;
              color: white;
            }
            .header h1 {
              margin: 0;
              font-size: 28px;
              font-weight: 700;
              letter-spacing: -0.5px;
            }
            .header p {
              margin: 8px 0 0 0;
              font-size: 16px;
              opacity: 0.9;
            }
            .content {
              padding: 40px 30px;
              text-align: center;
            }
            .code-container {
              background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
              border: 2px solid #e2e8f0;
              border-radius: 12px;
              padding: 30px 20px;
              margin: 30px 0;
              display: inline-block;
              min-width: 200px;
            }
            .code {
              font-size: 36px;
              font-weight: 800;
              letter-spacing: 8px;
              color: #6366F1;
              font-family: 'Courier New', monospace;
              margin: 0;
              text-shadow: 0 2px 4px rgba(99, 102, 241, 0.2);
            }
            .info-text {
              color: #64748b;
              font-size: 16px;
              line-height: 1.6;
              margin: 20px 0;
            }
            .warning-box {
              background-color: #fef3c7;
              border: 1px solid #f59e0b;
              border-radius: 8px;
              padding: 16px;
              margin: 20px 0;
              text-align: left;
            }
            .warning-box p {
              margin: 0;
              color: #92400e;
              font-size: 14px;
            }
            .footer {
              background-color: #f8fafc;
              padding: 30px;
              text-align: center;
              border-top: 1px solid #e2e8f0;
            }
            .footer p {
              margin: 0;
              color: #64748b;
              font-size: 14px;
              line-height: 1.5;
            }
            .app-name {
              font-weight: 700;
              color: #6366F1;
            }
            .icon {
              width: 60px;
              height: 60px;
              background: linear-gradient(135deg, #6366F1, #8B5CF6);
              border-radius: 50%;
              display: inline-flex;
              align-items: center;
              justify-content: center;
              margin-bottom: 20px;
              box-shadow: 0 8px 16px rgba(99, 102, 241, 0.3);
            }
            .icon::before {
              content: '🎓';
              font-size: 28px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="icon"></div>
              <h1>Welcome to Teacher Attendance</h1>
              <p>Verify your email to get started</p>
            </div>
            
            <div class="content">
              <h2 style="color: #1e293b; margin: 0 0 10px 0; font-size: 24px;">Verify Your Email Address</h2>
              <p class="info-text">
                To complete your registration and secure your account, please enter the verification code below in the app.
              </p>
              
              <div class="code-container">
                <div class="code">${code}</div>
              </div>
              
              <p class="info-text">
                <strong>This code will expire in 10 minutes</strong> for security reasons.
              </p>
              
              <div class="warning-box">
                <p><strong>Security Notice:</strong> If you didn't create an account with Teacher Attendance, please ignore this email. Your email address will not be used.</p>
              </div>
            </div>
            
            <div class="footer">
              <p>
                <span class="app-name">Teacher Attendance App</span><br>
                Secure • Reliable • Easy to Use<br>
                © 2025 Teacher Attendance. All rights reserved.
              </p>
            </div>
          </div>
        </body>
        </html>
      `
    };
    
    await transporter.sendMail(mailOptions);
    
    res.json({ message: 'Verification code sent successfully' });
  } catch (error) {
    console.error('Error sending verification code:', error);
    res.status(500).json({ error: 'Failed to send verification code' });
  }
});

app.post('/api/auth/verify-code', async (req, res) => {
  try {
    const { email, code } = req.body;
    
    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required' });
    }
    
    // Find verification code
    const verification = await EmailVerification.findOne({ email, code });
    
    if (!verification) {
      return res.status(400).json({ error: 'Invalid verification code' });
    }
    
    // Check if code is expired
    if (verification.expiresAt < new Date()) {
      return res.status(400).json({ error: 'Verification code has expired' });
    }
    
    // Delete the verification code after successful verification
    await EmailVerification.deleteOne({ _id: verification._id });
    
    res.json({ message: 'Email verified successfully' });
  } catch (error) {
    console.error('Error verifying code:', error);
    res.status(500).json({ error: 'Failed to verify code' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    console.log('Login request received');
    
    // Check MongoDB connection status
    if (mongoose.connection.readyState !== 1) {
      console.error('MongoDB not connected. ReadyState:', mongoose.connection.readyState);
      return res.status(503).json({ error: 'Database connection unavailable. Please try again.' });
    }
    
    const { email, password } = req.body;
    
    // Validate input
    if (!email || !password) {
      console.log('Login validation failed: Missing email or password');
      return res.status(400).json({ 
        error: 'Email and password are required',
        code: 'MISSING_CREDENTIALS'
      });
    }
    
    console.log('Attempting login for email:', email);
    
    // Normalize email
    const normalizedEmail = email.toLowerCase().trim();
    
    // Find teacher by email with error handling
    let teacher;
    try {
      teacher = await Teacher.findOne({ email: normalizedEmail });
      console.log('Database query completed, teacher found:', !!teacher);
    } catch (dbError) {
      console.error('Database error during findOne:', dbError);
      return res.status(500).json({ 
        error: 'Database connection error. Please try again.',
        code: 'DATABASE_ERROR'
      });
    }
    
    if (!teacher) {
      console.log('Login attempt failed: Teacher not found for email:', normalizedEmail);
      return res.status(401).json({ 
        error: 'Invalid email or password',
        code: 'INVALID_CREDENTIALS'
      });
    }
    
    // Check if teacher has a password set
    if (!teacher.password) {
      console.error('Login attempt failed: Teacher has no password set:', normalizedEmail);
      return res.status(401).json({ 
        error: 'Invalid email or password',
        code: 'INVALID_CREDENTIALS'
      });
    }
    
    // Check password using bcrypt with additional error handling
    let isPasswordValid = false;
    try {
      console.log('Comparing password with bcrypt');
      isPasswordValid = await bcrypt.compare(password, teacher.password);
      console.log('Password comparison completed, valid:', isPasswordValid);
    } catch (bcryptError) {
      console.error('Bcrypt comparison error:', bcryptError);
      return res.status(500).json({ 
        error: 'Authentication error. Please try again.',
        code: 'AUTHENTICATION_ERROR'
      });
    }
    
    if (!isPasswordValid) {
      console.log('Login attempt failed: Invalid password for email:', normalizedEmail);
      return res.status(401).json({ 
        error: 'Invalid email or password',
        code: 'INVALID_CREDENTIALS'
      });
    }
    
    // Generate JWT token for the teacher (even if inactive for subscription flow)
    const token = jwt.sign(
      {
        userId: teacher._id,
        teacherId: teacher.teacherId,
        email: teacher.email,
        userType: 'teacher',
      },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '30d' } // 30 days token validity
    );
    
    // Check subscription status
    const now = new Date();
    const isSubscriptionExpired = teacher.subscriptionExpiryDate && now > teacher.subscriptionExpiryDate;
    
    // Get latest payment proof for status
    const latestPaymentProof = await PaymentProof.findOne({ userEmail: normalizedEmail })
      .sort({ createdAt: -1 });
    
    // Return teacher data (excluding password) with token
    const teacherData = {
      _id: teacher._id,
      name: teacher.name,
      email: teacher.email,
      phone: teacher.phone,
      teacherId: teacher.teacherId,
      status: teacher.status,
      subscriptionType: teacher.subscriptionType,
      subscriptionStatus: teacher.subscriptionStatus,
      subscriptionExpiryDate: teacher.subscriptionExpiryDate,
      isFirstLogin: teacher.isFirstLogin,
      paymentProofStatus: latestPaymentProof ? latestPaymentProof.status : null,
      paymentProofRejectionReason: latestPaymentProof && latestPaymentProof.status === 'rejected' 
        ? latestPaymentProof.rejectionReason : null,
      requiresSubscriptionSetup: teacher.isFirstLogin && teacher.subscriptionType !== 'free',
      accountInactive: teacher.status !== 'active',
      subscriptionExpired: isSubscriptionExpired
    };
    
    console.log('Login successful for email:', normalizedEmail);
    res.json({ 
      message: 'Login successful', 
      teacher: teacherData,
      token: token 
    });
  } catch (error) {
    console.error('Unexpected error during login:', error);
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      error: 'An error occurred during login. Please try again later.',
      code: 'INTERNAL_ERROR'
    });
  }
});

// Check teacher status (for periodic validation)
app.get('/api/auth/status', async (req, res) => {
  try {
    // Get teacher email from query parameter or authorization header
    const email = req.query.email;

    if (!email) {
      return res.status(400).json({ error: 'Email parameter is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const teacher = await Teacher.findOne({ email: normalizedEmail });

    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    // Check if subscription has expired
    const now = new Date();
    const isSubscriptionExpired = teacher.subscriptionExpiryDate && now > teacher.subscriptionExpiryDate;
    const isActive = teacher.status === 'active' && !isSubscriptionExpired;

    // Check if subscription is expiring within 3 days
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    const isSubscriptionExpiringSoon = teacher.subscriptionExpiryDate && 
      teacher.subscriptionExpiryDate <= threeDaysFromNow && 
      !isSubscriptionExpired;
    
    // Check for pending or rejected payment proofs
    const latestPaymentProof = await PaymentProof.findOne({ userEmail: normalizedEmail })
      .sort({ createdAt: -1 });

    res.json({
      status: teacher.status,
      isActive: isActive,
      subscriptionExpired: isSubscriptionExpired,
      subscriptionExpiringSoon: isSubscriptionExpiringSoon,
      subscriptionType: teacher.subscriptionType,
      subscriptionExpiryDate: teacher.subscriptionExpiryDate,
      subscriptionStatus: teacher.subscriptionStatus,
      isFirstLogin: teacher.isFirstLogin,
      lastSubscriptionWarningDate: teacher.lastSubscriptionWarningDate,
      paymentProofStatus: latestPaymentProof ? latestPaymentProof.status : null,
      paymentProofRejectionReason: latestPaymentProof && latestPaymentProof.status === 'rejected' 
        ? latestPaymentProof.rejectionReason : null,
      _accountActivated: isActive && !teacher.isFirstLogin // Signal for real-time activation
    });
  } catch (error) {
    console.error('Error checking teacher status:', error);
    res.status(500).json({ error: 'Failed to check teacher status' });
  }
});

// Forgot Password Routes
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    
    // Check if teacher exists
    const teacher = await Teacher.findOne({ email: email.toLowerCase().trim() });
    if (!teacher) {
      // Don't reveal if email exists or not for security
      return res.json({ message: 'If an account with this email exists, a password reset code has been sent.' });
    }
    
    // Generate 6-digit reset code
    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Set expiration time (10 minutes from now)
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    
    // Save reset code
    await PasswordReset.findOneAndUpdate(
      { email },
      { resetCode, expiresAt },
      { upsert: true, new: true }
    );
    
    // Send email
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Reset Your Password - Teacher Attendance App',
      html: `
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Password Reset</title>
          <style>
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              margin: 0;
              padding: 0;
              background-color: #f8fafc;
            }
            .container {
              max-width: 600px;
              margin: 0 auto;
              background-color: #ffffff;
              border-radius: 16px;
              overflow: hidden;
              box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
            }
            .header {
              background: linear-gradient(135deg, #DC2626 0%, #EF4444 50%, #F87171 100%);
              padding: 40px 30px;
              text-align: center;
              color: white;
            }
            .header h1 {
              margin: 0;
              font-size: 28px;
              font-weight: 700;
              letter-spacing: -0.5px;
            }
            .header p {
              margin: 8px 0 0 0;
              font-size: 16px;
              opacity: 0.9;
            }
            .content {
              padding: 40px 30px;
              text-align: center;
            }
            .code-container {
              background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
              border: 2px solid #fecaca;
              border-radius: 12px;
              padding: 30px 20px;
              margin: 30px 0;
              display: inline-block;
              min-width: 200px;
            }
            .code {
              font-size: 36px;
              font-weight: 800;
              letter-spacing: 6px;
              color: #DC2626;
              font-family: 'Courier New', monospace;
              margin: 0;
              text-shadow: 0 2px 4px rgba(220, 38, 38, 0.2);
            }
            .info-text {
              color: #64748b;
              font-size: 16px;
              line-height: 1.6;
              margin: 20px 0;
            }
            .warning-box {
              background-color: #fef3c7;
              border: 1px solid #f59e0b;
              border-radius: 8px;
              padding: 16px;
              margin: 20px 0;
              text-align: left;
            }
            .warning-box p {
              margin: 0;
              color: #92400e;
              font-size: 14px;
            }
            .security-tips {
              background-color: #f0f9ff;
              border: 1px solid #0ea5e9;
              border-radius: 8px;
              padding: 16px;
              margin: 20px 0;
              text-align: left;
            }
            .security-tips h3 {
              margin: 0 0 8px 0;
              color: #0c4a6e;
              font-size: 16px;
            }
            .security-tips ul {
              margin: 0;
              padding-left: 20px;
              color: #0c4a6e;
            }
            .security-tips li {
              margin: 4px 0;
              font-size: 14px;
            }
            .footer {
              background-color: #f8fafc;
              padding: 30px;
              text-align: center;
              border-top: 1px solid #e2e8f0;
            }
            .footer p {
              margin: 0;
              color: #64748b;
              font-size: 14px;
              line-height: 1.5;
            }
            .app-name {
              font-weight: 700;
              color: #DC2626;
            }
            .icon {
              width: 60px;
              height: 60px;
              background: linear-gradient(135deg, #DC2626, #EF4444);
              border-radius: 50%;
              display: inline-flex;
              align-items: center;
              justify-content: center;
              margin-bottom: 20px;
              box-shadow: 0 8px 16px rgba(220, 38, 38, 0.3);
            }
            .icon::before {
              content: '🔐';
              font-size: 28px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="icon"></div>
              <h1>Password Reset Request</h1>
              <p>Secure your Teacher Attendance account</p>
            </div>
            
            <div class="content">
              <h2 style="color: #1e293b; margin: 0 0 10px 0; font-size: 24px;">Reset Your Password</h2>
              <p class="info-text">
                We received a request to reset your password. Use the code below to create a new password for your account.
              </p>
              
              <div class="code-container">
                <div class="code">${resetCode}</div>
              </div>
              
              <p class="info-text">
                <strong>This code will expire in 10 minutes</strong> for your security.
              </p>
              
              <div class="warning-box">
                <p><strong>Security Alert:</strong> If you didn't request this password reset, please ignore this email and consider changing your password immediately if you suspect unauthorized access.</p>
              </div>
              
              <div class="security-tips">
                <h3>🔒 Password Security Tips</h3>
                <ul>
                  <li>Use at least 8 characters with a mix of letters, numbers, and symbols</li>
                  <li>Avoid using personal information or common words</li>
                  <li>Don't reuse passwords from other accounts</li>
                  <li>Consider using a password manager</li>
                </ul>
              </div>
            </div>
            
            <div class="footer">
              <p>
                <span class="app-name">Teacher Attendance App</span><br>
                Secure • Reliable • Easy to Use<br>
                © 2025 Teacher Attendance. All rights reserved.
              </p>
            </div>
          </div>
        </body>
        </html>
      `
    };
    
    await transporter.sendMail(mailOptions);
    
    res.json({ message: 'If an account with this email exists, a password reset code has been sent.' });
  } catch (error) {
    console.error('Error sending reset code:', error);
    res.status(500).json({ error: 'Failed to send reset code' });
  }
});

app.post('/api/auth/reset-password', async (req, res) => {
  try {
    const { email, resetCode, newPassword } = req.body;
    
    if (!email || !resetCode || !newPassword) {
      return res.status(400).json({ error: 'Email, reset code, and new password are required' });
    }
    
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long' });
    }
    
    // Find reset code
    const resetDoc = await PasswordReset.findOne({ email, resetCode });
    
    if (!resetDoc) {
      return res.status(400).json({ error: 'Invalid reset code', code: 'INVALID_RESET_CODE' });
    }
    
    // Check if code is expired
    if (resetDoc.expiresAt < new Date()) {
      return res.status(400).json({ error: 'Reset code has expired', code: 'RESET_CODE_EXPIRED' });
    }
    
    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 12);
    
    // Update teacher password
    await Teacher.findOneAndUpdate(
      { email: email.toLowerCase().trim() },
      { password: hashedPassword }
    );
    
    // Delete the reset code
    await PasswordReset.deleteOne({ _id: resetDoc._id });
    
    res.json({ message: 'Password reset successfully' });
  } catch (error) {
    console.error('Error resetting password:', error);
    res.status(500).json({ error: 'Failed to reset password' });
  }
});

// ============================================
// Web Session Management Routes
// ============================================

// Get active web sessions
app.get('/api/web-session/active', verifyToken, async (req, res) => {  
try {
    console.log('=== GET Active Web Sessions Request ===');
    console.log('Authenticated user:', req.user);
    console.log('Request timestamp:', new Date().toISOString());
    
    // Get the authenticated teacher's ID from the token
    const teacherId = req.user.teacherId;
    console.log('Looking for sessions for teacher:', teacherId);
    
    // Find sessions for this specific teacher
    const sessions = await WebSession.find({
      teacherId: teacherId,
      isActive: true,
      expiresAt: { $gt: new Date() },
    }).populate('userId');
    
    console.log(`✓ Found ${sessions.length} active session(s) for teacher ${teacherId}`);
    
    if (sessions.length > 0) {
      console.log('Session details:');
      sessions.forEach((session, index) => {
        console.log(`  Session ${index + 1}:`, {
          sessionId: session.sessionId,
          teacherId: session.teacherId,
          deviceId: session.deviceId,
          isActive: session.isActive,
          createdAt: session.createdAt,
          expiresAt: session.expiresAt,
          ipAddress: session.ipAddress || 'unknown',
          lastActivity: session.lastActivity || session.updatedAt || session.createdAt,
          userAgent: session.userAgent?.substring(0, 50) + '...' || 'N/A'
        });
      });
    } else {
      console.log('⚠ No active sessions found for this teacher');
      console.log('Checking all active sessions in database...');
      const allSessions = await WebSession.find({
        isActive: true,
        expiresAt: { $gt: new Date() },
      });
      console.log(`Total active sessions in DB: ${allSessions.length}`);
      if (allSessions.length > 0) {
        console.log('Other teacher IDs with active sessions:', 
          [...new Set(allSessions.map(s => s.teacherId))]);
      }
    }
    
    // Map sessions to include IP and lastActivity
    const sessionsWithMetadata = sessions.map(session => ({
      sessionId: session.sessionId,
      teacherId: session.teacherId,
      deviceId: session.deviceId,
      isActive: session.isActive,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
      ipAddress: session.ipAddress || 'unknown',
      lastActivity: session.lastActivity || session.updatedAt || session.createdAt,
      userAgent: session.userAgent || 'unknown'
    }));
    
    res.json(sessionsWithMetadata);
  } catch (error) {
    console.error('❌ Error fetching active sessions:', error);
    res.status(500).json({ error: 'Failed to fetch sessions' });
  }
});

// Verify session validity
app.post('/api/web-session/verify', async (req, res) => {
  try {
    const { sessionId } = req.body;
    
    const session = await WebSession.findOne({
      sessionId,
      isActive: true,
      expiresAt: { $gt: new Date() },
    }).populate('userId');
    
    if (!session) {
      return res.status(404).json({ error: 'Session not found or expired' });
    }
    
    res.json({ valid: true, session });
  } catch (error) {
    console.error('Error verifying session:', error);
    res.status(500).json({ error: 'Failed to verify session' });
  }
});

// Disconnect a web session
app.post('/api/web-session/disconnect', verifyToken, async (req, res) => {
  try {
    console.log('=== Disconnect Web Session Request ===');
    const { sessionId } = req.body;
    console.log('Session ID to disconnect:', sessionId);
    console.log('Request from user:', req.user);
    
    const session = await WebSession.findOne({ sessionId });
    
    if (!session) {
      console.log('❌ Session not found:', sessionId);
      return res.status(404).json({ error: 'Session not found' });
    }
    
    console.log('Found session:', {
      sessionId: session.sessionId,
      teacherId: session.teacherId,
      isActive: session.isActive,
      deviceId: session.deviceId
    });
    
    const updatedSession = await WebSession.findOneAndUpdate(
      { sessionId },
      { isActive: false },
      { new: true }
    );
    
    console.log('✓ Session disconnected successfully');
    console.log('Updated session isActive:', updatedSession.isActive);
    
    // Notify via WebSocket
    io.emit('session-disconnected', { sessionId });
    console.log('WebSocket notification sent');
    
    res.json({ message: 'Session disconnected successfully' });
  } catch (error) {
    console.error('❌ Error disconnecting session:', error);
    res.status(500).json({ error: 'Failed to disconnect session' });
  }
});

// Get all web sessions for a teacher
app.get('/api/web-session/teacher/:teacherId', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.params;
    
    const sessions = await WebSession.find({
      teacherId,
      isActive: true,
      expiresAt: { $gt: new Date() },
    });
    
    res.json(sessions);
  } catch (error) {
    console.error('Error fetching teacher sessions:', error);
    res.status(500).json({ error: 'Failed to fetch sessions' });
  }
});

// Get all teacher sessions for a company (admin view)
app.get('/api/web-session/teacher-sessions/:companyId', verifyToken, async (req, res) => {
  const debugLog = [];
  try {
    const { companyId } = req.params;
    debugLog.push(`[SESSIONS API] GET /api/web-session/teacher-sessions/${companyId}`);
    debugLog.push(`[SESSIONS API] Timestamp: ${new Date().toISOString()}`);
    console.log('=== GET Teacher Sessions ===');
    console.log('CompanyId:', companyId);
    
    // Convert companyId to ObjectId for proper comparison
    const companyObjectId = new mongoose.Types.ObjectId(companyId);
    debugLog.push(`[SESSIONS API] Converted to ObjectId: ${companyObjectId.toString()}`);
    
    // First, get all teachers who belong to this company
    debugLog.push(`[SESSIONS API] Finding teachers with companyId in companyIds array...`);
    const teachers = await Teacher.find({ companyIds: companyObjectId });
    debugLog.push(`[SESSIONS API] Found ${teachers.length} teachers for this company`);
    console.log(`Found ${teachers.length} teachers for company`);
    
    if (teachers.length > 0) {
      const teacherDetails = teachers.map(t => ({
        _id: t._id.toString(),
        teacherId: t.teacherId,
        name: t.name,
        companyIds: t.companyIds.map(id => id.toString())
      }));
      debugLog.push(`[SESSIONS API] Teachers: ${JSON.stringify(teacherDetails, null, 2)}`);
      console.log('Teachers:', teacherDetails);
    }
    
    const teacherIds = teachers.map(t => t._id);
    debugLog.push(`[SESSIONS API] Looking for sessions for ${teacherIds.length} teacher IDs`);
    
    // Then get all active sessions for these teachers
    const sessionQuery = {
      userId: { $in: teacherIds },
      userType: 'teacher',
      isActive: true,
      expiresAt: { $gt: new Date() },
    };
    debugLog.push(`[SESSIONS API] Session query: ${JSON.stringify({...sessionQuery, expiresAt: 'Date > now'})}`);
    
    const sessions = await WebSession.find(sessionQuery).populate('userId');
    debugLog.push(`[SESSIONS API] Found ${sessions.length} active sessions`);
    console.log(`Found ${sessions.length} active sessions`);
    
    // Format sessions with teacher data for frontend
    const formattedSessions = sessions.map(s => ({
      _id: s._id,
      sessionId: s.sessionId,
      teacherId: s.teacherId || s.userId?.teacherId,
      teacherName: s.userId?.name || 'Unknown Teacher',
      teacherEmail: s.userId?.email || 'No email',
      deviceInfo: s.userAgent || `Device ${s.deviceId || 'Unknown'}`,
      loginTime: s.createdAt,
      lastActivity: s.lastActivity || s.createdAt,
      isActive: s.isActive,
      userId: s.userId, // Keep the populated userId for fallback
    }));
    
    if (formattedSessions.length > 0) {
      const sessionDetails = formattedSessions.map(s => ({
        sessionId: s.sessionId,
        teacherId: s.teacherId,
        teacherName: s.teacherName,
        teacherEmail: s.teacherEmail,
        isActive: s.isActive,
        deviceId: s.deviceInfo
      }));
      debugLog.push(`[SESSIONS API] Formatted Sessions: ${JSON.stringify(sessionDetails, null, 2)}`);
      console.log('Formatted Sessions:', sessionDetails);
    }
    
    // Send debug logs in response headers
    const debugHeader = Buffer.from(debugLog.join('\n')).toString('base64');
    res.setHeader('X-Debug-Log', debugHeader);
    
    res.json(formattedSessions);
  } catch (error) {
    console.error('Error fetching company teacher sessions:', error);
    debugLog.push(`[SESSIONS API] ERROR: ${error.message}`);
    const debugHeader = Buffer.from(debugLog.join('\n')).toString('base64');
    res.setHeader('X-Debug-Log', debugHeader);
    res.status(500).json({ error: 'Failed to fetch teacher sessions' });
  }
});

// Get detailed teacher data for a specific session (admin view)
app.get('/api/web-session/teacher-data/:sessionId', verifyToken, async (req, res) => {
  try {
    await connectToDatabase();
    
    const { sessionId } = req.params;
    
    // Find the session
    const session = await WebSession.findOne({
      sessionId,
      isActive: true,
      userType: 'teacher',
      expiresAt: { $gt: new Date() },
    }).populate('userId');
    
    if (!session || !session.userId) {
      return res.status(404).json({ error: 'Session not found or inactive' });
    }
    
    const teacher = session.userId;
    const teacherId = teacher._id;
    
    // Get teacher's classes
    const classes = await Class.find({ teacherId }).lean();
    const classIds = classes.map(c => c._id);
    
    // Get students for these classes
    const students = await Student.find({ classId: { $in: classIds } }).lean();
    
    // Get recent attendance records (last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const attendance = await Attendance.find({
      studentId: { $in: students.map(s => s._id) },
      date: { $gte: thirtyDaysAgo },
    }).populate('studentId').lean();
    
    // Get attendance summary
    const totalStudents = students.length;
    const todayAttendance = await Attendance.find({
      studentId: { $in: students.map(s => s._id) },
      date: {
        $gte: new Date(new Date().setHours(0, 0, 0, 0)),
        $lt: new Date(new Date().setHours(23, 59, 59, 999)),
      },
    }).lean();
    
    const todayPresent = todayAttendance.filter(a => a.status === 'present').length;
    const todayAbsent = todayAttendance.filter(a => a.status === 'absent').length;
    
    res.json({
      session: {
        sessionId: session.sessionId,
        deviceId: session.deviceId,
        createdAt: session.createdAt,
        companyId: session.companyId,
      },
      teacher: {
        _id: teacher._id,
        name: teacher.name,
        email: teacher.email,
        teacherId: teacher.teacherId,
        phone: teacher.phone,
        status: teacher.status,
      },
      statistics: {
        totalClasses: classes.length,
        totalStudents,
        todayPresent,
        todayAbsent,
        attendanceMarked: todayAttendance.length > 0,
      },
      classes,
      students,
      recentAttendance: attendance.slice(0, 50), // Last 50 records
    });
  } catch (error) {
    console.error('Error fetching teacher data:', error);
    res.status(500).json({ error: 'Failed to fetch teacher data' });
  }
});

// Get all active teachers with their data for admin dashboard
app.get('/api/admin/active-teachers/:companyId', verifyToken, async (req, res) => {
  try {
    await connectToDatabase();
    
    const { companyId } = req.params;
    
    if (req.user.userType !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    // Get all active sessions for this company
    const sessions = await WebSession.find({
      companyId,
      userType: 'teacher',
      isActive: true,
      expiresAt: { $gt: new Date() },
    }).populate('userId').lean();
    
    // Get detailed data for each teacher
    const teachersData = await Promise.all(
      sessions.map(async (session) => {
        if (!session.userId) return null;
        
        const teacher = session.userId;
        const teacherId = teacher._id;
        
        // Get classes count
        const classCount = await Class.countDocuments({ teacherId });
        
        // Get students count
        const classIds = await Class.find({ teacherId }).distinct('_id');
        const studentCount = await Student.countDocuments({ classId: { $in: classIds } });
        
        // Get today's attendance
        const todayAttendance = await Attendance.find({
          studentId: { $in: await Student.find({ classId: { $in: classIds } }).distinct('_id') },
          date: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
            $lt: new Date(new Date().setHours(23, 59, 59, 999)),
          },
        }).lean();
        
        return {
          sessionId: session.sessionId,
          deviceId: session.deviceId,
          connectedAt: session.createdAt,
          teacher: {
            _id: teacher._id,
            name: teacher.name,
            email: teacher.email,
            teacherId: teacher.teacherId,
            phone: teacher.phone,
          },
          stats: {
            classes: classCount,
            students: studentCount,
            todayPresent: todayAttendance.filter(a => a.status === 'present').length,
            todayAbsent: todayAttendance.filter(a => a.status === 'absent').length,
            todayTotal: todayAttendance.length,
          },
        };
      })
    );
    
    // Filter out null entries
    const validTeachersData = teachersData.filter(t => t !== null);
    
    res.json({
      success: true,
      count: validTeachersData.length,
      teachers: validTeachersData,
    });
  } catch (error) {
    console.error('Error fetching active teachers:', error);
    res.status(500).json({ error: 'Failed to fetch active teachers' });
  }
});

// Logout a teacher session (admin action)
app.post('/api/web-session/logout-teacher', verifyToken, async (req, res) => {
  try {
    const { sessionId } = req.body;
    
    if (!sessionId) {
      return res.status(400).json({ error: 'Session ID is required' });
    }
    
    const session = await WebSession.findOne({ sessionId });
    
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    // Deactivate the session but KEEP the company association
    // The teacher remains associated with the company for future logins
    session.isActive = false;
    session.expiresAt = new Date();
    await session.save();
    
    console.log(`Session ${sessionId} deactivated. Teacher-company association preserved.`);
    
    // Notify via WebSocket
    io.emit('session-disconnected', { sessionId });
    
    res.json({ 
      message: 'Teacher logged out successfully',
      note: 'Teacher remains associated with company for future logins'
    });
  } catch (error) {
    console.error('Error logging out teacher:', error);
    res.status(500).json({ error: 'Failed to logout teacher' });
  }
});

// Remove teacher from company (admin action - permanently removes association)
app.post('/api/teachers/remove-company', verifyToken, async (req, res) => {
  try {
    const { teacherId, companyId } = req.body;
    
    if (!teacherId || !companyId) {
      return res.status(400).json({ error: 'Teacher ID and Company ID are required' });
    }
    
    console.log(`Removing teacher ${teacherId} from company ${companyId}`);
    
    const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
    
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    if (!teacher.companyIds || teacher.companyIds.length === 0) {
      return res.status(400).json({ error: 'Teacher has no company associations' });
    }

    const companyIdStr = companyId.toString();
    const initialLength = teacher.companyIds.length;
    teacher.companyIds = teacher.companyIds.filter(id => id.toString() !== companyIdStr);
    
    if (teacher.companyIds.length === initialLength) {
      return res.status(400).json({ error: 'Teacher is not associated with this company' });
    }

    await teacher.save();
    
    // Also deactivate all active sessions for this teacher-company combination
    await WebSession.updateMany(
      {
        teacherId: teacher.teacherId,
        companyId: companyId,
        isActive: true
      },
      {
        isActive: false,
        expiresAt: new Date()
      }
    );
    
    console.log(`✓ Teacher ${teacherId} removed from company ${companyId}`);
    
    res.json({ 
      message: 'Teacher removed from company successfully',
      teacher: {
        teacherId: teacher.teacherId,
        name: teacher.name,
        remainingCompanies: teacher.companyIds.length
      }
    });
  } catch (error) {
    console.error('Error removing teacher from company:', error);
    res.status(500).json({ error: 'Failed to remove teacher from company' });
  }
});

// Generate QR code for web login (HTTP endpoint)
app.post('/api/web-session/generate-qr', verifyToken, async (req, res) => {
  try {
    await connectToDatabase();
    
    console.log('=== Generate QR Request (HTTP) ===');
    console.log('Request Body:', req.body);
    
    const { v4: uuidv4 } = await import('uuid');
    const { userType = 'teacher', companyId } = req.body;
    
    if (!companyId) {
      console.log('❌ Missing companyId in request');
      return res.status(400).json({ error: 'Company ID is required' });
    }
    
    console.log('Generating QR for companyId:', companyId);
    
    const sessionId = uuidv4();
    // No expiration - QR codes are valid indefinitely
    const expiresAt = new Date(Date.now() + (365 * 24 * 60 * 60 * 1000)); // 1 year (effectively no expiration)
    
    // Create web session with companyId (convert to ObjectId)
    const webSession = new WebSession({
      sessionId,
      userType,
      isActive: false, // Will be activated when scanned
      expiresAt,
      companyId: new mongoose.Types.ObjectId(companyId), // Associate with the admin's company
    });
    
    await webSession.save();
    console.log('✓ WebSession created with companyId:', webSession.companyId);
    
    // Generate QR code with format expected by mobile app (include companyId in QR)
    const qrData = JSON.stringify({
      type: 'web-auth',
      sessionId,
      userType, // Keep for backward compatibility
      companyId: companyId.toString(), // Include companyId for validation
    });
    
    console.log('Generated QR code data:', qrData);
    
    const qrCode = await QRCode.toDataURL(qrData);
    
    res.json({
      sessionId,
      qrCode,
      qrData, // Return the raw data for debugging
    });
  } catch (error) {
    console.error('Error generating QR code:', error);
    res.status(500).json({ error: 'Failed to generate QR code' });
  }
});

// Check if QR session is authenticated (polling endpoint)
app.get('/api/web-session/check-auth/:sessionId', verifyToken, async (req, res) => {
  try {
    await connectToDatabase();
    
    const { sessionId } = req.params;
    
    console.log('Checking auth status for session:', sessionId);
    
    const session = await WebSession.findOne({
      sessionId,
      expiresAt: { $gt: new Date() },
    }).populate('userId');
    
    if (!session) {
      console.log('Session not found or expired:', sessionId);
      return res.json({ 
        authenticated: false,
        message: 'Session not found or expired' 
      });
    }
    
    console.log('Session found:', {
      sessionId: session.sessionId,
      isActive: session.isActive,
      hasUserId: !!session.userId,
      userId: session.userId?._id,
      userType: session.userType
    });
    
    if (session.isActive && session.userId) {
      // Session is authenticated
      const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
      
      console.log('=== JWT Token Generation (check-auth endpoint) ===');
      console.log('JWT_SECRET exists:', !!process.env.JWT_SECRET);
      console.log('JWT_SECRET length:', jwtSecret.length);
      
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
      
      console.log('Session is authenticated, returning success');
      console.log('User type:', session.userType);
      console.log('Teacher ID:', session.userId.teacherId);
      
      return res.json({
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
    console.log('Session not authenticated yet');
    res.json({ authenticated: false });
  } catch (error) {
    console.error('Error checking auth status:', error);
    res.json({ authenticated: false, error: 'Internal server error' });
  }
});

// Authenticate QR code (HTTP endpoint for mobile app)
app.post('/api/web-session/authenticate', verifyToken, async (req, res) => {
  try {
    await connectToDatabase();
    
    const { sessionId, teacherId, deviceId } = req.body;
    
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
      existingSession.ipAddress = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || req.ip || req.connection.remoteAddress || 'unknown').split(',')[0].trim();
      existingSession.userAgent = req.headers['user-agent'] || 'unknown';
      await existingSession.save();
      
      // Now find and update the new session that was just scanned
      const newSession = await WebSession.findOne({
        sessionId,
        expiresAt: { $gt: new Date() },
      });
      
      if (newSession) {
        // Deactivate the new scanned session and use the existing one
        newSession.isActive = false;
        await newSession.save();
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
        console.log('ERROR: Session already authenticated on different device');
        return res.status(409).json({ 
          success: false, 
          message: 'This session is already authenticated on another device',
          details: {
            currentDevice: session.deviceId,
            requestingDevice: deviceId,
          }
        });
      } else {
        console.log('✓ Same device attempting to re-authenticate');
      }
    }
    
    console.log('✓ Teacher found:', teacher.name, '(ID:', teacher.teacherId, ')');
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
      console.error('⚠⚠⚠ WARNING: No companyId in session, skipping teacher-company association');
      console.log('Session details:', {
        sessionId: session.sessionId,
        companyId: session.companyId,
        userType: session.userType
      });
    }
    console.log('=== END COMPANY ASSOCIATION LOGIC ===');
    
    // Update session with teacher info and device metadata
    console.log('Updating session with authentication details...');
    session.userId = teacher._id; // Store as ObjectId, not string
    session.userModel = 'Teacher'; // Set the model reference
    session.teacherId = teacher.teacherId; // Custom teacher ID (TCH...)
    session.isActive = true;
    session.deviceId = deviceId || 'mobile-app';
    session.ipAddress = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || req.ip || req.connection.remoteAddress || 'unknown').split(',')[0].trim();
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
    
    res.json({
      success: true,
      message: 'Authentication successful',
      sessionId,
      token, // Include the JWT token in the response
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
    res.status(500).json({ 
      success: false, 
      message: 'Authentication failed: ' + error.message 
    });
  }
});

// ============================================
// Admin Routes
// ============================================

// Admin login
app.post('/api/admin/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const admin = await Admin.findOne({ email: email.toLowerCase().trim() });
    
    if (!admin) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const isValidPassword = await bcrypt.compare(password, admin.password);
    
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    // Generate session
    const { v4: uuidv4 } = await import('uuid');
    const sessionId = uuidv4();
    const webSession = new WebSession({
      sessionId,
      userId: admin._id,
      userModel: 'Admin',
      userType: 'admin',
      deviceId: req.headers['user-agent'] || 'unknown',
      isActive: true,
      expiresAt: new Date(Date.now() + (24 * 60 * 60 * 1000)),
      ipAddress: (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || req.ip || req.connection.remoteAddress || 'unknown').split(',')[0].trim(),
      userAgent: req.headers['user-agent'] || 'unknown',
      lastActivity: new Date(),
    });
    
    await webSession.save();
    
    const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
    
    console.log('=== JWT Token Generation (admin login) ===');
    console.log('JWT_SECRET exists:', !!process.env.JWT_SECRET);
    console.log('JWT_SECRET length:', jwtSecret.length);
    
    const token = jwt.sign(
      {
        sessionId,
        userId: admin._id,
        userType: 'admin',
      },
      jwtSecret,
      { expiresIn: '24h' }
    );
    
    res.json({
      success: true,
      user: {
        _id: admin._id,
        email: admin.email,
        name: admin.name,
        companyName: admin.companyName,
        role: admin.role,
      },
      session: webSession,
      token,
    });
  } catch (error) {
    console.error('Error during admin login:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Admin registration (public endpoint for first-time admin creation)
app.post('/api/admin/register', async (req, res) => {
  try {
    const { email, password, name, companyName } = req.body;
    
    // Validate required fields
    if (!email || !password || !name || !companyName) {
      return res.status(400).json({ error: 'All fields are required' });
    }
    
    // Check if admin with this email already exists
    const existingAdmin = await Admin.findOne({ email: email.toLowerCase().trim() });
    if (existingAdmin) {
      return res.status(400).json({ error: 'Email already registered' });
    }
    
    // Validate password length
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }
    
    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);
    
    // Create new admin
    const admin = new Admin({
      email: email.toLowerCase().trim(),
      password: hashedPassword,
      name: name.trim(),
      companyName: companyName.trim(),
    });
    
    await admin.save();
    
    res.status(201).json({
      success: true,
      message: 'Admin account created successfully',
      admin: {
        _id: admin._id,
        email: admin.email,
        name: admin.name,
        companyName: admin.companyName,
      },
    });
  } catch (error) {
    console.error('Error during admin registration:', error);
    if (error.code === 11000) {
      return res.status(400).json({ error: 'Email already registered' });
    }
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Create admin (protected - only for initial setup or by existing admin)
app.post('/api/admin/create', async (req, res) => {
  try {
    const { email, password, name, secretKey } = req.body;
    
    // Check if this is the first admin (no secret key required)
    const adminCount = await Admin.countDocuments();
    
    if (adminCount > 0 && secretKey !== process.env.ADMIN_CREATE_SECRET) {
      return res.status(403).json({ error: 'Unauthorized' });
    }
    
    const hashedPassword = await bcrypt.hash(password, 12);
    
    const admin = new Admin({
      email: email.toLowerCase().trim(),
      password: hashedPassword,
      name,
    });
    
    await admin.save();
    
    res.status(201).json({
      message: 'Admin created successfully',
      admin: {
        _id: admin._id,
        email: admin.email,
        name: admin.name,
      },
    });
  } catch (error) {
    console.error('Error creating admin:', error);
    res.status(500).json({ error: 'Failed to create admin' });
  }
});

// Get all teachers (admin only)
app.get('/api/admin/teachers', verifyToken, async (req, res) => {
  try {
    if (req.user.userType !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    const teachers = await Teacher.find().select('-password');
    res.json(teachers);
  } catch (error) {
    console.error('Error fetching teachers:', error);
    res.status(500).json({ error: 'Failed to fetch teachers' });
  }
});

// Get dashboard stats (admin)
app.get('/api/admin/stats', verifyToken, async (req, res) => {
  try {
    if (req.user.userType !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    const [teacherCount, studentCount, classCount, activeSessionCount] = await Promise.all([
      Teacher.countDocuments({ status: 'active' }),
      Student.countDocuments(),
      Class.countDocuments(),
      WebSession.countDocuments({ isActive: true, expiresAt: { $gt: new Date() } }),
    ]);
    
    res.json({
      teachers: teacherCount,
      students: studentCount,
      classes: classCount,
      activeSessions: activeSessionCount,
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// Get admin profile
app.get('/api/admin/profile', verifyToken, async (req, res) => {
  try {
    console.log('=== Admin Profile Request ===');
    console.log('User from token:', req.user);
    
    if (req.user.userType !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    // Get admin from database
    const admin = await Admin.findById(req.user.userId).select('-password');
    
    if (!admin) {
      console.log('Admin not found for userId:', req.user.userId);
      return res.status(404).json({ error: 'Admin not found' });
    }
    
    console.log('✓ Admin profile found:', admin.email);
    
    res.json({
      id: admin._id,
      email: admin.email,
      name: admin.name,
      companyName: admin.companyName,
      role: admin.role,
      createdAt: admin.createdAt,
      updatedAt: admin.updatedAt,
    });
  } catch (error) {
    console.error('Error fetching admin profile:', error);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// Update admin profile
app.put('/api/admin/profile', verifyToken, async (req, res) => {
  try {
    console.log('=== Update Admin Profile Request ===');
    console.log('User from token:', req.user);
    console.log('Update data:', req.body);
    
    if (req.user.userType !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    const { name, companyName } = req.body;
    
    // Build update object with only provided fields
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (companyName !== undefined) updateData.companyName = companyName;
    updateData.updatedAt = new Date();
    
    // Update admin in database
    const admin = await Admin.findByIdAndUpdate(
      req.user.userId,
      { $set: updateData },
      { new: true, select: '-password' }
    );
    
    if (!admin) {
      console.log('Admin not found for userId:', req.user.userId);
      return res.status(404).json({ error: 'Admin not found' });
    }
    
    console.log('✓ Admin profile updated:', admin.email);
    
    res.json({
      id: admin._id,
      email: admin.email,
      name: admin.name,
      companyName: admin.companyName,
      role: admin.role,
      createdAt: admin.createdAt,
      updatedAt: admin.updatedAt,
    });
  } catch (error) {
    console.error('Error updating admin profile:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// Change admin password
app.put('/api/admin/change-password', verifyToken, async (req, res) => {
  try {
    console.log('=== Change Admin Password Request ===');
    console.log('User from token:', req.user);
    
    if (req.user.userType !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    const { currentPassword, newPassword } = req.body;
    
    // Validate inputs
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ 
        error: 'Current password and new password are required' 
      });
    }
    
    if (newPassword.length < 6) {
      return res.status(400).json({ 
        error: 'New password must be at least 6 characters long' 
      });
    }
    
    // Get admin with password
    const admin = await Admin.findById(req.user.userId);
    
    if (!admin) {
      console.log('Admin not found for userId:', req.user.userId);
      return res.status(404).json({ error: 'Admin not found' });
    }
    
    // Verify current password
    const isPasswordValid = await bcrypt.compare(currentPassword, admin.password);
    
    if (!isPasswordValid) {
      console.log('Invalid current password for admin:', admin.email);
      return res.status(401).json({ error: 'Current password is incorrect' });
    }
    
    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    
    // Update password
    admin.password = hashedPassword;
    admin.updatedAt = new Date();
    await admin.save();
    
    console.log('✓ Password changed successfully for admin:', admin.email);
    
    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('Error changing password:', error);
    res.status(500).json({ error: 'Failed to change password' });
  }
});

// ============================================
// Super Admin Routes
// ============================================

// Get all teachers with earnings
app.get('/api/super-admin/teachers', verifySuperAdmin, async (req, res) => {
  try {
    const teachers = await Teacher.find({})
      .select('_id name email teacherId phone status profilePicture companyIds subscriptionType subscriptionStartDate subscriptionExpiryDate isRestricted restrictedAt restrictionReason restrictedBy createdAt updatedAt')
      .populate('companyIds', 'companyName');
    
    // Calculate earnings and student count for each teacher
    const teachersWithEarnings = await Promise.all(teachers.map(async (teacher) => {
      // Find all classes for this teacher
      const classes = await Class.find({ teacherId: teacher._id });
      const classIds = classes.map(c => c._id);
      
      // Find all payments for students in these classes
      const payments = await Payment.find({ classId: { $in: classIds } });
      const totalEarnings = payments.reduce((sum, payment) => sum + (payment.amount || 0), 0);
      
      // Count students
      const studentCount = await Student.countDocuments({ classId: { $in: classIds } });
      
      return {
        _id: teacher._id,
        teacherId: teacher.teacherId,
        name: teacher.name,
        email: teacher.email,
        phone: teacher.phone,
        status: teacher.status,
        profilePicture: teacher.profilePicture,
        companyIds: teacher.companyIds,
        subscriptionType: teacher.subscriptionType,
        subscriptionStartDate: teacher.subscriptionStartDate,
        subscriptionExpiryDate: teacher.subscriptionExpiryDate,
        isRestricted: teacher.isRestricted,
        restrictedAt: teacher.restrictedAt,
        restrictionReason: teacher.restrictionReason,
        restrictedBy: teacher.restrictedBy,
        totalEarnings,
        studentCount,
        classCount: classes.length,
        createdAt: teacher.createdAt,
        updatedAt: teacher.updatedAt
      };
    }));
    
    res.json({ teachers: teachersWithEarnings });
  } catch (error) {
    console.error('Error fetching teachers for super admin:', error);
    res.status(500).json({ error: 'Failed to fetch teachers' });
  }
});

// Get students for a specific teacher
app.get('/api/super-admin/teachers/:teacherId/students', verifySuperAdmin, async (req, res) => {
  try {
    const { teacherId } = req.params;
    
    // Find all classes for this teacher
    const classes = await Class.find({ teacherId }).populate('companyId', 'companyName');
    const classIds = classes.map(c => c._id);
    
    // Find all students in these classes
    const students = await Student.find({ classId: { $in: classIds } })
      .populate('classId', 'name')
      .populate('companyId', 'companyName');
    
    // Calculate payments per student
    const studentsWithPayments = await Promise.all(students.map(async (student) => {
      const payments = await Payment.find({ studentId: student._id });
      const totalPaid = payments.reduce((sum, payment) => sum + (payment.amount || 0), 0);
      
      return {
        _id: student._id,
        name: student.name,
        email: student.email,
        phone: student.phone,
        classId: student.classId,
        companyId: student.companyId,
        totalPaid,
        paymentCount: payments.length,
        createdAt: student.createdAt,
        updatedAt: student.updatedAt
      };
    }));
    
    res.json({ 
      teacherId,
      classes,
      students: studentsWithPayments 
    });
  } catch (error) {
    console.error('Error fetching students for teacher:', error);
    res.status(500).json({ error: 'Failed to fetch students' });
  }
});

// Toggle teacher status (activate/deactivate)
app.put('/api/super-admin/teachers/:teacherId/status', verifySuperAdmin, async (req, res) => {
  try {
    const { teacherId } = req.params;
    const { status } = req.body;
    
    if (!['active', 'inactive'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status. Must be active or inactive' });
    }
    
    const teacher = await Teacher.findById(teacherId);
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    
    teacher.status = status;
    teacher.updatedAt = new Date();
    await teacher.save();
    
    // Send FCM notification to teacher about status change
    if (status === 'active') {
      await sendFCMNotificationToTeacher(
        teacherId,
        'Account Activated! 🎉',
        'Your account has been activated. You can now log in and use the app.',
        {
          type: 'status_changed',
          newStatus: status,
          timestamp: new Date().toISOString()
        }
      ).catch(err => console.log('FCM notification failed:', err));
    } else {
      await sendFCMNotificationToTeacher(
        teacherId,
        'Account Deactivated',
        'Your account has been deactivated. Contact admin for more information.',
        {
          type: 'status_changed',
          newStatus: status,
          timestamp: new Date().toISOString()
        }
      ).catch(err => console.log('FCM notification failed:', err));
    }
    
    res.json({ 
      message: `Teacher ${status === 'active' ? 'activated' : 'deactivated'} successfully`,
      teacher: {
        _id: teacher._id,
        teacherId: teacher.teacherId,
        name: teacher.name,
        status: teacher.status
      }
    });
  } catch (error) {
    console.error('Error updating teacher status:', error);
    res.status(500).json({ error: 'Failed to update teacher status' });
  }
});

// Set teacher subscription free with options
app.post('/api/super-admin/teachers/:teacherId/set-free-options', verifySuperAdmin, async (req, res) => {
  try {
    const { teacherId } = req.params;
    const { isLifetime, freeDays } = req.body;
    
    const teacher = await Teacher.findById(teacherId);
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    
    // Update subscription details
    teacher.subscriptionType = 'free';
    teacher.subscriptionStartDate = new Date();
    
    if (isLifetime) {
      // Set expiry to far future for lifetime
      teacher.subscriptionExpiryDate = new Date(Date.now() + (100 * 365 * 24 * 60 * 60 * 1000)); // 100 years
    } else {
      // Set expiry based on freeDays
      const days = freeDays || 30; // Default to 30 days if not specified
      teacher.subscriptionExpiryDate = new Date(Date.now() + (days * 24 * 60 * 60 * 1000));
    }
    
    teacher.updatedAt = new Date();
    await teacher.save();

    // Send FCM notification to teacher
    const notificationTitle = isLifetime ? 'Free Subscription Granted! 🎁' : 'Free Trial Activated! 🎁';
    const notificationBody = isLifetime 
      ? 'Congratulations! You now have a free lifetime subscription to all features.'
      : `You have been granted a free trial for ${freeDays || 30} days. Enjoy unlimited access!`;
    
    await sendFCMNotificationToTeacher(
      teacherId,
      notificationTitle,
      notificationBody,
      {
        type: 'free_subscription_granted',
        subscriptionType: 'free',
        isLifetime: isLifetime,
        expiryDate: teacher.subscriptionExpiryDate.toISOString()
      }
    ).catch(err => console.log('FCM notification failed:', err));
    
    res.json({ 
      message: `Teacher subscription set to free ${isLifetime ? 'lifetime' : `for ${freeDays || 30} days`} successfully`,
      teacher: {
        _id: teacher._id,
        teacherId: teacher.teacherId,
        name: teacher.name,
        subscriptionType: teacher.subscriptionType,
        subscriptionStartDate: teacher.subscriptionStartDate,
        subscriptionExpiryDate: teacher.subscriptionExpiryDate
      }
    });
  } catch (error) {
    console.error('Error setting teacher subscription free:', error);
    res.status(500).json({ error: 'Failed to set teacher subscription free' });
  }
});

// Start paid subscription for teacher
app.post('/api/super-admin/teachers/:teacherId/start-subscription', verifySuperAdmin, async (req, res) => {
  try {
    const { teacherId } = req.params;
    const { subscriptionType } = req.body;

    if (!subscriptionType) {
      return res.status(400).json({ error: 'subscriptionType is required' });
    }

    const teacher = await Teacher.findById(teacherId);
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    
    const wasFreePreviously = teacher.subscriptionType === 'free' && teacher.status === 'active';

    // Update subscription details based on type
    teacher.subscriptionType = subscriptionType;
    
    // If moving from free to paid, set account to inactive and require payment
    if (wasFreePreviously) {
      teacher.status = 'inactive';
      teacher.subscriptionStatus = 'none'; // Requires new payment
      teacher.subscriptionStartDate = null;
      teacher.subscriptionExpiryDate = null;

      // Send FCM notification that they need to pay
      await sendFCMNotificationToTeacher(
        teacherId,
        'Subscription Change Required',
        `Your subscription has been changed to ${subscriptionType}. Please submit your payment proof to continue.`,
        {
          type: 'subscription_change_required',
          subscriptionType: subscriptionType,
          action: 'requires_payment'
        }
      ).catch(err => console.log('FCM notification failed:', err));
    } else {
      // For new subscriptions or upgrades, just update the type
      teacher.subscriptionStartDate = new Date();

      // Set subscription expiry based on type
      if (subscriptionType === 'monthly') {
        // Monthly subscription expires in 30 days
        teacher.subscriptionExpiryDate = new Date(Date.now() + (30 * 24 * 60 * 60 * 1000));
      } else if (subscriptionType === 'yearly') {
        // Yearly subscription expires in 365 days
        teacher.subscriptionExpiryDate = new Date(Date.now() + (365 * 24 * 60 * 60 * 1000));
      } else if (subscriptionType !== 'free') {
        return res.status(400).json({ error: 'Invalid subscriptionType. Must be "monthly", "yearly", or "free"' });
      }

      // Send FCM notification for subscription upgrade
      await sendFCMNotificationToTeacher(
        teacherId,
        `${subscriptionType.charAt(0).toUpperCase() + subscriptionType.slice(1)} Subscription Activated! 🎉`,
        `Your ${subscriptionType} subscription is now active. Enjoy unlimited features!`,
        {
          type: 'subscription_activated',
          subscriptionType: subscriptionType,
          expiryDate: teacher.subscriptionExpiryDate.toISOString()
        }
      ).catch(err => console.log('FCM notification failed:', err));
    }

    teacher.updatedAt = new Date();
    await teacher.save();

    res.json({
      message: wasFreePreviously 
        ? `Teacher subscription changed from free to ${subscriptionType}. Account deactivated pending payment.`
        : `Teacher subscription set to ${subscriptionType} successfully`,
      teacher: {
        _id: teacher._id,
        teacherId: teacher.teacherId,
        name: teacher.name,
        status: teacher.status,
        subscriptionType: teacher.subscriptionType,
        subscriptionStatus: teacher.subscriptionStatus,
        subscriptionStartDate: teacher.subscriptionStartDate,
        subscriptionExpiryDate: teacher.subscriptionExpiryDate,
        requiresPayment: wasFreePreviously
      }
    });
  } catch (error) {
    console.error('Error starting teacher subscription:', error);
    res.status(500).json({ error: 'Failed to start teacher subscription' });
  }
});

// Get super admin stats
app.get('/api/super-admin/stats', verifySuperAdmin, async (req, res) => {
  try {
    const totalTeachers = await Teacher.countDocuments({});
    const activeTeachers = await Teacher.countDocuments({ status: 'active' });
    const inactiveTeachers = await Teacher.countDocuments({ status: 'inactive' });
    
    const totalStudents = await Student.countDocuments({});
    const totalClasses = await Class.countDocuments({});
    
    // Calculate total earnings
    const allPayments = await Payment.find({});
    const totalEarnings = allPayments.reduce((sum, payment) => sum + (payment.amount || 0), 0);
    
    const totalAdmins = await Admin.countDocuments({});
    const superAdmins = await Admin.countDocuments({ role: 'super-admin' });
    
    res.json({
      totalTeachers,
      activeTeachers,
      inactiveTeachers,
      totalStudents,
      totalClasses,
      totalEarnings,
      totalAdmins,
      superAdmins
    });
  } catch (error) {
    console.error('Error fetching super admin stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// Register FCM token for Super Admin
app.post('/api/super-admin/fcm-token', verifySuperAdmin, async (req, res) => {
  try {
    const { fcm_token } = req.body;
    const adminId = req.user._id;

    if (!fcm_token) {
      return res.status(400).json({ error: 'FCM token is required' });
    }

    // Update admin's FCM token
    const admin = await Admin.findByIdAndUpdate(
      adminId,
      { fcmToken: fcm_token },
      { new: true }
    );

    if (!admin) {
      return res.status(404).json({ error: 'Admin not found' });
    }

    console.log(`FCM token registered for admin: ${admin.email}`);
    res.json({ 
      message: 'FCM token registered successfully',
      fcmToken: admin.fcmToken 
    });
  } catch (error) {
    console.error('Error registering FCM token for admin:', error);
    res.status(500).json({ error: 'Failed to register FCM token' });
  }
});

// Register FCM token for Teacher
app.post('/api/teachers/fcm-token', verifyToken, async (req, res) => {
  try {
    const { fcm_token } = req.body;
    const teacherId = req.user._id || req.user.userId;

    console.log('FCM Token Registration:', {
      teacherId,
      fcm_token: fcm_token ? 'provided' : 'missing',
      userObj: req.user
    });

    if (!fcm_token) {
      return res.status(400).json({ error: 'FCM token is required' });
    }

    if (!teacherId) {
      return res.status(400).json({ error: 'Teacher ID is missing from token' });
    }

    // Update teacher's FCM token
    const teacher = await Teacher.findByIdAndUpdate(
      teacherId,
      { fcmToken: fcm_token },
      { new: true }
    );

    if (!teacher) {
      console.log('Teacher not found with ID:', teacherId);
      return res.status(404).json({ error: 'Teacher not found' });
    }

    console.log(`FCM token registered successfully for teacher: ${teacher.email}`);
    res.json({ 
      message: 'FCM token registered successfully',
      fcmToken: teacher.fcmToken 
    });
  } catch (error) {
    console.error('Error registering FCM token for teacher:', error);
    res.status(500).json({ error: 'Failed to register FCM token', details: error.message });
  }
});

// Get earnings for a specific teacher
app.get('/api/teachers/:teacherId/earnings', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.params;
    
    // Find teacher by ID
    const teacher = await Teacher.findById(teacherId);
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    
    // Find all classes for this teacher
    const classes = await Class.find({ teacherId: teacher._id });
    const classIds = classes.map(c => c._id);
    
    // Find all payments for students in these classes
    const payments = await Payment.find({ classId: { $in: classIds } });
    const totalEarnings = payments.reduce((sum, payment) => sum + (payment.amount || 0), 0);
    
    // Count students
    const studentCount = await Student.countDocuments({ classId: { $in: classIds } });
    
    res.json({
      teacherId: teacher.teacherId,
      teacherName: teacher.name,
      totalEarnings,
      studentCount,
      classCount: classes.length,
      paymentCount: payments.length
    });
  } catch (error) {
    console.error('Error fetching teacher earnings:', error);
    res.status(500).json({ error: 'Failed to fetch teacher earnings' });
  }
});

// Super admin monthly earnings by class report
app.get('/api/super-admin/reports/monthly-earnings-by-class', verifySuperAdmin, async (req, res) => {
  try {
    const { teacherId, year, month } = req.query;

    if (!teacherId) {
      return res.status(400).json({ error: 'teacherId is required' });
    }

    // Find teacher by teacherId string
    const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
    if (!teacher) {
      console.log('Teacher not found for teacherId:', teacherId);
      return res.json([]);
    }

    // Get all classes for this teacher
    const classes = await Class.find({ teacherId: teacher._id });
    
    const earningsReports = [];

    for (const classDoc of classes) {
      // Get all students in this class
      const students = await Student.find({ classId: classDoc._id });
      const studentIds = students.map(s => s._id);

      // Build payment query for this class
      let paymentQuery = { 
        classId: classDoc._id,
        studentId: { $in: studentIds }
      };

      // Add date filters if provided
      if (year && month) {
        const startDate = new Date(parseInt(year), parseInt(month) - 1, 1);
        const endDate = new Date(parseInt(year), parseInt(month), 0, 23, 59, 59);
        paymentQuery.date = { $gte: startDate, $lte: endDate };
      } else if (year) {
        const startDate = new Date(parseInt(year), 0, 1);
        const endDate = new Date(parseInt(year), 11, 31, 23, 59, 59);
        paymentQuery.date = { $gte: startDate, $lte: endDate };
      }

      // Get all payments for this class
      const payments = await Payment.find(paymentQuery);

      // Calculate total earnings
      const totalEarnings = payments.reduce((sum, payment) => sum + (payment.amount || 0), 0);

      // Group by month if no specific month provided
      const monthlyBreakdown = {};
      payments.forEach(payment => {
        if (payment.date) {
          const paymentDate = new Date(payment.date);
          const paymentMonth = payment.month || (paymentDate.getMonth() + 1);
          const monthKey = `${paymentDate.getFullYear()}-${String(paymentMonth).padStart(2, '0')}`;
          
          if (!monthlyBreakdown[monthKey]) {
            monthlyBreakdown[monthKey] = {
              year: paymentDate.getFullYear(),
              month: paymentMonth,
              amount: 0,
              paymentCount: 0
            };
          }
          
          monthlyBreakdown[monthKey].amount += payment.amount || 0;
          monthlyBreakdown[monthKey].paymentCount += 1;
        }
      });

      earningsReports.push({
        classId: classDoc._id.toString(),
        className: classDoc.name,
        studentCount: students.length,
        totalEarnings: totalEarnings,
        paymentCount: payments.length,
        monthlyBreakdown: Object.values(monthlyBreakdown).sort((a, b) => {
          if (a.year !== b.year) return b.year - a.year;
          return b.month - a.month;
        })
      });
    }

    // Sort by total earnings descending
    earningsReports.sort((a, b) => b.totalEarnings - a.totalEarnings);

    res.json(earningsReports);
  } catch (error) {
    console.error('Error in super-admin monthly-earnings-by-class:', error);
    res.status(500).json({ error: 'Failed to fetch monthly earnings by class' });
  }
});

// ==================== RESTRICTION MANAGEMENT ENDPOINTS ====================

// Super Admin: Get all teachers with their restriction status

// Super Admin: Restrict a teacher
app.post('/api/super-admin/restrict-teacher', verifySuperAdmin, async (req, res) => {
  try {
    const { teacherId, reason, adminId } = req.body;

    if (!teacherId || !adminId) {
      return res.status(400).json({ error: 'Teacher ID and Admin ID are required' });
    }

    // Update teacher restriction status
    const teacher = await Teacher.findByIdAndUpdate(
      teacherId,
      {
        isRestricted: true,
        restrictedBy: adminId,
        restrictedAt: new Date(),
        restrictionReason: reason || 'No reason provided'
      },
      { new: true }
    );

    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    // Send FCM notification to teacher about restriction
    await sendFCMNotificationToTeacher(
      teacherId,
      'Account Restricted ⛔',
      `Your account has been restricted. Reason: ${reason || 'Please contact admin for details'}`,
      {
        type: 'restriction',
        action: 'restricted',
        isRestricted: 'true',
        reason: reason || 'No reason provided'
      }
    ).catch(err => console.log('FCM notification failed:', err));

    // Get all classes taught by this teacher
    const classes = await Class.find({ teacherId: teacher._id });
    const classIds = classes.map(c => c._id);

    // Find all students in these classes
    const students = await Student.find({ classId: { $in: classIds } });

    // For each student, check if they have other non-restricted teachers
    for (const student of students) {
      // Get all classes this student is in
      const studentClasses = await Class.find({ 
        _id: { $in: [student.classId] }
      }).populate('teacherId');

      // Check if all teachers of this student are restricted
      const allTeachersRestricted = studentClasses.every(cls => 
        cls.teacherId && cls.teacherId.isRestricted
      );

      // Only restrict student if ALL their teachers are restricted
      if (allTeachersRestricted) {
        await Student.findByIdAndUpdate(
          student._id,
          {
            isRestricted: true,
            restrictedBy: adminId,
            restrictedAt: new Date(),
            restrictionReason: 'Teacher restricted'
          }
        );
      }
    }

    res.json({ 
      success: true, 
      message: 'Teacher restricted successfully',
      teacher 
    });
  } catch (error) {
    console.error('Error restricting teacher:', error);
    res.status(500).json({ error: 'Failed to restrict teacher' });
  }
});

// Super Admin: Unrestrict a teacher
app.post('/api/super-admin/unrestrict-teacher', verifySuperAdmin, async (req, res) => {
  try {
    const { teacherId } = req.body;

    if (!teacherId) {
      return res.status(400).json({ error: 'Teacher ID is required' });
    }

    // Update teacher restriction status
    const teacher = await Teacher.findByIdAndUpdate(
      teacherId,
      {
        isRestricted: false,
        restrictedBy: null,
        restrictedAt: null,
        restrictionReason: null
      },
      { new: true }
    );

    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    // Send FCM notification to teacher for immediate unrestriction
    await sendFCMNotificationToTeacher(
      teacherId,
      'Account Unrestricted',
      'Your account has been unrestricted. You can now log in again.',
      {
        type: 'restriction',
        action: 'unrestricted',
        isRestricted: 'false'
      }
    ).catch(err => console.log('FCM notification failed:', err));

    // Get all classes taught by this teacher
    const classes = await Class.find({ teacherId: teacher._id });
    const classIds = classes.map(c => c._id);

    // Find all students in these classes who were restricted due to teacher restriction
    const students = await Student.find({ 
      classId: { $in: classIds },
      isRestricted: true,
      restrictionReason: 'Teacher restricted'
    });

    // Unrestrict students who were only restricted because of this teacher
    for (const student of students) {
      // Get all classes this student is in
      const studentClasses = await Class.find({ 
        _id: { $in: [student.classId] }
      }).populate('teacherId');

      // Check if any teacher is still restricted
      const hasRestrictedTeacher = studentClasses.some(cls => 
        cls.teacherId && cls.teacherId.isRestricted && cls.teacherId._id.toString() !== teacherId
      );

      // Only unrestrict if no other teachers are restricted
      if (!hasRestrictedTeacher) {
        await Student.findByIdAndUpdate(
          student._id,
          {
            isRestricted: false,
            restrictedBy: null,
            restrictedAt: null,
            restrictionReason: null
          }
        );
      }
    }

    res.json({ 
      success: true, 
      message: 'Teacher unrestricted successfully',
      teacher 
    });
  } catch (error) {
    console.error('Error unrestricting teacher:', error);
    res.status(500).json({ error: 'Failed to unrestrict teacher' });
  }
});

// Teacher: Check restriction status (polling endpoint)
app.get('/api/teacher/restriction-status/:teacherId', async (req, res) => {
  try {
    const { teacherId } = req.params;

    const teacher = await Teacher.findOne({ teacherId })
      .select('isRestricted restrictedAt restrictionReason name email');

    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    res.json({
      isRestricted: teacher.isRestricted || false,
      restrictedAt: teacher.restrictedAt,
      restrictionReason: teacher.restrictionReason,
      name: teacher.name,
      email: teacher.email
    });
  } catch (error) {
    console.error('Error checking teacher restriction:', error);
    res.status(500).json({ error: 'Failed to check restriction status' });
  }
});

// Student: Check restriction status (polling endpoint)
app.get('/api/student/restriction-status/:studentId', async (req, res) => {
  try {
    const { studentId } = req.params;

    const student = await Student.findOne({ studentId })
      .select('isRestricted restrictedAt restrictionReason name email classId')
      .populate({
        path: 'classId',
        select: 'name teacherId',
        populate: {
          path: 'teacherId',
          select: 'name isRestricted'
        }
      });

    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Get all classes for this student (in case they're in multiple)
    const allClasses = await Class.find({ 
      _id: { $in: [student.classId] } 
    }).populate('teacherId', 'name isRestricted');

    // Filter to get available (non-restricted) classes
    const availableClasses = allClasses.filter(cls => 
      cls.teacherId && !cls.teacherId.isRestricted
    );

    // Get restricted classes
    const restrictedClasses = allClasses.filter(cls => 
      cls.teacherId && cls.teacherId.isRestricted
    );

    res.json({
      isRestricted: student.isRestricted || false,
      restrictedAt: student.restrictedAt,
      restrictionReason: student.restrictionReason,
      name: student.name,
      email: student.email,
      availableClasses: availableClasses.map(cls => ({
        id: cls._id,
        name: cls.name,
        teacherName: cls.teacherId.name
      })),
      restrictedClasses: restrictedClasses.map(cls => ({
        id: cls._id,
        name: cls.name,
        teacherName: cls.teacherId.name
      }))
    });
  } catch (error) {
    console.error('Error checking student restriction:', error);
    res.status(500).json({ error: 'Failed to check restriction status' });
  }
});

// Super Admin: Get all students with restriction status
app.get('/api/super-admin/students', verifySuperAdmin, async (req, res) => {
  try {
    const students = await Student.find({})
      .select('name email studentId isRestricted restrictedAt restrictionReason classId')
      .populate({
        path: 'classId',
        select: 'name teacherId',
        populate: {
          path: 'teacherId',
          select: 'name isRestricted'
        }
      });
    
    res.json(students);
  } catch (error) {
    console.error('Error fetching students:', error);
    res.status(500).json({ error: 'Failed to fetch students' });
  }
});

// Super Admin: Manually restrict a student
app.post('/api/super-admin/restrict-student', verifySuperAdmin, async (req, res) => {
  try {
    const { studentId, reason, adminId } = req.body;

    if (!studentId || !adminId) {
      return res.status(400).json({ error: 'Student ID and Admin ID are required' });
    }

    const student = await Student.findByIdAndUpdate(
      studentId,
      {
        isRestricted: true,
        restrictedBy: adminId,
        restrictedAt: new Date(),
        restrictionReason: reason || 'No reason provided'
      },
      { new: true }
    );

    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Send FCM notification to student
    await sendFCMNotificationToStudent(
      studentId,
      'Account Restricted ⛔',
      `Your account has been restricted. Reason: ${reason || 'Please contact admin for details'}`,
      {
        type: 'restriction',
        action: 'restricted',
        isRestricted: 'true',
        reason: reason || 'No reason provided'
      }
    ).catch(err => console.log('FCM notification failed:', err));

    res.json({ 
      success: true, 
      message: 'Student restricted successfully',
      student 
    });
  } catch (error) {
    console.error('Error restricting student:', error);
    res.status(500).json({ error: 'Failed to restrict student' });
  }
});

// Super Admin: Manually unrestrict a student
app.post('/api/super-admin/unrestrict-student', verifySuperAdmin, async (req, res) => {
  try {
    const { studentId } = req.body;

    if (!studentId) {
      return res.status(400).json({ error: 'Student ID is required' });
    }

    const student = await Student.findByIdAndUpdate(
      studentId,
      {
        isRestricted: false,
        restrictedBy: null,
        restrictedAt: null,
        restrictionReason: null
      },
      { new: true }
    );

    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Send FCM notification to student
    await sendFCMNotificationToStudent(
      studentId,
      'Account Unrestricted! ✅',
      'Your account restriction has been removed. You can now access the app again.',
      {
        type: 'restriction',
        action: 'unrestricted',
        isRestricted: 'false'
      }
    ).catch(err => console.log('FCM notification failed:', err));

    res.json({ 
      success: true, 
      message: 'Student unrestricted successfully',
      student 
    });
  } catch (error) {
    console.error('Error unrestricting student:', error);
    res.status(500).json({ error: 'Failed to unrestrict student' });
  }
});

// Teacher: Get students in their classes
app.get('/api/teacher/students', verifyTeacher, async (req, res) => {
  try {
    const teacherId = req.user.userId;

    // Find all classes taught by this teacher
    const classes = await Class.find({ teacherId: teacherId });
    const classIds = classes.map(c => c._id);

    // Get all students in these classes
    const students = await Student.find({ classId: { $in: classIds } })
      .select('name email studentId isRestricted restrictedAt restrictionReason classId')
      .populate('classId', 'name')
      .sort({ name: 1 });

    res.json(students);
  } catch (error) {
    console.error('Error fetching teacher students:', error);
    res.status(500).json({ error: 'Failed to fetch students' });
  }
});

// Teacher: Restrict a student
app.post('/api/teacher/restrict-student', verifyTeacher, async (req, res) => {
  try {
    const { studentId, reason } = req.body;
    const teacherId = req.user.userId;

    if (!studentId) {
      return res.status(400).json({ error: 'Student ID is required' });
    }

    // Verify the student is in one of the teacher's classes
    const student = await Student.findById(studentId).populate('classId');
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Check if the teacher teaches this student's class
    const teacherClass = await Class.findOne({ 
      _id: student.classId._id, 
      teacherId: teacherId 
    });

    if (!teacherClass) {
      return res.status(403).json({ error: 'You can only restrict students in your classes' });
    }

    // Restrict the student
    const updatedStudent = await Student.findByIdAndUpdate(
      studentId,
      {
        isRestricted: true,
        restrictedBy: teacherId,
        restrictedAt: new Date(),
        restrictionReason: reason || 'Restricted by teacher'
      },
      { new: true }
    ).populate('classId', 'name');

    // Send FCM notification to student
    await sendFCMNotificationToStudent(
      studentId,
      'Restricted by Teacher',
      `You have been restricted in ${updatedStudent.classId.name || 'your class'}. Reason: ${reason || 'No reason provided'}`,
      {
        type: 'restriction',
        action: 'restricted',
        isRestricted: 'true',
        reason: reason || 'Restricted by teacher',
        className: updatedStudent.classId.name
      }
    ).catch(err => console.log('FCM notification failed:', err));

    res.json({ 
      success: true, 
      message: 'Student restricted successfully',
      student: updatedStudent 
    });
  } catch (error) {
    console.error('Error restricting student:', error);
    res.status(500).json({ error: 'Failed to restrict student' });
  }
});

// Teacher: Unrestrict a student
app.post('/api/teacher/unrestrict-student', verifyTeacher, async (req, res) => {
  try {
    const { studentId } = req.body;
    const teacherId = req.user.userId;

    if (!studentId) {
      return res.status(400).json({ error: 'Student ID is required' });
    }

    // Verify the student is in one of the teacher's classes
    const student = await Student.findById(studentId).populate('classId');
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Check if the teacher teaches this student's class
    const teacherClass = await Class.findOne({ 
      _id: student.classId._id, 
      teacherId: teacherId 
    });

    if (!teacherClass) {
      return res.status(403).json({ error: 'You can only unrestrict students in your classes' });
    }

    // Unrestrict the student
    const updatedStudent = await Student.findByIdAndUpdate(
      studentId,
      {
        isRestricted: false,
        restrictedBy: null,
        restrictedAt: null,
        restrictionReason: null
      },
      { new: true }
    ).populate('classId', 'name');

    // Send FCM notification to student
    await sendFCMNotificationToStudent(
      studentId,
      'Unrestricted! ✅',
      `Your restriction in ${updatedStudent.classId.name || 'your class'} has been removed. You can now participate again.`,
      {
        type: 'restriction',
        action: 'unrestricted',
        isRestricted: 'false',
        className: updatedStudent.classId.name
      }
    ).catch(err => console.log('FCM notification failed:', err));

    res.json({ 
      success: true, 
      message: 'Student unrestricted successfully',
      student: updatedStudent 
    });
  } catch (error) {
    console.error('Error unrestricting student:', error);
    res.status(500).json({ error: 'Failed to unrestrict student' });
  }
});

// ==================== SUBSCRIPTION STATUS ENDPOINTS ====================

// Teacher: Check subscription status
app.get('/api/teacher/subscription-status/:teacherId', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.params;

    const teacher = await Teacher.findOne({ teacherId })
      .select('subscriptionType subscriptionStartDate subscriptionExpiryDate status email name');

    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    const now = new Date();
    const expiryDate = teacher.subscriptionExpiryDate ? new Date(teacher.subscriptionExpiryDate) : null;
    const isExpired = expiryDate && expiryDate < now;
    const daysUntilExpiry = expiryDate ? Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24)) : null;

    res.json({
      subscriptionType: teacher.subscriptionType || 'free',
      subscriptionStartDate: teacher.subscriptionStartDate,
      subscriptionExpiryDate: teacher.subscriptionExpiryDate,
      status: teacher.status,
      isExpired: isExpired,
      expiring: daysUntilExpiry && daysUntilExpiry <= 7,
      daysUntilExpiry: daysUntilExpiry,
      email: teacher.email,
      name: teacher.name
    });
  } catch (error) {
    console.error('Error checking teacher subscription status:', error);
    res.status(500).json({ error: 'Failed to check subscription status' });
  }
});

// Student: Check subscription status
app.get('/api/student/subscription-status/:studentId', verifyToken, async (req, res) => {
  try {
    const { studentId } = req.params;

    const student = await Student.findOne({ studentId })
      .select('subscriptionType subscriptionStartDate subscriptionExpiryDate email name')
      .populate({
        path: 'classId',
        select: 'teacherId',
        populate: {
          path: 'teacherId',
          select: 'subscriptionType subscriptionExpiryDate'
        }
      });

    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Get teacher subscription info
    let teacherSubscriptionStatus = 'free';
    let teacherSubscriptionExpired = false;
    if (student.classId && student.classId.teacherId) {
      teacherSubscriptionStatus = student.classId.teacherId.subscriptionType || 'free';
      if (student.classId.teacherId.subscriptionExpiryDate) {
        const expiryDate = new Date(student.classId.teacherId.subscriptionExpiryDate);
        teacherSubscriptionExpired = expiryDate < new Date();
      }
    }

    const now = new Date();
    const expiryDate = student.subscriptionExpiryDate ? new Date(student.subscriptionExpiryDate) : null;
    const isExpired = expiryDate && expiryDate < now;
    const daysUntilExpiry = expiryDate ? Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24)) : null;

    res.json({
      subscriptionType: student.subscriptionType || 'free',
      subscriptionStartDate: student.subscriptionStartDate,
      subscriptionExpiryDate: student.subscriptionExpiryDate,
      isExpired: isExpired,
      expiring: daysUntilExpiry && daysUntilExpiry <= 7,
      daysUntilExpiry: daysUntilExpiry,
      teacherSubscriptionStatus: teacherSubscriptionStatus,
      teacherSubscriptionExpired: teacherSubscriptionExpired,
      email: student.email,
      name: student.name
    });
  } catch (error) {
    console.error('Error checking student subscription status:', error);
    res.status(500).json({ error: 'Failed to check subscription status' });
  }
});

// ==================== ADMIN CHANGES ENDPOINTS ====================

// Teacher: Get all admin changes
app.get('/api/teacher/admin-changes/:teacherId', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.params;

    const teacher = await Teacher.findOne({ teacherId })
      .select('isRestricted restrictionReason restrictedAt subscriptionType subscriptionExpiryDate status');

    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    const now = new Date();
    const expiryDate = teacher.subscriptionExpiryDate ? new Date(teacher.subscriptionExpiryDate) : null;
    const isSubscriptionExpired = expiryDate && expiryDate < now;

    res.json({
      restrictions: {
        isRestricted: teacher.isRestricted || false,
        restrictionReason: teacher.restrictionReason,
        restrictedAt: teacher.restrictedAt
      },
      subscription: {
        status: teacher.subscriptionType || 'free',
        expiryDate: teacher.subscriptionExpiryDate,
        expiring: expiryDate && (expiryDate - now) / (1000 * 60 * 60 * 24) <= 7,
        expired: isSubscriptionExpired
      },
      status: {
        status: teacher.status || 'active',
        updatedAt: new Date()
      },
      classes: []
    });
  } catch (error) {
    console.error('Error checking teacher admin changes:', error);
    res.status(500).json({ error: 'Failed to check admin changes' });
  }
});

// Student: Get all admin changes
app.get('/api/student/admin-changes/:studentId', verifyToken, async (req, res) => {
  try {
    const { studentId } = req.params;

    const student = await Student.findOne({ studentId })
      .select('isRestricted restrictionReason restrictedAt subscriptionType subscriptionExpiryDate')
      .populate({
        path: 'classId',
        select: 'name teacherId',
        populate: {
          path: 'teacherId',
          select: 'name subscriptionType subscriptionExpiryDate'
        }
      });

    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    const now = new Date();
    const expiryDate = student.subscriptionExpiryDate ? new Date(student.subscriptionExpiryDate) : null;
    const isSubscriptionExpired = expiryDate && expiryDate < now;

    // Get teacher subscription info
    let teacherSubscriptionExpired = false;
    if (student.classId && student.classId.teacherId && student.classId.teacherId.subscriptionExpiryDate) {
      const teacherExpiryDate = new Date(student.classId.teacherId.subscriptionExpiryDate);
      teacherSubscriptionExpired = teacherExpiryDate < now;
    }

    res.json({
      restrictions: {
        isRestricted: student.isRestricted || false,
        restrictionReason: student.restrictionReason,
        restrictedAt: student.restrictedAt
      },
      subscription: {
        status: student.subscriptionType || 'free',
        expiryDate: student.subscriptionExpiryDate,
        expiring: expiryDate && (expiryDate - now) / (1000 * 60 * 60 * 24) <= 7,
        expired: isSubscriptionExpired
      },
      status: {
        status: 'active',
        updatedAt: new Date()
      },
      classes: student.classId ? [{ 
        _id: student.classId._id,
        name: student.classId.name,
        teacherId: student.classId.teacherId._id,
        teacherName: student.classId.teacherId.name,
        teacherSubscriptionExpired: teacherSubscriptionExpired
      }] : []
    });
  } catch (error) {
    console.error('Error checking student admin changes:', error);
    res.status(500).json({ error: 'Failed to check admin changes' });
  }
});

// Mark subscription warning as shown
app.post('/api/teacher/subscription-warning-shown', verifyToken, async (req, res) => {
  try {
    const { teacherEmail } = req.body;

    if (!teacherEmail) {
      return res.status(400).json({ error: 'Teacher email is required' });
    }

    const teacher = await Teacher.findOne({ email: teacherEmail });
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    teacher.lastSubscriptionWarningDate = new Date();
    await teacher.save();

    res.json({ 
      message: 'Warning date updated successfully',
      lastSubscriptionWarningDate: teacher.lastSubscriptionWarningDate 
    });
  } catch (error) {
    console.error('Error marking subscription warning shown:', error);
    res.status(500).json({ error: 'Failed to update warning date' });
  }
});

// ==================== ALTERNATIVE ENDPOINT PATHS (for backward compatibility) ====================

// Alternative path: /api/teachers/:teacherId/restriction-status
app.get('/api/teachers/:teacherId/restriction-status', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.params;
    console.log('Checking restriction status for teacher:', teacherId);

    const teacher = await Teacher.findOne({ teacherId })
      .select('isRestricted restrictedAt restrictionReason name email');

    if (!teacher) {
      console.log('Teacher not found:', teacherId);
      return res.status(404).json({ error: 'Teacher not found' });
    }

    console.log('Restriction status:', teacher.isRestricted);
    res.json({
      isRestricted: teacher.isRestricted || false,
      restrictedAt: teacher.restrictedAt,
      restrictionReason: teacher.restrictionReason,
      name: teacher.name,
      email: teacher.email
    });
  } catch (error) {
    console.error('Error checking teacher restriction:', error);
    res.status(500).json({ error: 'Failed to check restriction status', message: error.message });
  }
});

// Alternative path: /api/teachers/:teacherId/subscription-status
app.get('/api/teachers/:teacherId/subscription-status', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.params;
    console.log('Checking subscription status for teacher:', teacherId);

    const teacher = await Teacher.findOne({ teacherId })
      .select('subscriptionType subscriptionStartDate subscriptionExpiryDate status email name');

    if (!teacher) {
      console.log('Teacher not found:', teacherId);
      return res.status(404).json({ error: 'Teacher not found' });
    }

    const now = new Date();
    const expiryDate = teacher.subscriptionExpiryDate ? new Date(teacher.subscriptionExpiryDate) : null;
    const isExpired = expiryDate && expiryDate < now;
    const daysUntilExpiry = expiryDate ? Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24)) : null;

    console.log('Subscription status:', { type: teacher.subscriptionType, isExpired, daysUntilExpiry });
    res.json({
      subscriptionType: teacher.subscriptionType || 'free',
      subscriptionStartDate: teacher.subscriptionStartDate,
      subscriptionExpiryDate: teacher.subscriptionExpiryDate,
      status: teacher.status,
      isExpired: isExpired,
      expiring: daysUntilExpiry && daysUntilExpiry <= 7,
      daysUntilExpiry: daysUntilExpiry,
      email: teacher.email,
      name: teacher.name
    });
  } catch (error) {
    console.error('Error checking teacher subscription status:', error);
    res.status(500).json({ error: 'Failed to check subscription status', message: error.message });
  }
});

// Alternative path: /api/teachers/:teacherId/admin-changes
app.get('/api/teachers/:teacherId/admin-changes', verifyToken, async (req, res) => {
  try {
    const { teacherId } = req.params;
    console.log('Checking admin changes for teacher:', teacherId);

    const teacher = await Teacher.findOne({ teacherId })
      .select('isRestricted restrictionReason restrictedAt subscriptionType subscriptionExpiryDate status');

    if (!teacher) {
      console.log('Teacher not found:', teacherId);
      return res.status(404).json({ error: 'Teacher not found' });
    }

    const now = new Date();
    const expiryDate = teacher.subscriptionExpiryDate ? new Date(teacher.subscriptionExpiryDate) : null;
    const isSubscriptionExpired = expiryDate && expiryDate < now;

    console.log('Admin changes data:', { 
      isRestricted: teacher.isRestricted, 
      subscriptionType: teacher.subscriptionType,
      isExpired: isSubscriptionExpired 
    });

    res.json({
      restrictions: {
        isRestricted: teacher.isRestricted || false,
        restrictionReason: teacher.restrictionReason,
        restrictedAt: teacher.restrictedAt
      },
      subscription: {
        status: teacher.subscriptionType || 'free',
        expiryDate: teacher.subscriptionExpiryDate,
        expiring: expiryDate && (expiryDate - now) / (1000 * 60 * 60 * 24) <= 7,
        expired: isSubscriptionExpired
      },
      status: {
        status: teacher.status || 'active',
        updatedAt: new Date()
      },
      classes: []
    });
  } catch (error) {
    console.error('Error checking teacher admin changes:', error);
    res.status(500).json({ error: 'Failed to check admin changes', message: error.message });
  }
});

// Test FCM Notification endpoint
app.post('/api/test/send-notification', verifyToken, async (req, res) => {
  try {
    const { receiverId, receiverType = 'teacher', title, body } = req.body;

    if (!receiverId || !title || !body) {
      return res.status(400).json({ 
        error: 'Missing required fields: receiverId, title, body' 
      });
    }

    let success = false;
    let message = '';

    if (receiverType === 'teacher') {
      success = await sendFCMNotificationToTeacher(
        receiverId,
        title,
        body,
        { testNotification: 'true', timestamp: new Date().toISOString() }
      );
      message = success ? 'Test notification sent to teacher' : 'Failed to send notification';
    } else if (receiverType === 'admin') {
      success = await sendFCMNotificationToAdmin(
        receiverId,
        title,
        body,
        { testNotification: 'true', timestamp: new Date().toISOString() }
      );
      message = success ? 'Test notification sent to admin' : 'Failed to send notification';
    } else {
      return res.status(400).json({ error: 'Invalid receiverType. Use "teacher" or "admin"' });
    }

    res.json({ 
      success,
      message,
      details: { receiverId, receiverType, title, body }
    });
  } catch (error) {
    console.error('Error testing FCM notification:', error);
    res.status(500).json({ 
      error: 'Failed to send test notification',
      details: error.message
    });
  }
});

// Export the app for Vercel
module.exports = app;

// Only listen when not in Vercel environment
if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}