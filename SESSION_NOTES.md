# Заметки по восстановлению проекта (2026-08-19)

## Что было не так
В корне репозитория оказался вложен отдельный, полноценный нативный Android-проект
(`app/`, `build.gradle.kts`, `settings.gradle.kts`, `gradlew` и т.д. прямо в корне) —
похоже, Android Studio когда-то была открыта не на той папке. Это ломало и git-историю,
и Gradle-сборку, и конфигурацию IDE.

## Что исправлено (закоммичено, коммит `fc2a561`, запушено в `origin/master`)
- Удалён весь дублирующий Android-проект в корне (`app/`, корневые `build.gradle*`,
  `settings.gradle*`, `gradle/`, `gradlew(.bat)`, `local.properties`).
- `.gitignore` дополнен: `android/build/`, `android/app/build/`, `.gradle/`,
  `.gradle_home/`, `local.properties`.
- `android/build.gradle.kts` — восстановлено стандартное перенаправление build-директории
  Flutter (`rootProject.layout.buildDirectory...`), без него Flutter CLI не находил
  собранный APK.
- `android/app/build.gradle.kts` — `compileSdk` поднят до `37` (требование
  `flutter_secure_storage`), иначе падал `checkDebugAarMetadata`.
- `flutter analyze` — чисто, `flutter test` — проходит, `flutter build apk --debug` —
  собирается.

## Локальные (не в git) правки IDE-конфига
`.idea/` в git не попадает, поэтому эти правки нужно помнить — при переклонировании
репозитория на новой машине эта же проблема может повториться:
- `.idea/gradle.xml`: `externalProjectPath` был `$PROJECT_DIR$` (корень репо) —
  переставлен на `$PROJECT_DIR$/android` (реальный Gradle-проект).
- `.idea/misc.xml`: убран `<component name="ProjectType"><option name="id" value="Android" /></component>` —
  он заставлял Android Studio считать весь проект чистым Android-проектом и скрывал
  Flutter-конфигурацию запуска (`main.dart`).

## Проблема с push
Локальный git не мог проверить SSL-сертификат GitHub из-за перехвата HTTPS антивирусом
AVG. Решение (уже применено пользователем):
```
git config --global http.sslBackend schannel
```

## Текущий статус запуска в Android Studio
После правки `.idea/misc.xml` нужно:
1. `File → Invalidate Caches / Restart → Invalidate and Restart`.
2. Дождаться индексации и Gradle sync.
3. В выпадающем списке конфигураций выбрать **`main.dart`** (зелёная иконка Flutter),
   а не `zairo_android`.
4. Выбрать устройство (эмулятор `sdk gphone16k x86 64` или Windows/Chrome) и нажать Run.

**Подтверждено пользователем 2026-08-19 04:05**: конфигурация `main.dart` появилась,
приложение успешно запущено на эмуляторе Pixel 9 Pro (`com.zairo/.MainActivity`).
Проект полностью рабочий.

## На заметку
`android/app/google-services.json` присутствует, но в `pubspec.yaml` нет Firebase-зависимостей
и плагин `google-services` нигде не подключён — файл сейчас ни на что не влияет.
Если Firebase не планируется — можно удалить.
