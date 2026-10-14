#!/usr/bin/env bash
#
# bump_version.sh — поднимает версию и билд приложения.
#
# Схема по умолчанию: build +1 и patch +1 за каждое обновление
#   3.0 (build 31) → 3.0.1 (build 32)
#
# Меняет:
#   • KnowerManager.xcodeproj/project.pbxproj  (MARKETING_VERSION, CURRENT_PROJECT_VERSION)
#   • CHANGELOG.md                             (строка «Версия приложения: **X** (build N)»)
#
# Использование:
#   scripts/bump_version.sh                 # build +1, patch +1
#   scripts/bump_version.sh --build-only    # только build +1
#   scripts/bump_version.sh --minor         # build +1, минор +1 (3.0.1 → 3.1)
#   scripts/bump_version.sh --major         # build +1, мажор +1 (3.1 → 4.0)
#   scripts/bump_version.sh --set 3.2.1     # явная версия + build +1
#   scripts/bump_version.sh --quiet         # без вывода сводки
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBX="$ROOT/KnowerManager.xcodeproj/project.pbxproj"
CHANGELOG="$ROOT/CHANGELOG.md"

mode="patch"
explicit=""
quiet=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only) mode="build"; shift ;;
    --minor)      mode="minor"; shift ;;
    --major)      mode="major"; shift ;;
    --set)        explicit="${2:-}"; mode="set"; shift 2 ;;
    --quiet)      quiet=1; shift ;;
    -h|--help)    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "bump_version: неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$PBX" ]] || { echo "bump_version: не найден $PBX" >&2; exit 1; }

# --- Текущие значения -------------------------------------------------------
cur_build="$(awk -F'= ' '/CURRENT_PROJECT_VERSION/ { gsub(/;/,"",$2); print $2; exit }' "$PBX")"
cur_ver="$(awk -F'= ' '/MARKETING_VERSION/ { gsub(/;/,"",$2); gsub(/[[:space:]]/,"",$2); print $2; exit }' "$PBX")"

[[ "$cur_build" =~ ^[0-9]+$ ]] || { echo "bump_version: не удалось прочитать CURRENT_PROJECT_VERSION" >&2; exit 1; }
[[ -n "$cur_ver" ]] || { echo "bump_version: не удалось прочитать MARKETING_VERSION" >&2; exit 1; }

IFS='.' read -r -a parts <<< "$cur_ver"
maj="${parts[0]:-0}"; min="${parts[1]:-0}"; pat="${parts[2]:-0}"

# --- Новая версия -----------------------------------------------------------
case "$mode" in
  build) : ;;
  patch) if [[ ${#parts[@]} -ge 3 ]]; then pat=$((pat + 1)); else parts=("$maj" "$min" "1"); maj="${parts[0]}"; min="${parts[1]}"; pat="${parts[2]}"; fi ;;
  minor) min=$((min + 1)); pat=0 ;;
  major) maj=$((maj + 1)); min=0; pat=0 ;;
  set)
    [[ "$explicit" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || { echo "bump_version: некорректная версия '$explicit'" >&2; exit 2; }
    IFS='.' read -r -a parts <<< "$explicit"
    maj="${parts[0]:-0}"; min="${parts[1]:-0}"; pat="${parts[2]:-0}"
    ;;
esac

# Формат: минор/мажор оставляют 2 компонента (3.1, 4.0), патч добавляет третий (3.0.1).
if [[ "$mode" == "minor" || "$mode" == "major" ]]; then
  new_ver="$maj.$min"
else
  new_ver="$maj.$min.$pat"
fi
new_build=$((cur_build + 1))

# --- Применение -------------------------------------------------------------
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${new_build};/g" "$PBX"
sed -i '' -E "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = ${new_ver};/g" "$PBX"

if [[ -f "$CHANGELOG" ]] && grep -q 'Версия приложения:' "$CHANGELOG"; then
  sed -i '' -E "s/(Версия приложения: \*\*)[0-9.]+(\*\* \(build )[0-9]+(\))/\1${new_ver}\2${new_build}\3/" "$CHANGELOG"
fi

if [[ $quiet -eq 0 ]]; then
  echo "Версия: ${cur_ver} (build ${cur_build}) → ${new_ver} (build ${new_build})"
fi
