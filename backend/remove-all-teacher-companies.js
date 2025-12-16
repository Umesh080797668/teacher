// Script to remove companyId from all teachers
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

async function removeAllTeacherCompanies() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✓ Connected to MongoDB');

    // Get command line arguments
    const companyId = process.argv[2];

    if (!companyId) {
      console.log('\n=== Usage ===');
      console.log('node remove-all-teacher-companies.js <companyId>');
      console.log('\nExample:');
      console.log('node remove-all-teacher-companies.js 694009d60baf794f08d323ac');
      console.log('\n=== Current Teachers ===');

      const teachers = await Teacher.find({});
      teachers.forEach(t => {
        console.log(`- ${t.teacherId} (${t.name}): companyIds = [${t.companyIds.map(id => id.toString()).join(', ')}]`);
      });

      process.exit(1);
    }

    console.log('\n=== Removing Company from All Teachers ===');
    console.log('Company ID to remove:', companyId);

    // Find all teachers with this company ID
    const teachers = await Teacher.find({ companyIds: companyId });

    if (teachers.length === 0) {
      console.log('❌ No teachers found with this company ID');
      process.exit(1);
    }

    console.log(`\n✓ Found ${teachers.length} teachers with this company ID:`);
    teachers.forEach(t => {
      console.log(`- ${t.teacherId} (${t.name})`);
    });

    // Remove company from all teachers
    const result = await Teacher.updateMany(
      { companyIds: companyId },
      { $pull: { companyIds: new mongoose.Types.ObjectId(companyId) } }
    );

    console.log(`\n✓✓✓ SUCCESS: Company removed from ${result.modifiedCount} teachers`);

    console.log('\n=== Verification ===');
    const updatedTeachers = await Teacher.find({});
    updatedTeachers.forEach(t => {
      console.log(`- ${t.teacherId} (${t.name}): companyIds = [${t.companyIds.map(id => id.toString()).join(', ')}]`);
    });

    console.log('\n✓ Done!');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await mongoose.disconnect();
  }
}

removeAllTeacherCompanies();