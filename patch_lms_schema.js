const fs = require('fs');
let code = fs.readFileSync('backend/server.js', 'utf8');

// Update schema
code = code.replace(
  "sizeBytes: Number,",
  "sizeBytes: Number,\n  allowDownload: { type: Boolean, default: false },\n  relatedQuizUrl: String,\n  relatedMaterialUrl: String,"
);

// Update POST endpoint
const postRegex = /const { \n\s*title, \n\s*description, \n\s*videoUrl, \n\s*thumbnailUrl, \n\s*classId, \n\s*teacherId \n\s*} = req\.body;/;
code = code.replace(
  postRegex,
  "const { \n        title, \n        description, \n        videoUrl, \n        thumbnailUrl, \n        classId, \n        teacherId,\n        allowDownload,\n        relatedQuizUrl,\n        relatedMaterialUrl\n      } = req.body;"
);

code = code.replace(
  "classId,\n        teacherId: teacher._id",
  "classId,\n        teacherId: teacher._id,\n        allowDownload: allowDownload || false,\n        relatedQuizUrl,\n        relatedMaterialUrl"
);

// Update PUT endpoint
code = code.replace(
  "const { title, description, videoUrl, classId } = req.body;",
  "const { title, description, videoUrl, classId, allowDownload, relatedQuizUrl, relatedMaterialUrl } = req.body;"
);

code = code.replace(
  "{ title, description, videoUrl, classId },",
  "{ title, description, videoUrl, classId, allowDownload, relatedQuizUrl, relatedMaterialUrl },"
);

fs.writeFileSync('backend/server.js', code);
console.log('Schema and endpoints patched correctly.');
