# flutter_local_notifications enregistre les rappels programmés avec Gson.
# Sans ces règles, R8 supprime les types génériques en build release et
# zonedSchedule / pendingNotificationRequests échouent ("Missing type parameter").
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
