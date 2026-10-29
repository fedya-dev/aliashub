#!/usr/bin/env bash
# ============================================================================
#  ALIASHUB — инсталатор
#  Автор: Федя Серафиев  ·  https://fedia.eu
#
#  Инсталира:   ~/.local/bin/aliashub
#  Мигрира:     стара инсталация на aliasctl v3.x (бинарен, rc блокове, backup-и)
#  Настройва:   авто-зареждане в ~/.bashrc и ~/.zshrc (чрез aliashub init)
#  Деинсталира: ./install.sh --uninstall   (НЕ пипа твоите алиаси и backup-и)
# ============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SRC="$SCRIPT_DIR/aliashub"
BIN_DIR="${HOME}/.local/bin"
TARGET="$BIN_DIR/aliashub"
OLD_TARGET="$BIN_DIR/aliasctl"
PATH_MARKER="# >>> aliashub PATH >>>"
OLD_PATH_MARKER="# >>> aliasctl PATH >>>"

c_g=$'\033[38;5;82m'; c_y=$'\033[38;5;214m'; c_r=$'\033[38;5;196m'
c_b=$'\033[38;5;81m'; c_d=$'\033[38;5;240m'; c_0=$'\033[0m'

ok()   { printf "%b%s%b\n" "$c_g" "$1" "$c_0"; }
warn() { printf "%b%s%b\n" "$c_y" "$1" "$c_0"; }
err()  { printf "%b%s%b\n" "$c_r" "$1" "$c_0" >&2; }
dim()  { printf "%b%s%b\n" "$c_d" "$1" "$c_0"; }

banner() {
    printf "%b\n" "$c_b"
    echo "  ──────────────────────────────────────────"
    echo "   ALIASHUB — инсталатор  (fedia.eu)"
    echo "  ──────────────────────────────────────────"
    printf "%b\n" "$c_0"
}

ensure_rc_file() { # $1 = път; връща 0 ако файлът съществува/е създаден
    if [ ! -f "$1" ]; then
        case "$1" in
            *.zshrc) command -v zsh >/dev/null 2>&1 || return 0 ;;
        esac
        : > "$1"
        ok "  създаден: $1"
    fi
    return 0
}

path_in_rc() { grep -Fq "$PATH_MARKER" "$1" 2>/dev/null; }

sed_inplace() { # sed_inplace <израз> <файл> — преносимо (GNU и BSD sed)
    local _expr="$1" _file="$2" _tmp
    _tmp="$(mktemp)"
    sed "$_expr" "$_file" > "$_tmp" && mv "$_tmp" "$_file" || { rm -f "$_tmp"; return 1; }
}

upgrade_old_path_marker() { # подменя стари 'aliasctl PATH' маркери с новите
    local _rc="$1"
    [ -f "$_rc" ] || return 0
    grep -Fq "$OLD_PATH_MARKER" "$_rc" 2>/dev/null || return 0
    if sed_inplace 's|# >>> aliasctl PATH >>>|# >>> aliashub PATH >>>|; s|# <<< aliasctl PATH <<<|# <<< aliashub PATH <<<|' "$_rc"; then
        ok "  ✓ Старите PATH маркери в $_rc са обновени до aliashub"
    fi
}

add_path_block() { # добавя ~/.local/bin в PATH на даден rc (идемпотентно)
    local _rc="$1"
    if ! ensure_rc_file "$_rc"; then return 0; fi
    upgrade_old_path_marker "$_rc"
    if path_in_rc "$_rc"; then
        dim "  PATH блокът вече е в $_rc"
        return 0
    fi
    { printf '\n%s\n' "$PATH_MARKER"
      printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "$BIN_DIR" "$BIN_DIR"
      printf '# <<< aliashub PATH <<<\n'
    } >> "$_rc"
    ok "  PATH добавен в $_rc"
}

uninstall() {
    local _removed=0
    if [ -f "$TARGET" ]; then
        rm -f "$TARGET" && ok "Изтрит: $TARGET"
        _removed=1
    else
        dim "Няма инсталиран $TARGET"
    fi
    if [ -f "$OLD_TARGET" ]; then
        rm -f "$OLD_TARGET" && ok "Изтрит и старият: $OLD_TARGET"
        _removed=1
    fi
    [ "$_removed" -eq 0 ] || true
    cat <<EOF

За пълно почистване (по желание, ръчно):
  1. Изтрий блоковете '# >>> aliashub' (или старите '# >>> aliasctl')
     от ~/.bashrc и/или ~/.zshrc
  2. Изтрий реда '# >>> aliashub PATH >>>' от същите файлове
  3. Данните ти са в ~/.fedya_aliases и ~/.config/aliashub/ — изтрий ги само
     ако наистина искаш (алиасите и backup-ите НЕ се пипат от uninstall).
EOF
}

main() {
    if [ "${1:-}" = "--uninstall" ]; then
        banner
        uninstall
        return 0
    fi

    banner

    # 1. проверки
    if [ ! -f "$SRC" ]; then
        err "✗ Не намирам '$SRC'. Пусни install.sh от папката на проекта."
        return 1
    fi
    if ! command -v bash >/dev/null 2>&1; then
        err "✗ Трябва Bash (скриптът е bash). Инсталирай bash и пробвай пак."
        return 1
    fi

    # 2. копиране в ~/.local/bin (+ премахни стария aliasctl, ако има такъв)
    mkdir -p "$BIN_DIR"
    if [ -e "$OLD_TARGET" ]; then
        rm -f "$OLD_TARGET"
        ok "✓ Старият aliasctl е премахнат: $OLD_TARGET"
    fi
    if cp "$SRC" "$TARGET" && chmod +x "$TARGET"; then
        ok "✓ Инсталиран: $TARGET"
    else
        err "✗ Не можах да запиша в $BIN_DIR"
        return 1
    fi

    # 3. миграция на backup-ите от aliasctl v3.x (~/.config/aliasctl → aliashub)
    #    се извършва от самия aliashub при първото му пускане (стъпка 5 init).

    # 4. PATH в rc файловете
    case ":$PATH:" in
        *":$BIN_DIR:"*) dim "· ~/.local/bin вече е в PATH" ;;
        *)
            echo "· ~/.local/bin липсва в PATH — добавям го:"
            for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
                if [ -f "$_rc" ] || [ "${_rc##*.}" = "bashrc" ]; then
                    add_path_block "$_rc"
                fi
            done
            warn "  → нови терминали ще го видят автоматично; текущият: export PATH=\"$BIN_DIR:\$PATH\""
            ;;
    esac

    # 5. авто-зареждане на алиасите (идемпотентно; надгражда стари aliasctl блокове)
    echo "· Настройване на авто-зареждането:"
    "$TARGET" init

    # 6. здравна проверка
    echo
    "$TARGET" doctor || true

    # 7. финал
    cat <<EOF

$(ok '✓ Готово!')
Бърз старт:
  aliashub                        → интерактивното меню
  aliashub add gs 'git status'    → нов алиас
  aliashub add srv 'ssh root@srv' --category server --tags ssh
  aliashub list --tag ssh         → филтър по таг
  aliashub list -g                → групирано по категория
  aliashub lang en                → английски интерфейс (запомня се)
  aliashub help                   → пълна помощ

Съвет: за да влят новите алиаси в текущия терминал — source ~/.fedya_aliases
EOF
}

main "$@"
