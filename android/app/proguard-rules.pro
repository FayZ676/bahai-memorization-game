-keep class ai.onnxruntime.** { *; }
-keepclassmembers class com.faizififita.verses.logic.** {
    *** Companion;
}
-keepclasseswithmembers class com.faizififita.verses.logic.** {
    kotlinx.serialization.KSerializer serializer(...);
}
