const fs = require('fs');

const path = '/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance/backend/server.js';
let content = fs.readFileSync(path, 'utf8');

const multerConfig = `
// Configure multer for Video uploads
const videoUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 150 * 1024 * 1024, // 150MB limit for videos
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('video/') || file.mimetype.includes('mp4')) {
      cb(null, true);
    } else {
      cb(new Error('Only video files are allowed!'), false);
    }
  }
});
`;

if (!content.includes('videoUpload = multer')) {
  content = content.replace('// Configure multer for Resource uploads', multerConfig + '\n// Configure multer for Resource uploads');
}

const endpoint = `

// Upload LMS Video directly to Cloudinary
app.post('/api/lms/upload/video', verifyToken, videoUpload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'File is required' });

    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder: 'lms-videos',
        resource_type: 'video',
      },
      (error, result) => {
        if (error) {
          console.error('Cloudinary upload error:', error);
          return res.status(500).json({ error: error.message });
        }
        res.status(200).json({ url: result.secure_url });
      }
    );
    
    uploadStream.end(req.file.buffer);
  } catch (error) {
    console.error('Video upload error:', error);
    res.status(500).json({ error: 'Failed to upload video' });
  }
});
`;

if (!content.includes('/api/lms/upload/video')) {
  content = content.replace("app.post('/api/lms/videos', verifyToken, async (req, res) => {", endpoint + "\napp.post('/api/lms/videos', verifyToken, async (req, res) => {");
}

fs.writeFileSync(path, content);
console.log('Backend patched!');
