# Страховочные правила R8 на случай, если минификация когда-нибудь будет включена
# повторно (gradle-свойство shrink=true или отключение строки isMinifyEnabled = false
# в android/app/build.gradle.kts).
#
# Причина: плагины на Pigeon KT-FFI/JNI (например, shared_preferences) ищут свои
# методы через JNI по ТОЧНОЙ строке: имя класса + JVM-дескриптор метода.
# R8 переименовывает типы внутри дескрипторов (kotlin.coroutines.Continuation -> x0.d),
# поэтому поиск метода падает с NoSuchMethodError, Dart-Future не завершается,
# инициализация в main() зависает — приложение не рисует первый кадр (чёрный экран).

# Классы плагина shared_preferences целиком (имена классов и членов не трогаем).
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Типы, встречающиеся в JNI-дескрипторах suspend-методов этих плагинов.
-keepnames class kotlin.coroutines.Continuation
-keepnames class kotlin.coroutines.CoroutineContext
-keepnames class kotlin.coroutines.CoroutineContext$Key
-keepnames class kotlinx.coroutines.CancellableContinuation
