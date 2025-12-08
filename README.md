# Teacher Attendance Mobile Backend

A simple Express.js backend for the Teacher Attendance mobile app.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Create a `.env` file with your MongoDB URI:
   ```
   PORT=3001
   MONGODB_URI=mongodb://localhost:27017/teacher_attendance_mobile
   ```

3. Start the server:
   ```bash
   npm run dev  # For development with nodemon
   npm start    # For production
   ```

## API Endpoints

### Students
- `GET /api/students` - Get all students
- `POST /api/students` - Create a new student

### Attendance
- `GET /api/attendance` - Get attendance records (optional query params: studentId, month, year)
- `POST /api/attendance` - Create a new attendance record

## Database

Uses MongoDB with two collections:
- `students`: Student information
- `attendances`: Attendance records