# flutter_local_notifications, planlanmış bildirimleri Gson ile
# SharedPreferences'a JSON olarak yazıp okuyor. R8/ProGuard kod
# küçültme (minify) sırasında generic tip bilgisini (Signature) ve
# TypeToken alt sınıflarını silerse, uygulama release modunda
# "PlatformException: Missing type parameter" hatasıyla çöküyor
# (bkz. https://github.com/MaikuB/flutter_local_notifications/issues/2265
# ve #2223). Bu kurallar o bilgiyi korur.

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
