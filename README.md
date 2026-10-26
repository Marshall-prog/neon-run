# NEON RUN

Неоновый раннер: прыгай через препятствия, собирай монеты, ставь рекорды.
10 уровней — у каждого свой фон, палитра и трек.

**Играть в браузере:** https://marshall-prog.github.io/neon-run/

## Управление

**Телефон**
- тап — прыжок, повторный тап в воздухе — двойной прыжок
- свайп вниз — присед / быстрое падение
- кнопка ⏸ — пауза

**Компьютер**
- `↑` / `пробел` — прыжок (повторно — двойной)
- `↓` — присед
- `Esc` — пауза

Музыка и звук включаются и выключаются отдельно, выбор сохраняется.

## Android

APK — в [Releases](https://github.com/Marshall-prog/neon-run/releases).
Версии 2.x подписаны новым ключом: перед установкой удалите версию 1.x,
рекорды и настройки из неё не переносятся.

## Устройство репозитория

```
index.html, index.js, index.wasm,
index.pck, index.png ...   — готовая web-сборка, её отдаёт GitHub Pages
scripts/patch-web.py       — пост-экспортный патчер web-сборки
godot/                     — исходники Godot 4.7.2 (сцены, скрипты, ассеты)
```

Движок — Godot 4.7.2 (GL Compatibility), вся графика рисуется кодом: ни одного
спрайта. Сборка Web и Android описана в [`godot/README.md`](godot/README.md).

Pre-push проверка (web-сборка + Godot-проект):

```bash
cp scripts/hooks/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

Версия 1.x была на Canvas 2D; её код остался в истории git (до коммита `83a5f1e`).

## Лицензия

Код — MIT, см. [LICENSE](LICENSE). Музыка — CC0/PD, авторы в
[`godot/assets/music/CREDITS.txt`](godot/assets/music/CREDITS.txt).
