window.faceApiLoaded = false;
window.initFaceApi = async function() {
  if (window.faceApiLoaded) return;

  try {
    // Force CPU backend directly to avoid WebGL initialization crashes on unsupported devices.
    await faceapi.tf.setBackend('cpu');
    try {
        await faceapi.tf.ready();
    } catch (e) {
        console.warn("tf.ready() logged an error but continuing:", e);
    }
  } catch (e) {
    console.warn("Failed to configure tensorflow cpu backend, proceeding anyway:", e);
  }

  try {
    const modelPath = 'models/face-api';
    console.log("Loading face-api models from " + modelPath + "...");
    await faceapi.nets.tinyFaceDetector.loadFromUri(modelPath);
    await faceapi.nets.faceLandmark68Net.loadFromUri(modelPath);
    await faceapi.nets.faceRecognitionNet.loadFromUri(modelPath);
    window.faceApiLoaded = true;
    console.log("face-api.js models loaded successfully.");
  } catch (e) {
    console.error("Error loading face-api models from 'models/face-api':", e);
  }
}

window.detectFace = async function(videoElementId) {
  if (!window.faceApiLoaded) return null;
  
  const videoEl = document.getElementById(videoElementId);
  if (!videoEl) return null;

  try {
    const detection = await faceapi.detectSingleFace(videoEl, new faceapi.TinyFaceDetectorOptions())
      .withFaceLandmarks()
      .withFaceDescriptor();
    
    if (!detection) return null;
    return Array.from(detection.descriptor);
  } catch (e) {
    // console.error(e);
    return null;
  }
}
