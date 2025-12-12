package com.example.teacher_attendance;

import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Enable hardware acceleration explicitly
        getWindow().setFlags(
            android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        );
    }

    @Override
    public void onTrimMemory(int level) {
        super.onTrimMemory(level);
        
        // Handle memory pressure to prevent graphics buffer issues
        if (level >= TRIM_MEMORY_RUNNING_LOW) {
            System.gc();
        }
    }
}
