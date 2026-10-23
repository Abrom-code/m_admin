# Proguard / R8 rules for Android release build

# Google ML Kit Text Recognition
# The google_mlkit_text_recognition plugin references language-specific recognizer
# options (Chinese, Devanagari, Japanese, Korean) in its TextRecognizer implementation.
# Because the application only uses Latin script recognition (TextRecognitionScript.latin),
# these optional language dependencies are intentionally not bundled in dependencies to
# prevent APK bloat (~20-30 MB).
# We suppress R8 warnings for these unused optional language script classes:
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Retain Google ML Kit runtime classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
