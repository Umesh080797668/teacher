const mongoose = require('mongoose');
require('dotenv').config();

const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';

const WebSessionSchema = new mongoose.Schema({
  sessionId: String,
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'Teacher' },
  userType: String,
  isActive: Boolean,
  expiresAt: Date,
  companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' },
});

const WebSession = mongoose.model('WebSession', WebSessionSchema);

async function run() {
  try {
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    const companyIdStr = '694009d60baf794f08d323ac';
    const sessionId = 'test-session-' + Date.now();

    console.log(`Creating test session with companyId: ${companyIdStr}`);

    const session = new WebSession({
        sessionId,
        userType: 'teacher',
        isActive: false,
        expiresAt: new Date(Date.now() + 3600000),
        companyId: companyIdStr // Passing as string
    });

    await session.save();
    console.log('Session saved.');

    const savedSession = await WebSession.findOne({ sessionId });
    console.log('Retrieved session:');
    console.log(` - sessionId: ${savedSession.sessionId}`);
    console.log(` - companyId: ${savedSession.companyId}`);
    console.log(` - companyId type: ${typeof savedSession.companyId}`);
    console.log(` - companyId constructor: ${savedSession.companyId ? savedSession.companyId.constructor.name : 'N/A'}`);

    if (savedSession.companyId && savedSession.companyId.toString() === companyIdStr) {
        console.log('SUCCESS: companyId saved correctly.');
    } else {
        console.log('FAILURE: companyId NOT saved correctly.');
    }

  } catch (error) {
    console.error(error);
  } finally {
    await mongoose.disconnect();
  }
}

run();
