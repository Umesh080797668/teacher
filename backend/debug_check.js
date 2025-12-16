const mongoose = require('mongoose');
require('dotenv').config();

const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';

const TeacherSchema = new mongoose.Schema({
  name: String,
  teacherId: String,
  companyIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }],
});

const WebSessionSchema = new mongoose.Schema({
  sessionId: String,
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'Teacher' },
  userType: String,
  isActive: Boolean,
  expiresAt: Date,
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' },
});

const Teacher = mongoose.model('Teacher', TeacherSchema);
const WebSession = mongoose.model('WebSession', WebSessionSchema);

async function run() {
  try {
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    const companyId = '694009d60baf794f08d323ac'; // From user request
    console.log(`Checking for companyId: ${companyId}`);

    // 1. Check Teachers linked to this company
    const teachers = await Teacher.find({ companyIds: new mongoose.Types.ObjectId(companyId) });
    console.log(`Teachers linked to company: ${teachers.length}`);
    teachers.forEach(t => console.log(` - ${t.name} (${t.teacherId})`));

    if (teachers.length === 0) {
        console.log('No teachers linked. Checking all teachers...');
        const allTeachers = await Teacher.find({});
        allTeachers.forEach(t => console.log(` - ${t.name}: companyIds=[${t.companyIds}]`));
    }

    // 2. Check ALL WebSessions for this company (Active or Inactive)
    const allCompanySessions = await WebSession.find({ 
        companyId: new mongoose.Types.ObjectId(companyId)
    });
    console.log(`Total WebSessions with companyId: ${allCompanySessions.length}`);
    allCompanySessions.forEach(s => console.log(` - Session ${s.sessionId}: active=${s.isActive}, userId=${s.userId}`));

    // 4. Check recent sessions (last 1 hour)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentSessions = await WebSession.find({ createdAt: { $gt: oneHourAgo } });
    console.log(`Recent sessions (last 1 hour): ${recentSessions.length}`);
    recentSessions.forEach(s => {
        console.log(` - Session ${s.sessionId}`);
        console.log(`   companyId: ${s.companyId}`);
        console.log(`   isActive: ${s.isActive}`);
        console.log(`   userId: ${s.userId}`);
        console.log(`   createdAt: ${s.createdAt}`);
    });

    // 3. Check Active WebSessions for the linked teachers (alternative query)
    if (teachers.length > 0) {
        const teacherIds = teachers.map(t => t._id);
        const teacherSessions = await WebSession.find({
            userId: { $in: teacherIds },
            isActive: true
        });
        console.log(`Active WebSessions for linked teachers: ${teacherSessions.length}`);
        teacherSessions.forEach(s => console.log(` - Session ${s.sessionId}: companyId=${s.companyId}`));
    }

  } catch (error) {
    console.error(error);
  } finally {
    await mongoose.disconnect();
  }
}

run();
