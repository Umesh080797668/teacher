const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const AdminSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  name: { type: String, required: true },
  companyName: { type: String, required: true },
  role: { type: String, enum: ['admin', 'super-admin'], default: 'admin' },
}, { timestamps: true });

const Admin = mongoose.model('Admin', AdminSchema);

async function addSuperAdmin() {
  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';

    console.log('Connecting to MongoDB...');
    await mongoose.connect(mongoUri);

    const email = 'eduverseadmin@gmail.com';
    const password = 'imantha2004';
    const name = 'Imantha Umesh';
    const companyName = 'EduVerse';

    // Check if super admin already exists
    const existingAdmin = await Admin.findOne({ email });
    if (existingAdmin) {
      console.log('Super admin already exists!');
      return;
    }

    // Hash the password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Create super admin
    const superAdmin = new Admin({
      email,
      password: hashedPassword,
      name,
      companyName,
      role: 'super-admin'
    });

    await superAdmin.save();

    console.log('Super admin added successfully!');
    console.log('Email:', email);
    console.log('Password:', password);
    console.log('Role: super-admin');

  } catch (error) {
    console.error('Error adding super admin:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  }
}

addSuperAdmin();