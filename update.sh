#!/usr/bin/env bash
# Обновление пакета claude-desktop из официального APT-репозитория Anthropic.
#
#   ./update.sh            — pull, проверить, собрать, установить, закоммитить, push
#   ./update.sh check      — только проверить наличие новой версии
#   ./update.sh notify     — тихая проверка с уведомлением на рабочий стол (для systemd-таймера)
#   ./update.sh rollback   — показать локальные сборки для отката
#   ./update.sh rollback <версия> — установить указанную локальную сборку

set -euo pipefail
cd "$(dirname "$0")"

INDEX="https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages"
PKGNAME="claude-desktop"

latest_entry() {
    # Индекс APT: абзацы «Поле: значение», разделённые пустой строкой.
    # Выводит «версия sha256» самой свежей версии пакета.
    curl -fsSL "$INDEX" | awk -v RS= -v FS='\n' '
        {
            p = v = s = ""
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^Package: /) p = substr($i, 10)
                else if ($i ~ /^Version: /) v = substr($i, 10)
                else if ($i ~ /^SHA256: /) s = substr($i, 9)
            }
            if (p == "'"$PKGNAME"'" && v != "" && s != "") print v, s
        }' | sort -V -k1,1 | tail -1
}

latest_version() {
    local e
    e=$(latest_entry) || return 1
    printf '%s\n' "${e%% *}"
}

current_version() {
    # Истина — установленная версия; если пакет не установлен, берём PKGBUILD.
    local q
    if q=$(pacman -Q "$PKGNAME" 2>/dev/null); then
        printf '%s\n' "$q" | awk '{sub(/-[0-9]+$/,"",$2); print $2}'
    else
        grep -oP '(?<=^pkgver=).*' PKGBUILD
    fi
}

cmd="${1:-update}"

case "$cmd" in
check)
    cur=$(current_version); new=$(latest_version)
    echo "Установленная версия: $cur"
    echo "Версия в APT-репо:    $new"
    if [[ $(vercmp "$new" "$cur") -gt 0 ]]; then
        echo "Доступно обновление. Запустите: ./update.sh"
        exit 10
    else
        echo "Обновление не требуется."
    fi
    ;;

notify)
    # Для systemd-таймера: молча выйти при недоступности сети,
    # показать уведомление только если вышла новая версия.
    cur=$(current_version)
    new=$(latest_version 2>/dev/null) || exit 0
    [[ -n "$new" ]] || exit 0
    if [[ $(vercmp "$new" "$cur") -gt 0 ]]; then
        notify-send -a "Claude" -i claude-desktop -u critical \
            "Вышло обновление Claude Desktop $new" \
            "Установлена версия $cur. Для обновления запустите: $(pwd)/update.sh"
    fi
    ;;

update)
    # Сначала забрать изменения с другой машины: при расхождении
    # истории скрипт остановится, слияние — вручную.
    git pull --ff-only
    cur=$(current_version)
    entry=$(latest_entry) || true
    new=${entry%% *}; sum=${entry##* }
    if [[ -z "$entry" || "$new" == "$sum" ]]; then
        echo "Не удалось прочитать индекс репозитория." >&2
        exit 1
    fi
    if [[ $(vercmp "$new" "$cur") -le 0 ]]; then
        echo "Уже актуальная версия: $cur"
        exit 0
    fi
    # Имя .deb в PKGBUILD собирается из pkgver, поэтому версия Debian
    # должна подходить для pkgver без преобразований.
    if [[ ! "$new" =~ ^[0-9][0-9.]*$ ]]; then
        echo "Версия $new не годится для pkgver — нужна ручная правка PKGBUILD." >&2
        exit 1
    fi
    echo "Обновление $cur -> $new"
    # Контрольная сумма берётся из индекса репозитория, updpkgsums не нужен.
    sed -i -e "s/^pkgver=.*/pkgver=$new/" \
           -e "s/^pkgrel=.*/pkgrel=1/" \
           -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('$sum')/" PKGBUILD
    makepkg -f
    git add PKGBUILD
    git commit -m "Update $new"
    sudo pacman -U "${PKGNAME}-${new}-1-x86_64.pkg.tar.zst"
    git push
    echo "Готово: установлена версия $new."
    ;;

rollback)
    ver="${2:-}"
    if [[ -z "$ver" ]]; then
        echo "Локально доступные сборки:"
        ls -1 "${PKGNAME}"-*.pkg.tar.zst 2>/dev/null \
            | sed -E "s/^${PKGNAME}-(.+)-[0-9]+-x86_64.*/  \1/" \
            || echo "  (нет собранных пакетов)"
        echo
        echo "Откат: ./update.sh rollback <версия>"
        exit 0
    fi
    pkgfile=$(ls -1 "${PKGNAME}-${ver}"-*-x86_64.pkg.tar.zst 2>/dev/null | sort -V | tail -1) || true
    if [[ -z "${pkgfile:-}" ]]; then
        echo "Сборка версии $ver не найдена." >&2
        exit 1
    fi
    sudo pacman -U "$pkgfile"
    ;;

*)
    echo "Использование: $0 [check|notify|update|rollback [версия]]" >&2
    exit 2
    ;;
esac
