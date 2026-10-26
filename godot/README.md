# NEON RUN — Godot 4 порт (v2.0.0)

Игра переписана с Canvas 2D на **Godot 4.7.2** (GL Compatibility). Отрисовка осталась
процедурной через `_draw()`, внешний вид и физика сверены с оригиналом 1:1.

Старая веб-версия (`/index.html`, `/hero.js`, `/assets/`) лежит в корне репозитория и не
тронута — это референс до «флипа» релиза.

## Структура

```
godot/
  project.godot          — настройки (480×800, portrait, GL Compatibility)
  scenes/main.tscn       — единственная сцена
  scripts/
    game.gd              — состояние, физика, спавн, HUD, меню, бот/автотесты
    pen.gd               — canvas-подобная обёртка над CanvasItem (стек трансформаций)
    palette.gd           — 10 палитр, HAZARD, медали, константы
    hero.gd              — модель героя (порт hero.js, IK-конечности)
    obstacles.gd         — 15 препятствий
    backgrounds.gd       — 10 процедурных фонов
    store.gd             — рекорды/медали/настройки (user://)
    sfx.gd               — SFX генерируются в рантайме (AudioStreamWAV)
    music.gd             — 10 треков .ogg, по одному на уровень
  assets/music/          — ogg + CREDITS.md
  assets/fonts/          — DejaVu Sans / Bold / Mono (кириллица)
  web/                   — готовая web-сборка (коммитится для GitHub Pages)
  export_presets.cfg     — пресеты Web и Android (без секретов)
```

## Локальный запуск

```bash
godot --path godot
```

В WSL с GUI:

```bash
DISPLAY=:0 XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir \
PULSE_SERVER=/mnt/wslg/PulseServer \
godot --path godot --rendering-driver opengl3
```

## Сборка

Требуется Godot 4.7.2 + export templates, JDK 17, Android SDK (build-tools 34+).

### Web

```bash
cd godot
godot --headless --path . --export-release "Web" web/index.html
python3 ../scripts/patch-web.py
```

Экспорт генерирует `web/index.html` заново и сбрасывает часть настроек пулов,
поэтому сразу после него нужен `scripts/patch-web.py`: он возвращает
`GODOT_CONFIG` (`emscriptenPoolSize`, `godotPoolSize`, `fileSizes` по фактическим
размерам файлов) и копирует артефакты `web/` в корень репозитория. Скрипт
идемпотентен, умеет `--check`.

Сборка однопоточная (`thread_support=false`) — COOP/COEP-заголовки не нужны.
Результат: `godot/web/` — 50.6 МБ на диске (`index.wasm` 39.5 МБ + `index.pck`
10.8 МБ с музыкой), по сети с gzip около 20.7 МБ.

### Android APK

```bash
cd godot
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/neon-run-release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=neonrun
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...   # из вашего хранилища секретов
export JAVA_HOME=/path/to/jdk17
godot --headless --path . --export-release "Android" build/android/neon-run-2.0.0.apk
```

Release-keystore в репозиторий не входит: путь задаётся через
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, пароль — через
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Подпись RSA 4096, срок 30 лет.

## Отладка и визуальная сверка

```bash
# скриншот кадра (без GUI)
godot --headless --path godot -- --shot=/tmp/x.png --frames=30 --auto=menu

# режимы: menu, menu_board, menu_howto, play, dead, pause, lvl2/lvl5/lvl9, bot
# уровень:  --level=N (1..10)
# бот-ран:  godot --headless --path godot -- --auto=bot --turbo=900000
```

Бот должен стабильно проходить 3 000–10 000 м (проверка физики/баланса).

## Релиз 2.0.0 — важное для пользователей

- Это **новая нативная сборка** на Godot: подпись и `versionCode` новые (20000).
  Перед установкой APK нужно **удалить старую версию** — иначе Android откажет
  в обновлении из-за другой подписи.
- Локальные рекорды, медали и настройки **не переносятся**: у старой версии данные в
  `localStorage` WebView, у Godot — в `user://`. После первого запуска таблица рекордов пустая.
- Пакет: `dev.marshall.neonrun`, minSdk 24, targetSdk 36, arm64-v8a, портрет.
- Разрешений не запрашивает (INTERNET в манифест не добавлен).
