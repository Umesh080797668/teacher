const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3004;

// Middleware
app.use(cors());
app.use(express.json());

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

AttendanceSchema.index({ studentId: 1, year: 1, month: 1 });

const Student = mongoose.model('Student', StudentSchema);
const Attendance = mongoose.model('Attendance', AttendanceSchema);
const Class = mongoose.model('Class', ClassSchema);
const Payment = mongoose.model('Payment', PaymentSchema);
const Teacher = mongoose.model('Teacher', TeacherSchema);
const EmailVerification = mongoose.model('EmailVerification', EmailVerificationSchema);
const PasswordReset = mongoose.model('PasswordReset', PasswordResetSchema);

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
    const students = await Student.find({});
    res.json(students);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch students' });
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

// Attendance
app.get('/api/attendance', async (req, res) => {
  try {
    const { studentId, month, year } = req.query;
    let query = {};
    if (studentId) query.studentId = studentId;
    if (month) query.month = parseInt(month);
    if (year) query.year = parseInt(year);

    const attendance = await Attendance.find(query).sort({ date: -1 });
    res.json(attendance);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch attendance' });
  }
});

app.post('/api/attendance', async (req, res) => {
  try {
    const { studentId, date, session = 'daily', status } = req.body;
    
    // Convert studentId to ObjectId if it's a string
    let studentObjectId = studentId;
    if (typeof studentId === 'string' && studentId.match(/^[0-9a-fA-F]{24}$/)) {
      studentObjectId = new mongoose.Types.ObjectId(studentId);
    }
    
    const attendanceDate = new Date(date);
    const attendance = new Attendance({
      studentId: studentObjectId,
      date: attendanceDate,
      session,
      status,
      month: attendanceDate.getMonth() + 1,
      year: attendanceDate.getFullYear(),
    });
    await attendance.save();
    res.status(201).json(attendance);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create attendance record' });
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
    const { classId, studentId } = req.query;
    let query = {};
    if (classId) query.classId = classId;
    if (studentId) query.studentId = studentId;

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
    const { name, email, phone, password, status } = req.body;
    
    // Prepare update object
    const updateData = { name, email, phone, status };
    
    // Hash password if provided
    if (password) {
      const saltRounds = 10;
      updateData.password = await bcrypt.hash(password, saltRounds);
    }
    
    const updatedTeacher = await Teacher.findByIdAndUpdate(id, updateData, { new: true });
    if (!updatedTeacher) {
      return res.status(404).json({ error: 'Teacher not found' });
    }
    res.status(200).json(updatedTeacher);
  } catch (error) {
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
    const today = new Date();
    const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const endOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);

    // Total students
    const totalStudents = await Student.countDocuments();

    // Today's attendance
    const todayAttendance = await Attendance.find({
      date: { $gte: startOfDay, $lt: endOfDay }
    });

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
    const students = await Student.find({});
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
    const monthlyStats = await Attendance.aggregate([
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
    ]);

    res.json(monthlyStats);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch monthly stats' });
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

// Export the app for Vercel
module.exports = app;

// Only listen when not in Vercel environment
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}