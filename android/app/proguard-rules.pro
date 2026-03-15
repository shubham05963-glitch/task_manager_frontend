# R8/Proguard rules to fix Jackson and OpenTelemetry missing classes
-dontwarn com.fasterxml.jackson.**
-dontwarn io.opentelemetry.**
-dontwarn com.google.auto.value.**

# Fix for Google Play Core missing classes (Flutter Deferred Components)
-dontwarn com.google.android.play.core.**

# Keep Jackson classes if they are being used by reflection
-keep class com.fasterxml.jackson.** { *; }

# Keep OpenTelemetry classes
-keep class io.opentelemetry.** { *; }

# Flutter standard Proguard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
