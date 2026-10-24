# Ohara — R8 keep rules for the release build.
#
# Shrinking is on (see build.gradle.kts). Flutter's own engine classes are kept
# by the rules the Flutter Gradle plugin contributes; what follows is for this
# app's plugins, which reach code by reflection or over a platform channel and
# so are invisible to the shrinker's call graph.

# The Flutter embedding, reached from native code by name.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ExoPlayer / media3, behind video_player and just_audio. A blanket
# `-keep class androidx.media3.** { *; }` used to sit here; it exempted the
# whole of media3 — several megabytes of dex, most of it codecs and formats
# this app never plays — from shrinking. Media3 ships its own consumer rules
# for exactly the classes it loads reflectively by name (extension renderers,
# extractors, data sources), so those survive R8 without help.
#
# Verify after changing this: a release build must open a reel and play a
# voice note.
-dontwarn androidx.media3.**

# flutter_secure_storage keeps the session token in a keystore-backed
# preference file; its cipher provider is looked up by name.
-keep class androidx.security.crypto.** { *; }

# Conscrypt / OkHttp are optional dependencies of the HTTP stack. Neither is
# on the classpath, and the warnings are noise rather than a missing type.
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Keep the annotations R8 uses to decide what else to keep.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Line numbers survive so a Play Console stack trace can be read back against
# the mapping file. Source file names are still stripped.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
