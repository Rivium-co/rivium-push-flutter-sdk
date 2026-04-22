# Keep RiviumPush classes and fields for JSON serialization
-keep class co.rivium.push.flutter.** { *; }
-keepclassmembers class co.rivium.push.flutter.** { *; }

# Keep native Rivium Push SDK classes (compiled from source into this plugin)
-keep class co.rivium.push.sdk.** { *; }
-keepclassmembers class co.rivium.push.sdk.** { *; }

# Keep PN Protocol classes
-keep class co.rivium.protocol.** { *; }

# Keep Gson and its reflection-based serialization
-keepattributes *Annotation*
-keepattributes Signature
-keep class com.google.gson.** { *; }

# Keep all model classes with @SerializedName
-keep class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep MQTT classes (Paho uses reflection for SSL and callbacks)
-keep class org.eclipse.paho.** { *; }
-keepclassmembers class org.eclipse.paho.** { *; }
-dontwarn org.eclipse.paho.**

# Keep OkHttp
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
