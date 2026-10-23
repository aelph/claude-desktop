#!/usr/bin/env bash
# Обновление пакета claude-desktop из официального APT-репозитория Anthropic.
#
#   ./update.sh            — pull, проверить, собрать, установить, закоммитить, push
#   ./update.sh check      — только проверить наличие новой версии
#   ./update.sh notify     — тихая проверка с уведомлением на рабочий стол (для systemd-таймера)
#   ./update.sh rollback   — показать локальные сборки для отката
#   ./update.sh rollback <версия> — установить указанную локальную сборку
#
# Код возврата 11 у check и update — новая версия опубликована битой (см. release_ok).

set -euo pipefail
cd "$(dirname "$0")"

INDEX="https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages"
PKGNAME="claude-desktop"

# Защита от битых релизов, общая для update.sh в yandex-music-pkg, max-bin и claude-desktop.
# 20.10.2026 Яндекс опубликовал Яндекс Музыку 5.124.1, чей deb весил 96 байт: в ar-архиве лежал только пустой индекс «__.SYMDEF SORTED», без control.tar и data.tar. Фид указывал именно этот размер и контрольную сумму именно этого файла, поэтому проверка суммы релиз пропустила, а сборка упала на распаковке.
# Настоящие сборки всех трёх программ весят десятки и сотни мегабайт, поэтому размер пакета из метаданных источника сверяется с порогом в 1 МиБ. Релиз меньше порога или без указанного размера считается битым: check и update сообщают о нём и выходят с кодом 11, notify молчит до тех пор, пока издатель не перевыпустит пакет.
MIN_SIZE=$((1024 * 1024))

release_ok() {
    [[ "${1:-}" =~ ^[0-9]+$ ]] && (( $1 >= MIN_SIZE ))
}

broken_release() {
    echo "Версия $1 опубликована битой (размер пакета: ${2:-не указан} байт), обновление пропущено." >&2
    exit 11
}

latest_entry() {
    # Индекс APT: абзацы «Поле: значение», разделённые пустой строкой.
    # Выводит «версия sha256 размер» самой свежей версии пакета.
    curl -fsSL "$INDEX" | awk -v RS= -v FS='\n' '
        {
            p = v = s = z = ""
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^Package: /) p = substr($i, 10)
                else if ($i ~ /^Version: /) v = substr($i, 10)
                else if ($i ~ /^SHA256: /) s = substr($i, 9)
                else if ($i ~ /^Size: /) z = substr($i, 7)
            }
            if (p == "'"$PKGNAME"'" && v != "" && s != "") print v, s, z
        }' | sort -V -k1,1 | tail -1
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
    cur=$(current_version); entry=$(latest_entry)
    read -r new _ size <<<"$entry"
    echo "Установленная версия: $cur"
    echo "Версия в APT-репо:    $new"
    if [[ $(vercmp "$new" "$cur") -gt 0 ]]; then
        release_ok "$size" || broken_release "$new" "$size"
        echo "Доступно обновление. Запустите: ./update.sh"
        exit 10
    else
        echo "Обновление не требуется."
    fi
    ;;

notify)
    # Для systemd-таймера: молча выйти, если сеть так и не появилась,
    # показать уведомление только если вышла новая версия.
    # Persistent=true запускает пропущенную проверку сразу после загрузки,
    # когда сети может ещё не быть: повторять попытки до 5 минут.
    cur=$(current_version)
    entry=""
    for _ in {1..10}; do
        entry=$(latest_entry 2>/dev/null) && [[ -n "$entry" ]] && break
        entry=""
        sleep 30
    done
    [[ -n "$entry" ]] || exit 0
    read -r new _ size <<<"$entry"
    # О битом релизе не уведомляем: обновиться на него всё равно нельзя.
    if [[ $(vercmp "$new" "$cur") -gt 0 ]] && release_ok "$size"; then
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
    read -r new sum size <<<"$entry"
    if [[ -z "$entry" || -z "$sum" ]]; then
        echo "Не удалось прочитать индекс репозитория." >&2
        exit 1
    fi
    if [[ $(vercmp "$new" "$cur") -le 0 ]]; then
        echo "Уже актуальная версия: $cur"
        exit 0
    fi
    release_ok "$size" || broken_release "$new" "$size"
    # Имя .deb в PKGBUILD собирается из pkgver, поэтому версия Debian
    # должна подходить для pkgver без преобразований.
    if [[ ! "$new" =~ ^[0-9][0-9.]*$ ]]; then
        echo "Версия $new не годится для pkgver — нужна ручная правка PKGBUILD." >&2
        exit 1
    fi
    echo "Обновление $cur -> $new"
    # Контрольная сумма берётся из индекса репозитория, updpkgsums не нужен.
    # Если PKGBUILD этой версии уже подтянут с другой машины, pkgrel не трогаем.
    if [[ $(grep -oP '(?<=^pkgver=).*' PKGBUILD) != "$new" ]]; then
        sed -i -e "s/^pkgver=.*/pkgver=$new/" -e "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
    fi
    sed -i "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('$sum')/" PKGBUILD
    makepkg -f
    git add PKGBUILD
    # Если версия уже подтянута с другой машины, коммитить нечего.
    git diff --cached --quiet || git commit -m "Update $new"
    pkgrel=$(grep -oP '(?<=^pkgrel=).*' PKGBUILD)
    sudo pacman -U "${PKGNAME}-${new}-${pkgrel}-x86_64.pkg.tar.zst"
    # Отправить коммит сразу, чтобы другие машины подтянули его, а не создали свой.
    git push -q || echo "Предупреждение: git push не удался, выполните его вручную." >&2
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
