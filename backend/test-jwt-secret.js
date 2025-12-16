// Test JWT Secret Configuration
require('dotenv').config();

console.log('=== JWT SECRET CONFIGURATION TEST ===\n');

const jwtSecret = process.env.JWT_SECRET;

if (!jwtSecret) {
  console.log('❌ JWT_SECRET is NOT set in environment variables!');
  console.log('This will cause token signature mismatches.');
  console.log('\nPlease ensure JWT_SECRET is set in:');
  console.log('1. Local: .env file');
  console.log('2. Vercel: Environment Variables in dashboard');
} else {
  console.log('✓ JWT_SECRET is set');
  console.log('Length:', jwtSecret.length);
  console.log('First 10 characters:', jwtSecret.substring(0, 10) + '...');
  console.log('Last 10 characters:', '...' + jwtSecret.substring(jwtSecret.length - 10));
  
  // Test token generation and verification
  const jwt = require('jsonwebtoken');
  
  console.log('\n=== Testing Token Generation & Verification ===\n');
  
  const testPayload = {
    userId: 'test-user-123',
    email: 'test@example.com',
    userType: 'teacher'
  };
  
  try {
    // Generate token
    const token = jwt.sign(testPayload, jwtSecret, { expiresIn: '24h' });
    console.log('✓ Token generated successfully');
    console.log('Token (first 50 chars):', token.substring(0, 50) + '...');
    
    // Verify token
    const decoded = jwt.verify(token, jwtSecret);
    console.log('✓ Token verified successfully');
    console.log('Decoded payload:', decoded);
    
    console.log('\n✅ JWT configuration is working correctly!');
  } catch (error) {
    console.log('❌ Error with JWT:', error.message);
  }
}

console.log('\n=== All Environment Variables ===\n');
console.log('MONGODB_URI:', process.env.MONGODB_URI ? 'SET' : 'NOT SET');
console.log('JWT_SECRET:', process.env.JWT_SECRET ? 'SET' : 'NOT SET');
console.log('EMAIL_USER:', process.env.EMAIL_USER ? 'SET' : 'NOT SET');
console.log('PORT:', process.env.PORT || 'NOT SET');
