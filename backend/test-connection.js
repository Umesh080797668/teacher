const mongoose = require('mongoose');
require('dotenv').config();

console.log('🧪 Testing MongoDB connection with local .env...');
console.log('URI present:', !!process.env.MONGODB_URI);
console.log('URI length:', process.env.MONGODB_URI ? process.env.MONGODB_URI.length : 0);

if (!process.env.MONGODB_URI) {
  console.log('❌ No MONGODB_URI found in .env');
  process.exit(1);
}

mongoose.connect(process.env.MONGODB_URI, {
  serverSelectionTimeoutMS: 5000
})
  .then(() => {
    console.log('✅ SUCCESS: Connected to MongoDB');
    console.log('Database:', mongoose.connection.db.databaseName);
    console.log('Host:', mongoose.connection.host);
    return mongoose.disconnect();
  })
  .catch(err => {
    console.log('❌ FAILED: MongoDB connection error');
    console.log('Error message:', err.message);
    console.log('Error code:', err.code);
    console.log('Error codeName:', err.codeName);
  });