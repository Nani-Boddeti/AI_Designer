# ─────────────────────────────────────────────
# Flutter
# ─────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─────────────────────────────────────────────
# Firebase — Core, Crashlytics, Messaging
# ─────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Crashlytics — keep stack-trace metadata
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.crashlytics.** { *; }
-dontwarn com.crashlytics.**

# ─────────────────────────────────────────────
# Supabase / Realtime (OkHttp + Ktor WebSocket)
# ─────────────────────────────────────────────
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# ─────────────────────────────────────────────
# Razorpay
# ─────────────────────────────────────────────
-keep class com.razorpay.** { *; }
-keep interface com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ProGuard rules for Proguard plus
-optimizations !method/inlining/*
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# ─────────────────────────────────────────────
# Hive (reflection-based adapters)
# ─────────────────────────────────────────────
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class hive.** { *; }

# ─────────────────────────────────────────────
# Geolocator
# ─────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─────────────────────────────────────────────
# Permission Handler
# ─────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ─────────────────────────────────────────────
# Image Picker / Compress
# ─────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ─────────────────────────────────────────────
# Share Plus
# ─────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# ─────────────────────────────────────────────
# Package Info Plus
# ─────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# ─────────────────────────────────────────────
# URL Launcher
# ─────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ─────────────────────────────────────────────
# In-App Review
# ─────────────────────────────────────────────
-keep class com.google.android.play.core.review.** { *; }
-dontwarn com.google.android.play.core.**

# ─────────────────────────────────────────────
# General Android / Java
# ─────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*,EnclosingMethod
-keep class androidx.** { *; }
-dontwarn androidx.**

# Keep enums intact (used in platform channels)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
