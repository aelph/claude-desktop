# claude-desktop

PKGBUILD для Arch/Manjaro: официальный Claude Desktop, переупакованный из
deb-пакета Anthropic без пересборки. Пакет локальный, в AUR не публикуется.

## Что делает PKGBUILD

- Берёт `.deb` из официального APT-репозитория
  `https://downloads.claude.ai/claude-desktop/apt/stable` и копирует его `/usr`
  как есть: приложение со встроенным Electron в `/usr/lib/claude-desktop`,
  `/usr/bin/claude-desktop`, ярлык и иконки.
- Зависимости Debian переведены на имена пакетов Arch.
- Из действий `postinst` оставлена только регистрация поиска GNOME Shell.
  Подключение APT-репозитория и профиль AppArmor в Arch не нужны.
- С `chrome-sandbox` снят бит SUID: ядра Arch/Manjaro разрешают
  непривилегированные пространства имён, и Chromium изолирует процессы через них.

## Установка

```
makepkg -si
```

## Обновление

Приложение на Linux само не обновляется. Всё делает `./update.sh`:

- `./update.sh check` — сравнить установленную версию с индексом
  APT-репозитория. Код возврата 10 — доступно обновление.
- `./update.sh` — если вышла новая версия: правит `pkgver` и контрольную сумму
  (берётся из индекса репозитория, `updpkgsums` не нужен), `makepkg -f`,
  коммит `Update <версия>`, установка через `sudo pacman -U`.
- `./update.sh rollback [версия]` — откат на ранее собранный локальный пакет.
  Собранные `.pkg.tar.zst` намеренно остаются в каталоге.
- `./update.sh notify` — тихая проверка с уведомлением через `notify-send`; при
  недоступности сети завершается молча.

### Уведомления о новых версиях

Ежедневная проверка в 12:00 со случайной задержкой до часа — systemd-таймер пользователя. Юниты создаются в
`~/.config/systemd/user/`; команды выполнять из каталога репозитория, чтобы
`$PWD` указывал на него:

```
mkdir -p ~/.config/systemd/user

printf '%s\n' '[Unit]' 'Description=Проверка обновлений Claude Desktop' '' \
  '[Service]' 'Type=oneshot' "ExecStart=$PWD/update.sh notify" \
  > ~/.config/systemd/user/claude-desktop-update-check.service

printf '%s\n' '[Unit]' 'Description=Ежедневная проверка обновлений Claude Desktop' '' \
  '[Timer]' 'OnCalendar=*-*-* 12:00:00' 'Persistent=true' 'RandomizedDelaySec=1h' '' \
  '[Install]' 'WantedBy=timers.target' \
  > ~/.config/systemd/user/claude-desktop-update-check.timer

systemctl --user daemon-reload
systemctl --user enable --now claude-desktop-update-check.timer
```

## Cowork

Вкладка Cowork выполняет длительные задачи в виртуальной машине QEMU/KVM.
Для неё нужны необязательные зависимости пакета (`qemu-system-x86`,
`edk2-ovmf`), членство пользователя в группе `kvm` и модуль ядра
`vhost_vsock`. Остальные функции приложения работают и без этого.
