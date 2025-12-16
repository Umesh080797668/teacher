// Script to remove companyId from teacher
const mongoose = require('mongoose');
require('dotenv').config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher-attendance';

// Define schemas
const TeacherSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  teacherId: { type: String, required: true, unique: true },
  phone: String,
  status: { type: String, enum: ['active', 'inactive'], default: 'active' },
  companyIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Admin' }],
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const Teacher = mongoose.model('Teacher', TeacherSchema);

async function removeTeacherCompany() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✓ Connected to MongoDB');

    // Get command line arguments
    const teacherId = process.argv[2];
    const companyId = process.argv[3];

    if (!teacherId || !companyId) {
      console.log('\n=== Usage ===');
      console.log('node remove-teacher-company.js <teacherId> <companyId>');
      console.log('\nExample:');
      console.log('node remove-teacher-company.js TCH828985185 694009d60baf794f08d323ac');
      console.log('\n=== Current Teachers ===');

      const teachers = await Teacher.find({});
      teachers.forEach(t => {
        console.log(`- ${t.teacherId} (${t.name}): companyIds = [${t.companyIds.map(id => id.toString()).join(', ')}]`);
      });

      process.exit(1);
    }

    console.log('\n=== Removing Company from Teacher ===');
    console.log('Teacher ID:', teacherId);
    console.log('Company ID to remove:', companyId);

    // Find teacher
    const teacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });

    if (!teacher) {
      console.log('❌ Teacher not found:', teacherId);
      process.exit(1);
    }

    console.log('\n✓ Teacher found:', teacher.name);
    console.log('Current companyIds:', teacher.companyIds.map(id => id.toString()));

    // Check if company exists
    const hasCompany = teacher.companyIds.some(id => id.toString() === companyId);

    if (!hasCompany) {
      console.log('\n✓ Teacher does not have this company');
    } else {
      // Remove company
      teacher.companyIds = teacher.companyIds.filter(id => id.toString() !== companyId);
      await teacher.save();
      console.log('\n✓✓✓ SUCCESS: Company removed from teacher');
      console.log('Updated companyIds:', teacher.companyIds.map(id => id.toString()));
    }

    console.log('\n=== Verification ===');
    const updatedTeacher = await Teacher.findOne({ teacherId: new RegExp('^' + teacherId + '$', 'i') });
    console.log('Teacher:', updatedTeacher.name);
    console.log('Email:', updatedTeacher.email);
    console.log('TeacherId:', updatedTeacher.teacherId);
    console.log('CompanyIds:', updatedTeacher.companyIds.map(id => id.toString()));
    console.log('\n✓ Done!');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await mongoose.disconnect();
  }
}

removeTeacherCompany();