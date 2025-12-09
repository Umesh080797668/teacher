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

  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';
    console.log('Connecting to MongoDB...');
    console.log('MongoDB URI present:', !!process.env.MONGODB_URI); // Debug log
    
    // Use slightly more permissive timeouts and smaller pools for serverless
    cachedConnection = await mongoose.connect(mongoUri, {
      // Give the driver more time to find servers in transient serverless networks
      serverSelectionTimeoutMS: 30000,
      connectTimeoutMS: 20000,
      socketTimeoutMS: 45000,
      // Keep pool small for serverless to avoid too many concurrent sockets
      maxPoolSize: 10,
      minPoolSize: 0,
      // Try to prefer IPv4 where possible (may help in some environments)
      family: 4,
      // Don't buffer commands while connecting to surface errors quickly
      bufferCommands: false,
    });
    
    console.log('MongoDB connected successfully');
    return cachedConnection;
  } catch (error) {
    console.error('MongoDB connection error:', error.message);
    console.error('Full error:', error);
    throw error;
  }
}

// Initialize connection
connectToDatabase();

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

AttendanceSchema.index({ studentId: 1, year: 1, month: 1 });

const Student = mongoose.model('Student', StudentSchema);
const Attendance = mongoose.model('Attendance', AttendanceSchema);
const Class = mongoose.model('Class', ClassSchema);
const Payment = mongoose.model('Payment', PaymentSchema);
const Teacher = mongoose.model('Teacher', TeacherSchema);
const EmailVerification = mongoose.model('EmailVerification', EmailVerificationSchema);

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
    const classes = await Class.find({});
    res.json(classes);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch classes' });
  }
});

app.post('/api/classes', async (req, res) => {
  try {
    const { name, teacherId } = req.body;
    
    // Convert teacherId to ObjectId if it's a string
    let teacherObjectId = teacherId;
    if (typeof teacherId === 'string' && teacherId.match(/^[0-9a-fA-F]{24}$/)) {
      teacherObjectId = new mongoose.Types.ObjectId(teacherId);
    }
    
    const classObj = new Class({ name, teacherId: teacherObjectId });
    await classObj.save();
    res.status(201).json(classObj);
  } catch (error) {
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
      subject: 'Email Verification Code',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #6750A4;">Email Verification</h2>
          <p>Your verification code is:</p>
          <div style="background-color: #f0f0f0; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 5px;">
            ${code}
          </div>
          <p>This code will expire in 10 minutes.</p>
          <p>If you didn't request this code, please ignore this email.</p>
        </div>
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
      return res.status(400).json({ error: 'Email and password are required' });
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
      return res.status(500).json({ error: 'Database connection error. Please try again.' });
    }
    
    if (!teacher) {
      console.log('Login attempt failed: Teacher not found for email:', normalizedEmail);
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    // Check if teacher has a password set
    if (!teacher.password) {
      console.error('Login attempt failed: Teacher has no password set:', normalizedEmail);
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    // Check password using bcrypt with additional error handling
    let isPasswordValid = false;
    try {
      console.log('Comparing password with bcrypt');
      isPasswordValid = await bcrypt.compare(password, teacher.password);
      console.log('Password comparison completed, valid:', isPasswordValid);
    } catch (bcryptError) {
      console.error('Bcrypt comparison error:', bcryptError);
      return res.status(500).json({ error: 'Authentication error. Please try again.' });
    }
    
    if (!isPasswordValid) {
      console.log('Login attempt failed: Invalid password for email:', normalizedEmail);
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    // Check if teacher is active
    if (teacher.status !== 'active') {
      console.log('Login attempt failed: Inactive account for email:', normalizedEmail);
      return res.status(403).json({ error: 'Account is not active. Please contact support.' });
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
    res.status(500).json({ error: 'An error occurred during login. Please try again later.' });
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