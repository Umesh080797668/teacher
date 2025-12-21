/**
 * Test script to verify MongoDB connection handling
 * This simulates the serverless cold start scenario
 */

const mongoose = require('mongoose');
require('dotenv').config();

let cachedConnection = null;
let connectionPromise = null;

async function connectToDatabase() {
  // If connection is already established and ready, return immediately
  if (cachedConnection && mongoose.connection.readyState === 1) {
    console.log('✓ Using cached database connection');
    return cachedConnection;
  }

  // If a connection is already in progress, wait for it
  if (connectionPromise) {
    console.log('⏳ Connection in progress, waiting...');
    return connectionPromise;
  }

  // Create new connection promise
  connectionPromise = (async () => {
    try {
      const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/teacher_attendance_mobile';
      console.log('🔌 Connecting to MongoDB...');
      console.log('📋 MongoDB URI present:', !!process.env.MONGODB_URI);

      // Retry loop to handle transient network issues on serverless platforms
      const maxAttempts = 3;
      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          console.log(`🔄 MongoDB connect attempt ${attempt}/${maxAttempts}`);
          
          // Connect to MongoDB
          await mongoose.connect(mongoUri, {
            serverSelectionTimeoutMS: 60000,
            connectTimeoutMS: 45000,
            socketTimeoutMS: 60000,
            maxPoolSize: 5,
            minPoolSize: 0,
            family: 4,
            bufferCommands: false,
          });

          // Wait for connection to be fully ready
          if (mongoose.connection.readyState !== 1) {
            console.log('⏳ Waiting for connection to be ready...');
            await new Promise((resolve, reject) => {
              const timeout = setTimeout(() => {
                reject(new Error('Connection ready timeout'));
              }, 10000);
              
              mongoose.connection.once('connected', () => {
                clearTimeout(timeout);
                resolve();
              });
              
              // If already connected, resolve immediately
              if (mongoose.connection.readyState === 1) {
                clearTimeout(timeout);
                resolve();
              }
            });
          }

          cachedConnection = mongoose.connection;
          console.log('✅ MongoDB connected successfully, readyState:', mongoose.connection.readyState);
          return cachedConnection;
        } catch (error) {
          console.error(`❌ MongoDB connection error on attempt ${attempt}:`, error.message);
          if (error.reason) {
            console.error('Topology reason:', error.reason);
          }
          if (attempt < maxAttempts) {
            const backoff = Math.pow(2, attempt) * 1000;
            console.log(`⏰ Retrying MongoDB connection in ${backoff}ms...`);
            await new Promise(res => setTimeout(res, backoff));
          } else {
            console.error('💥 All MongoDB connection attempts failed');
            throw error;
          }
        }
      }
    } finally {
      connectionPromise = null;
    }
  })();

  return connectionPromise;
}

// Define a simple schema for testing
const TestSchema = new mongoose.Schema({
  name: String,
  timestamp: { type: Date, default: Date.now }
});

const TestModel = mongoose.model('Test', TestSchema);

async function runTests() {
  console.log('\n🧪 Starting MongoDB Connection Tests...\n');
  
  try {
    // Test 1: Initial connection
    console.log('📋 Test 1: Initial Connection');
    await connectToDatabase();
    console.log('✅ Test 1 Passed: Initial connection successful\n');
    
    // Test 2: Query with connection established
    console.log('📋 Test 2: Query with Established Connection');
    if (mongoose.connection.readyState !== 1) {
      throw new Error('Connection not ready!');
    }
    const result = await TestModel.findOne({});
    console.log('✅ Test 2 Passed: Query executed successfully (found:', result ? 'document' : 'no document', ')\n');
    
    // Test 3: Cached connection
    console.log('📋 Test 3: Cached Connection');
    await connectToDatabase();
    console.log('✅ Test 3 Passed: Cached connection returned\n');
    
    // Test 4: Disconnect and reconnect
    console.log('📋 Test 4: Disconnect and Reconnect');
    await mongoose.disconnect();
    cachedConnection = null;
    console.log('🔌 Disconnected from MongoDB');
    await connectToDatabase();
    console.log('✅ Test 4 Passed: Reconnection successful\n');
    
    // Test 5: Multiple concurrent connection attempts
    console.log('📋 Test 5: Concurrent Connection Attempts');
    await mongoose.disconnect();
    cachedConnection = null;
    const promises = [
      connectToDatabase(),
      connectToDatabase(),
      connectToDatabase()
    ];
    await Promise.all(promises);
    console.log('✅ Test 5 Passed: Concurrent connections handled correctly\n');
    
    console.log('🎉 All tests passed!\n');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('👋 Disconnected from MongoDB');
    process.exit(0);
  }
}

// Run the tests
runTests();
