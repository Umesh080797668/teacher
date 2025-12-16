// Vercel serverless function to check JWT_SECRET configuration
module.exports = async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const jwtSecret = process.env.JWT_SECRET;
  
  const response = {
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    jwtSecretExists: !!jwtSecret,
    jwtSecretLength: jwtSecret ? jwtSecret.length : 0,
    jwtSecretFirst10: jwtSecret ? jwtSecret.substring(0, 10) + '...' : 'NOT SET',
    jwtSecretLast10: jwtSecret ? '...' + jwtSecret.substring(jwtSecret.length - 10) : 'NOT SET',
    allEnvVars: {
      MONGODB_URI: !!process.env.MONGODB_URI,
      JWT_SECRET: !!process.env.JWT_SECRET,
      EMAIL_USER: !!process.env.EMAIL_USER,
      PORT: process.env.PORT || 'NOT SET',
    }
  };
  
  return res.status(200).json(response);
};
