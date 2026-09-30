# CLAUDE.md

## О репозитории

Локальный PKGBUILD `claude-desktop` для Arch/Manjaro: переупаковка официального
deb-пакета Claude Desktop из APT-репозитория Anthropic
(`https://downloads.claude.ai/claude-desktop/apt/stable`). В AUR не публикуется.

Отслеживаются только `PKGBUILD`, `update.sh`, `README.md`, `CLAUDE.md`,
`.gitignore` — всё остальное игнорируется через whitelist в `.gitignore`.
Собранные пакеты намеренно накапливаются в корне — они нужны для отката.

## Обновление

Всё делает `./update.sh` (см. README.md). Версия и SHA256 берутся из индекса
`dists/stable/main/binary-amd64/Packages`; имя файла в пуле —
`pool/main/c/claude-desktop/claude-desktop_<версия>_amd64.deb`.

## Особенности PKGBUILD

- Пакет бинарный, `options=('!strip' '!debug')`; Electron встроенный.
- Сценарии `postinst`/`postrm` из deb не переносятся целиком: APT-репозиторий
  и AppArmor в Arch не нужны, статически ставятся только файлы поиска GNOME
  Shell из `resources/gnome-search-provider/`.
- `chrome-sandbox` без SUID (изоляция через user namespaces).
- После обновления версии сверять поле `Depends` из `control` нового deb с
  `depends` в PKGBUILD: могут появиться новые зависимости.
