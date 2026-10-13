# Иконка приложения «Гвинт»

Макет принят в проекте: `/mnt/project-files/gwent/design/11-app-icon.html` (вариант A: красный камень-жизнь в латунной
оправе на карточной рубашке). Рисунок собран из токенов дизайн-системы (`bg #14110E`, `gold #C8A35B`, `brass #8C6A3F`,
`lifeGem #B3261E`) и не копирует ассеты CD Projekt RED. Текста в иконке нет, название приложения задают платформы.

## Слои

Все слои 1024×1024, SVG из макета, PNG получены из SVG без правок.

| Файл | Куда идёт |
|---|---|
| `app_icon_ios.*` | мастер iOS: непрозрачный, без скруглений, знак крупнее, чем в Android (в 1,45 раза) для читаемости на 29–40 px. Заодно значок Android до 8.0 |
| `app_icon_foreground.*` | передний план адаптивной иконки Android; весь рисунок внутри круга 66/108 холста (безопасная зона) |
| `app_icon_background.*` | фон адаптивной иконки Android, без знака |
| `app_icon_monochrome.*` | силуэт для тематических иконок Android 13+ |

## Как это попадает в приложение

`tools/scripts/setup.sh` раскладывает готовые PNG: Android делает `flutter_launcher_icons` по
`flutter_launcher_icons.yaml` в корне (результат в `android/app/src/main/res/`), для iOS мастер копируется в
`ios/Runner/Assets.xcassets/AppIcon.appiconset/` (один размер 1024×1024, Xcode 14+ нарезает остальные сам). Результат
коммитится.

Менять иконку так: поправить SVG, запустить `node tools/app_icon/render.mjs` (нужны Node и Playwright с Chromium, в
проект они не входят), затем `tools/scripts/setup.sh` и закоммитить SVG, PNG и сгенерированные файлы.

## Название

Отображаемое имя «Гвинт»: `android/app/src/main/res/values/strings.xml` (`app_name`) и `CFBundleDisplayName` /
`CFBundleName` в `ios/Runner/Info.plist`. Идентификаторы пакета (`applicationId`, bundle id) не менялись.
