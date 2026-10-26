#!/usr/bin/env python3
"""Вернуть настройки web-сборки NEON RUN после экспорта Godot.

Godot при каждом экспорте генерирует godot/web/index.html заново и сбрасывает
часть GODOT_CONFIG на дефолты (emscriptenPoolSize=8, godotPoolSize=8) плюс
пересчитывает fileSizes. Скрипт возвращает проверенные значения и копирует
готовые артефакты из godot/web/ в корень репозитория (оттуда их раздаёт Pages).

Запуск:
    python3 scripts/patch-web.py            # применить
    python3 scripts/patch-web.py --check    # только показать расхождения

Коды возврата: 0 — ок / уже актуально, 1 — есть расхождения (--check),
2 — ошибка конфигурации.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "godot" / "web"
PRESETS = ROOT / "godot" / "export_presets.cfg"
HTML = WEB / "index.html"

# Проверенные значения. Менять только вместе с проверкой на живой сборке.
TUNED = {
    "canvasResizePolicy": 2,
    "emscriptenPoolSize": 4,
    "ensureCrossOriginIsolationHeaders": False,
    "focusCanvas": True,
    "godotPoolSize": 2,
}

# Файлы, которые раздаёт Pages: godot/web/ -> корень репозитория.
ARTIFACTS = (
    "index.html",
    "index.js",
    "index.wasm",
    "index.pck",
    "index.png",
    "index.icon.png",
    "index.apple-touch-icon.png",
    "index.audio.worklet.js",
    "index.audio.position.worklet.js",
)

CONFIG_RE = re.compile(r"^const GODOT_CONFIG = (\{.*\});$", re.MULTILINE)


def fail(msg: str) -> "NoReturn":
    print(f"ошибка: {msg}", file=sys.stderr)
    sys.exit(2)


def threads_enabled() -> bool:
    try:
        text = PRESETS.read_text(encoding="utf-8")
    except OSError as exc:
        fail(f"не читается {PRESETS}: {exc}")
    return bool(re.search(r"^variant/thread_support=true\s*$", text, re.MULTILINE))


def file_sizes() -> dict[str, int]:
    sizes = {}
    for name in ("index.pck", "index.wasm"):
        path = WEB / name
        if not path.is_file():
            fail(f"нет файла {path} — сначала выполните экспорт")
        sizes[name] = path.stat().st_size
    return sizes


def patched_config(cfg: dict) -> dict:
    cfg = dict(cfg)  # сохраняем исходный порядок ключей
    cfg.update(TUNED)
    cfg["fileSizes"] = file_sizes()
    return cfg


def patch_html(dry_run: bool) -> bool:
    if not HTML.is_file():
        fail(f"нет файла {HTML} — сначала выполните экспорт")

    text = HTML.read_text(encoding="utf-8")
    match = CONFIG_RE.search(text)
    if not match:
        fail("в godot/web/index.html не найдена строка 'const GODOT_CONFIG = {...};'")

    try:
        cfg = json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        fail(f"GODOT_CONFIG не парсится как JSON: {exc}")

    if not TUNED["ensureCrossOriginIsolationHeaders"] and threads_enabled():
        fail(
            "в export_presets.cfg включён variant/thread_support=true, "
            "а COOP/COEP выключать в этом случае нельзя"
        )

    updated = patched_config(cfg)
    line = "const GODOT_CONFIG = " + json.dumps(updated, separators=(",", ":")) + ";"
    new_text = text[: match.start()] + line + text[match.end() :]

    if new_text == text:
        print("godot/web/index.html: уже актуально")
        return False

    if dry_run:
        print("godot/web/index.html: требуется обновление")
        for key, value in TUNED.items():
            if cfg.get(key) != value:
                print(f"  {key}: {cfg.get(key)!r} -> {value!r}")
        if cfg.get("fileSizes") != updated["fileSizes"]:
            print(f"  fileSizes: {cfg.get('fileSizes')} -> {updated['fileSizes']}")
        return True

    HTML.write_text(new_text, encoding="utf-8")
    print("godot/web/index.html: обновлён")
    return True


def sync_artifacts(dry_run: bool) -> list[str]:
    changed = []
    for name in ARTIFACTS:
        src = WEB / name
        dst = ROOT / name
        if not src.is_file():
            print(f"предупреждение: нет {src}, пропускаю", file=sys.stderr)
            continue
        if dst.is_file() and dst.read_bytes() == src.read_bytes():
            continue
        changed.append(name)
        if not dry_run:
            shutil.copy2(src, dst)

    if dry_run:
        for name in changed:
            print(f"  {name}: будет скопирован в корень репозитория")
    else:
        for name in changed:
            print(f"  {name}: скопирован в корень репозитория")

    if not changed:
        print("корень репозитория: уже актуально")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="не менять файлы, только показать расхождения",
    )
    args = parser.parse_args()

    html_changed = patch_html(args.check)
    files_changed = sync_artifacts(args.check)

    if args.check and (html_changed or files_changed):
        print("есть расхождения")
        return 1

    if not html_changed and not files_changed:
        print("всё актуально, менять нечего")
    return 0


if __name__ == "__main__":
    sys.exit(main())
