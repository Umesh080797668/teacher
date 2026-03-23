const fs = require('fs');
let code = fs.readFileSync('backend/server.js', 'utf8');

code = code.replace(
  /const newVideo = new LmsVideo\(\{\s*title,\s*description,\s*videoUrl,\s*thumbnailUrl,\s*classId,\s*teacherId: teacher\._id,\s*uploadDate: new Date\(\)\s*\}\);/,
  "const newVideo = new LmsVideo({\n        title,\n        description,\n        videoUrl,\n        thumbnailUrl,\n        classId,\n        teacherId: teacher._id,\n        allowDownload: allowDownload || false,\n        relatedQuizUrl,\n        relatedMaterialUrl,\n        createdAt: new Date()\n      });"
);

fs.writeFileSync('backend/server.js', code);
console.log('Fixed app.post save fields');
