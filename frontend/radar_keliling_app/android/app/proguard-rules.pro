# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Pusher Channels
-keep class com.pusher.** { *; }
-dontwarn com.pusher.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# OkHttp (used by Dio/Pusher)
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**

# Keep all classes with @Keep annotation
-keep @androidx.annotation.Keep class * { *; }
