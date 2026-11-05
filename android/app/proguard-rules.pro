# Flutter Wrapper and Engine rules
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }
-keep class * extends io.flutter.embedding.android.FlutterActivity { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Jetpack Glance and Compose App Widgets
-keep class androidx.glance.** { *; }
-keep class androidx.glance.appwidget.** { *; }
-keep class androidx.compose.** { *; }
-dontwarn androidx.glance.**
-dontwarn androidx.compose.**

# Krivo Native Jetpack Glance Receivers and Composables
-keep class com.personal.couple_app.NoteGlanceWidget** { *; }
-keep class com.personal.couple_app.CoupleGlanceWidget** { *; }
-keep class com.personal.couple_app.DailyPromptGlanceWidget** { *; }
-keep class com.personal.couple_app.TasksGlanceWidget** { *; }

# HomeWidget Plugin for Flutter <-> Native Glance synchronization
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# Flutter Local Notifications Plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Firebase SDKs (Spark Free Tier)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Kotlin Metadata and Coroutines
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# Google Play Core / Deferred Components (unused in standalone release APK)
-dontwarn com.google.android.play.core.**
