# Changelog

## [v2.0.0] — 2026-10-26

### Added
- Godot 4.7.2 порт игры: процедурная отрисовка 1:1, 10 уровней, 15 препятствий,
  меню, пауза, таблица рекордов, медали, звук и музыка.
- Web-сборка Godot в `godot/web/` (доступна по `/godot/` на GitHub Pages).
- Экспорт Android APK: `dev.marshall.neonrun`, versionCode 20000, arm64-v8a.

### Changed
- Движок: Canvas 2D → Godot 4 (GL Compatibility).
- SFX генерируются в рантайме (`AudioStreamWAV`), музыка — 10 треков `.ogg`.
- Подпись APK: новый release-keystore (RSA 4096, 30 лет) вместо debug-ключа.

### Notes
- **Перед установкой APK 2.0.0 удалите версию 1.x**: подпись и versionCode новые,
  Android не даст обновить поверх.
- Рекорды и медали не переносятся — другая песочница (`user://` вместо `localStorage`).
