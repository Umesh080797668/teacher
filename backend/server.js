const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
const http = require('http');
const socketIo = require('socket.io');
const QRCode = require('qrcode');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: true,
    credentials: true,
  }
});
const PORT = process.env.PORT || 3004;

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

// Handle OPTIONS requests explicitly
app.options('*', cors());

// Email transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});

// MongoDB connection with connection reuse for serverless
let cachedConnection = null;

async function connectToDatabase() {
  if (cachedConnection && mongoose.connection.readyState === 1) {
    console.log('Using cached database connection');
    return cachedConnection;
  }

  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';
  console.log('Connecting to MongoDB...');
  console.log('MongoDB URI present:', !!process.env.MONGODB_URI); // Debug log

  // Retry loop to handle transient network issues on serverless platforms
  const maxAttempts = 3;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      console.log(`MongoDB connect attempt ${attempt}/${maxAttempts}`);
      cachedConnection = await mongoose.connect(mongoUri, {
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

      console.log('MongoDB connected successfully');
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

// Models
const ClassSchema = new mongoose.Schema({
  name: { type: String, required: true },
  teacherId: { type: mongoose.Schema.Types.ObjectId, ref: 'Teacher', required: true },
}, { timestamps: true });

const StudentSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: String,
  studentId: { type: String, unique: true },
  classId: { type: mongoose.Schema.Types.ObjectId, ref: 'Class' },
}, { timestamps: true });

const AttendanceSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Student', required: true },
  date: { type: Date, required: true },
  session: { type: String, default: 'daily' }, // Changed default to 'daily'
  status: { type: String, enum: ['present', 'absent', 'late'], required: true },
  month: { type: Number, required: true },
  year: { type: Number, required: true },
}, { timestamps: true });

const PaymentSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Student', required: true },
  classId: { type: mongoose.Schema.Types.ObjectId, ref: 'Class', required: true },
  amount: { type: Number, required: true },
  type: { type: String, enum: ['full', 'half', 'free'], required: true },
  date: { type: Date, default: Date.now },
}, { timestamps: true });

const TeacherSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: { type: String },
  password: { type: String, required: true },
  teacherId: { type: String, unique: true },
  status: { type: String, enum: ['active', 'inactive'], default: 'active' },
  profilePicture: { type: String }, // Profile picture path
}, { timestamps: true });

const EmailVerificationSchema = new mongoose.Schema({
  email: { type: String, required: true },
  code: { type: String, required: true },
  expiresAt: { type: Date, required: true },
}, { timestamps: true });

// Add TTL index to automatically delete expired codes
EmailVerificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const PasswordResetSchema = new mongoose.Schema({
  email: { type: String, required: true },
  resetCode: { type: String, required: true },
  expiresAt: { type: Date, required: true },
}, { timestamps: true });

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
}, { timestamps: true });

// Add TTL index to automatically delete expired sessions
WebSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

// Admin Schema for admin users
const AdminSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  name: { type: String, required: true },
  companyName: { type: String, required: true },
  role: { type: String, default: 'admin' },
}, { timestamps: true });

AttendanceSchema.index({ studentId: 1, year: 1, month: 1 });

const Student = mongoose.model('Student', StudentSchema);
const Attendance = mongoose.model('Attendance', AttendanceSchema);
const Class = mongoose.model('Class', ClassSchema);
const Payment = mongoose.model('Payment', PaymentSchema);
const Teacher = mongoose.model('Teacher', TeacherSchema);
const EmailVerification = mongoose.model('EmailVerification', EmailVerificationSchema);
const PasswordReset = mongoose.model('PasswordReset', PasswordResetSchema);
const WebSession = mongoose.model('WebSession', WebSessionSchema);
const Admin = mongoose.model('Admin', AdminSchema);

// Store for pending QR sessions and connected sockets
const pendingQRSessions = new Map(); // sessionId -> { timestamp, userType }
const connectedSockets = new Map(); // sessionId -> socket.id

// WebSocket connection handling
io.on('connection', (socket) => {
  console.log('New WebSocket connection:', socket.id);

  // Web client requests QR code
  socket.on('request-qr', async ({ userType }) => {
    try {
      const { v4: uuidv4 } = await import('uuid');
      const sessionId = uuidv4();
      const expiresAt = Date.now() + (5 * 60 * 1000); // 5 minutes
      
      pendingQRSessions.set(sessionId, {
        timestamp: Date.now(),
        expiresAt,
        userType: userType || 'teacher',
        socketId: socket.id,
      });

      // Generate QR code
      const qrData = JSON.stringify({
        sessionId,
        timestamp: Date.now(),
        expiresAt,
        type: 'web-auth',
      });

      const qrCodeDataUrl = await QRCode.toDataURL(qrData);

      socket.emit('qr-generated', {
        sessionId,
        qrCode: qrCodeDataUrl,
        expiresAt,
      });

      // Auto-cleanup expired session
      setTimeout(() => {
        if (pendingQRSessions.has(sessionId)) {
          pendingQRSessions.delete(sessionId);
          socket.emit('qr-expired', { sessionId });
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
      console.log('Authentication attempt for session:', sessionId);
      
      const pendingSession = pendingQRSessions.get(sessionId);
      
      if (!pendingSession) {
        socket.emit('auth-failed', { message: 'Invalid or expired session' });
        return;
      }

      if (Date.now() > pendingSession.expiresAt) {
        pendingQRSessions.delete(sessionId);
        socket.emit('auth-failed', { message: 'Session expired' });
        return;
      }

      // Find teacher
      const teacher = await Teacher.findOne({ teacherId });
      
      if (!teacher) {
        socket.emit('auth-failed', { message: 'Teacher not found' });
        return;
      }

      if (teacher.status !== 'active') {
        socket.emit('auth-failed', { message: 'Teacher account is inactive' });
        return;
      }

      // Create web session
      const webSession = new WebSession({
        sessionId,
        userId: teacher._id,
        userModel: 'Teacher',
        userType: pendingSession.userType,
        deviceId: deviceId || socket.id,
        isActive: true,
        expiresAt: new Date(Date.now() + (24 * 60 * 60 * 1000)), // 24 hours
        teacherId: teacher.teacherId,
      });

      await webSession.save();

      // Generate JWT token
      const token = jwt.sign(
        {
          sessionId,
          userId: teacher._id,
          teacherId: teacher.teacherId,
          userType: pendingSession.userType,
        },
        process.env.JWT_SECRET || 'your-secret-key',
        { expiresIn: '24h' }
      );

      // Notify web client
      const webSocketId = pendingSession.socketId;
      io.to(webSocketId).emit('authenticated', {
        success: true,
        user: {
          _id: teacher._id,
          name: teacher.name,
          email: teacher.email,
          teacherId: teacher.teacherId,
          status: teacher.status,
        },
        session: webSession,
        token,
      });

      // Notify mobile app
      socket.emit('auth-success', {
        message: 'Successfully authenticated',
        sessionId,
      });

      // Store connected socket
      connectedSockets.set(sessionId, webSocketId);
      pendingQRSessions.delete(sessionId);

      console.log('Authentication successful for session:', sessionId);
    } catch (error) {
      console.error('Error authenticating QR:', error);
      socket.emit('auth-failed', { message: 'Authentication failed' });
    }
  });

  // Disconnect session
  socket.on('disconnect-session', async ({ sessionId }) => {
    try {
      await WebSession.findOneAndUpdate(
        { sessionId },
        { isActive: false }
      );
      
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

  socket.on('disconnect', () => {
    console.log('WebSocket disconnected:', socket.id);
    
    // Clean up any sessions associated with this socket
    for (const [sessionId, socketId] of connectedSockets.entries()) {
      if (socketId === socket.id) {
        connectedSockets.delete(sessionId);
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
app.get('/api/students', async (req, res) => {
  try {
    console.log('GET /api/students called');
    console.log('MongoDB connection state:', mongoose.connection.readyState);
    const { teacherId } = req.query;

    let query = {};
    if (teacherId) {
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

app.post('/api/students', async (req, res) => {
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

app.get('/api/students/:id', async (req, res) => {
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

app.put('/api/students/:id', async (req, res) => {
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

app.delete('/api/students/:id', async (req, res) => {
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
app.get('/api/attendance', async (req, res) => {
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

    const attendance = await Attendance.find(query).sort({ date: -1 });
    res.json(attendance);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch attendance' });
  }
});

app.post('/api/attendance', async (req, res) => {
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
    
    const attendanceDate = new Date(date);
    console.log('Parsed date:', attendanceDate);
    
    const attendance = new Attendance({
      studentId: studentObjectId,
      date: attendanceDate,
      session,
      status,
      month: attendanceDate.getMonth() + 1,
      year: attendanceDate.getFullYear(),
    });
    console.log('Saving attendance:', attendance);
    await attendance.save();
    res.status(201).json(attendance);
  } catch (error) {
    console.error('Error creating attendance record:', error);
    res.status(500).json({ error: 'Failed to create attendance record', details: error.message });
  }
});

// Classes
app.get('/api/classes', async (req, res) => {
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

app.post('/api/classes', async (req, res) => {
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

app.get('/api/classes/:id', async (req, res) => {
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

app.put('/api/classes/:id', async (req, res) => {
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

app.delete('/api/classes/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await Class.findByIdAndDelete(id);
    res.status(200).json({ message: 'Class deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete class' });
  }
});

// Payments
app.get('/api/payments', async (req, res) => {
  try {
    const { classId, studentId, teacherId } = req.query;
    let query = {};
    if (classId) query.classId = classId;
    if (studentId) query.studentId = studentId;

    if (teacherId) {
      // Find teacher by teacherId string and get their classes
      console.log('Filtering payments for teacherId:', teacherId);
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

    const payments = await Payment.find(query).sort({ date: -1 });
    res.json(payments);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch payments' });
  }
});

app.post('/api/payments', async (req, res) => {
  try {
    const { studentId, classId, amount, type } = req.body;
    
    // Convert IDs to ObjectId if they're strings
    let studentObjectId = studentId;
    let classObjectId = classId;
    
    if (typeof studentId === 'string' && studentId.match(/^[0-9a-fA-F]{24}$/)) {
      studentObjectId = new mongoose.Types.ObjectId(studentId);
    }
    if (typeof classId === 'string' && classId.match(/^[0-9a-fA-F]{24}$/)) {
      classObjectId = new mongoose.Types.ObjectId(classId);
    }
    
    const payment = new Payment({ studentId: studentObjectId, classId: classObjectId, amount, type });
    await payment.save();
    res.status(201).json(payment);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create payment' });
  }
});

app.delete('/api/payments/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await Payment.findByIdAndDelete(id);
    res.status(200).json({ message: 'Payment deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete payment' });
  }
});

// Teachers
app.get('/api/teachers', async (req, res) => {
  try {
    const { status } = req.query;
    let query = {};
    if (status) query.status = status;
    
    const teachers = await Teacher.find(query);
    res.json(teachers);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch teachers' });
  }
});

app.get('/api/teachers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Try to find by teacherId first, then by _id if that fails
    let teacher = await Teacher.findOne({ teacherId: id });
    
    // If not found by teacherId, try by _id
    if (!teacher) {
      teacher = await Teacher.findById(id);
    }
    
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    res.json(teacher);
  } catch (error) {
    console.error('Error fetching teacher:', error);
    res.status(500).json({ error: 'Failed to fetch teacher' });
  }
});

app.post('/api/teachers', async (req, res) => {
  try {
    const { name, email, phone, password, teacherId, status = 'active' } = req.body;
    
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
    
    const teacher = new Teacher({ name, email, phone, password: hashedPassword, teacherId: finalTeacherId, status });
    await teacher.save();
    res.status(201).json(teacher);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create teacher' });
  }
});

app.put('/api/teachers/:id', async (req, res) => {
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

app.put('/api/teachers/:id/status', async (req, res) => {
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
app.get('/api/reports/attendance-summary', async (req, res) => {
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

app.get('/api/reports/student-reports', async (req, res) => {
  try {
    const { teacherId } = req.query;

    let studentQuery = {};
    if (teacherId) {
      // Find teacher by teacherId string and get their students
      console.log('Filtering student reports for teacherId:', teacherId);
      const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
      if (teacher) {
        const classes = await Class.find({ teacherId: teacher._id });
        const classIds = classes.map(c => c._id);
        studentQuery.classId = { $in: classIds };
        console.log('Found', classIds.length, 'classes for teacher');
      } else {
        console.log('Teacher not found for teacherId:', teacherId, '- returning empty array');
        return res.json([]);
      }
    }

    const students = await Student.find(studentQuery);
    const reports = [];

    for (const student of students) {
      const attendanceRecords = await Attendance.find({ studentId: student._id });
      const totalRecords = attendanceRecords.length;
      const presentCount = attendanceRecords.filter(a => a.status === 'present').length;
      const absentCount = attendanceRecords.filter(a => a.status === 'absent').length;
      const lateCount = attendanceRecords.filter(a => a.status === 'late').length;

      const attendanceRate = totalRecords > 0 ? (presentCount / totalRecords) * 100 : 0;

      reports.push({
        studentId: student._id,
        studentName: student.name,
        totalRecords,
        presentCount,
        absentCount,
        lateCount,
        attendanceRate
      });
    }

    res.json(reports);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch student reports' });
  }
});

app.get('/api/reports/monthly-stats', async (req, res) => {
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

// Daily attendance by class
app.get('/api/reports/daily-by-class', async (req, res) => {
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
app.get('/api/reports/monthly-by-class', async (req, res) => {
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

      const pipeline = [
        {
          $match: { studentId: { $in: studentIds } }
        },
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

      const monthlyStats = await Attendance.aggregate(pipeline);

      reports.push({
        classId: classObj._id,
        className: classObj.name,
        totalStudents: studentIds.length,
        monthlyStats
      });
    }

    res.json(reports);
  } catch (error) {
    console.error('Error fetching monthly stats by class:', error);
    res.status(500).json({ error: 'Failed to fetch monthly stats by class' });
  }
});

// Home Dashboard Endpoints
app.get('/api/home/stats', async (req, res) => {
  try {
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
    res.status(500).json({ error: 'Failed to fetch home stats' });
  }
});

app.get('/api/home/activities', async (req, res) => {
  try {
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
    res.status(500).json({ error: 'Failed to fetch home activities' });
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
    
    // Check if teacher is active
    if (teacher.status !== 'active') {
      console.log('Login attempt failed: Inactive account for email:', normalizedEmail);
      return res.status(403).json({ 
        error: 'Account is not active. Please contact support.',
        code: 'ACCOUNT_INACTIVE'
      });
    }
    
    // Return teacher data (excluding password)
    const teacherData = {
      _id: teacher._id,
      name: teacher.name,
      email: teacher.email,
      phone: teacher.phone,
      teacherId: teacher.teacherId,
      status: teacher.status
    };
    
    console.log('Login successful for email:', normalizedEmail);
    res.json({ message: 'Login successful', teacher: teacherData });
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

// Middleware to verify JWT token
const verifyToken = (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Get active web sessions
app.get('/api/web-session/active', verifyToken, async (req, res) => {
  try {
    const sessions = await WebSession.find({
      isActive: true,
      expiresAt: { $gt: new Date() },
    }).populate('userId');
    
    res.json(sessions);
  } catch (error) {
    console.error('Error fetching active sessions:', error);
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
    const { sessionId } = req.body;
    
    await WebSession.findOneAndUpdate(
      { sessionId },
      { isActive: false }
    );
    
    // Notify via WebSocket
    io.emit('session-disconnected', { sessionId });
    
    res.json({ message: 'Session disconnected successfully' });
  } catch (error) {
    console.error('Error disconnecting session:', error);
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
  try {
    const { companyId } = req.params;
    
    // First, get all teachers under this company
    const teachers = await Teacher.find({ companyId });
    const teacherIds = teachers.map(t => t._id);
    
    // Then get all active sessions for these teachers
    const sessions = await WebSession.find({
      userId: { $in: teacherIds },
      userType: 'teacher',
      isActive: true,
      expiresAt: { $gt: new Date() },
    }).populate('userId');
    
    res.json(sessions);
  } catch (error) {
    console.error('Error fetching company teacher sessions:', error);
    res.status(500).json({ error: 'Failed to fetch teacher sessions' });
  }
});

// Logout a teacher session (admin action)
app.post('/api/web-session/logout-teacher', verifyToken, async (req, res) => {
  try {
    const { sessionId } = req.body;
    
    if (!sessionId) {
      return res.status(400).json({ error: 'Session ID is required' });
    }
    
    const session = await WebSession.findOneAndUpdate(
      { sessionId },
      { isActive: false, expiresAt: new Date() }
    );
    
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }
    
    // Notify via WebSocket
    io.emit('session-disconnected', { sessionId });
    
    res.json({ message: 'Teacher logged out successfully' });
  } catch (error) {
    console.error('Error logging out teacher:', error);
    res.status(500).json({ error: 'Failed to logout teacher' });
  }
});

// Generate QR code for web login (HTTP endpoint)
app.post('/api/web-session/generate-qr', async (req, res) => {
  try {
    await connectToDatabase();
    
    const { v4: uuidv4 } = await import('uuid');
    const { userType = 'teacher' } = req.body;
    const sessionId = uuidv4();
    // No expiration - QR codes are valid indefinitely
    const expiresAt = new Date(Date.now() + (365 * 24 * 60 * 60 * 1000)); // 1 year (effectively no expiration)
    
    // Create web session
    const webSession = new WebSession({
      sessionId,
      userType,
      isActive: false, // Will be activated when scanned
      expiresAt,
    });
    
    await webSession.save();
    
    // Generate QR code with format expected by mobile app
    const qrData = JSON.stringify({
      type: 'web-auth',
      sessionId,
      userType, // Keep for backward compatibility
    });
    
    console.log('Generated QR code data:', qrData);
    
    const qrCode = await QRCode.toDataURL(qrData);
    
    res.json({
      sessionId,
      qrCode,
    });
  } catch (error) {
    console.error('Error generating QR code:', error);
    res.status(500).json({ error: 'Failed to generate QR code' });
  }
});

// Check if QR session is authenticated (polling endpoint)
app.get('/api/web-session/check-auth/:sessionId', async (req, res) => {
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
      const token = jwt.sign(
        {
          sessionId: session.sessionId,
          userId: session.userId._id,
          userType: session.userType,
        },
        process.env.JWT_SECRET || 'your-secret-key',
        { expiresIn: '24h' }
      );
      
      console.log('Session is authenticated, returning success');
      
      return res.json({
        authenticated: true,
        success: true,
        user: session.userId,
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
app.post('/api/web-session/authenticate', async (req, res) => {
  try {
    await connectToDatabase();
    
    const { sessionId, teacherId, deviceId } = req.body;
    
    console.log('=== Web Session Authentication Request ===');
    console.log('Session ID:', sessionId);
    console.log('Teacher ID:', teacherId);
    console.log('Device ID:', deviceId);
    
    // Validate input
    if (!sessionId || !teacherId) {
      console.log('ERROR: Missing required fields');
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required fields' 
      });
    }
    
    // Find the web session
    const session = await WebSession.findOne({
      sessionId,
      expiresAt: { $gt: new Date() },
    });
    
    if (!session) {
      console.log('ERROR: Session not found or expired');
      return res.status(404).json({ 
        success: false, 
        message: 'Session not found or expired' 
      });
    }
    
    console.log('Session found:', session.sessionId);
    
    // Find the teacher by teacherId field (not MongoDB _id)
    const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
    
    if (!teacher) {
      console.log('ERROR: Teacher not found for teacherId:', teacherId);
      return res.status(404).json({ 
        success: false, 
        message: 'Teacher not found' 
      });
    }
    
    console.log('Teacher found:', teacher.name, '(ID:', teacher.teacherId, ')');
    
    // Update session with teacher info
    session.userId = teacher._id; // Store as ObjectId, not string
    session.userModel = 'Teacher'; // Set the model reference
    session.teacherId = teacher.teacherId; // Custom teacher ID (TCH...)
    session.isActive = true;
    session.deviceId = deviceId || 'mobile-app';
    
    await session.save();
    
    console.log('SUCCESS: Session updated and activated');
    console.log('Session details:', {
      sessionId: session.sessionId,
      userId: session.userId,
      isActive: session.isActive,
      teacherId: session.teacherId,
    });
    
    res.json({
      success: true,
      message: 'Authentication successful',
      sessionId,
      teacher: {
        id: teacher._id,
        name: teacher.name,
        email: teacher.email,
      },
    });
  } catch (error) {
    console.error('ERROR in web-session authentication:', error);
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
    });
    
    await webSession.save();
    
    const token = jwt.sign(
      {
        sessionId,
        userId: admin._id,
        userType: 'admin',
      },
      process.env.JWT_SECRET || 'your-secret-key',
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

// Export the app for Vercel
module.exports = app;

// Only listen when not in Vercel environment
if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}