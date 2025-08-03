# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep ExoPlayer classes
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Keep Media3 classes (newer ExoPlayer)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Keep video player plugin classes
-keep class io.flutter.plugins.videoplayer.** { *; }
-dontwarn io.flutter.plugins.videoplayer.**

# Keep all classes needed for network video playback
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep MediaPlayer related classes
-keep class android.media.** { *; }
-dontwarn android.media.**