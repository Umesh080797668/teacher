# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Prevent stripping of native methods
-keepclassmembers class * {
    native <methods>;
}

# Keep graphics-related classes
-keep class android.graphics.** { *; }
-keep class android.hardware.** { *; }

# Prevent obfuscation of error messages
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep custom application class
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service

# AndroidX
-dontwarn androidx.**
-keep class androidx.** { *; }
