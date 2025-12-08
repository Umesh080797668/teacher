const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3004;

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile')
.then(() => console.log('MongoDB connected'))
.catch(err => console.error('MongoDB connection error:', err));

// Models
const ClassSchema = new mongoose.Schema({
  name: { type: String, required: true },
  teacherId: { type: String, required: true },
}, { timestamps: true });

const StudentSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: String,
  studentId: { type: String, unique: true },
  classId: String,
}, { timestamps: true });

const AttendanceSchema = new mongoose.Schema({
  studentId: { type: String, required: true },
  date: { type: Date, required: true },
  session: { type: String, default: 'daily' }, // Changed default to 'daily'
  status: { type: String, enum: ['present', 'absent', 'late'], required: true },
  month: { type: Number, required: true },
  year: { type: Number, required: true },
}, { timestamps: true });

const PaymentSchema = new mongoose.Schema({
  studentId: { type: String, required: true },
  classId: { type: String, required: true },
  amount: { type: Number, required: true },
  type: { type: String, enum: ['full', 'half', 'free'], required: true },
  date: { type: Date, default: Date.now },
}, { timestamps: true });

AttendanceSchema.index({ studentId: 1, year: 1, month: 1 });

const Student = mongoose.model('Student', StudentSchema);
const Attendance = mongoose.model('Attendance', AttendanceSchema);
const Class = mongoose.model('Class', ClassSchema);
const Payment = mongoose.model('Payment', PaymentSchema);

// Routes
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
    
    const student = new Student({ name, email, studentId: finalStudentId, classId });
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
    const attendanceDate = new Date(date);
    const attendance = new Attendance({
      studentId,
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
    const classObj = new Class({ name, teacherId });
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
    const payment = new Payment({ studentId, classId, amount, type });
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

// Reports
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

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});