#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
derived_data="$project_dir/.derivedData"
build_app="$derived_data/Build/Products/Release/Sound Mix.app"
install_dir="${SOUNDMIX_INSTALL_DIR:-/Applications}"
installed_app="$install_dir/Sound Mix.app"
staged_app="$install_dir/.Sound Mix.installing.$$.app"

if pgrep -f -x "$installed_app/Contents/MacOS/Sound Mix" > /dev/null; then
    echo "Encerre o Sound Mix pelo botão Sair na barra de menus antes de atualizar." >&2
    exit 1
fi

if ! command -v xcodegen > /dev/null; then
    echo "XcodeGen não encontrado. Instale com 'brew install xcodegen' e tente novamente." >&2
    exit 1
fi

(cd "$project_dir" && xcodegen generate --spec project.yaml)

xcodebuild -quiet \
    -project "$project_dir/soundMix-app.xcodeproj" \
    -scheme soundMix-app \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    build

codesign --verify --deep --strict "$build_app"
ditto "$build_app" "$staged_app"
codesign --verify --deep --strict "$staged_app"

if [[ -e "$installed_app" ]]; then
    backup_dir="$derived_data/install-backups"
    mkdir -p "$backup_dir"
    backup_app="$backup_dir/Sound Mix.$(date +%Y%m%d-%H%M%S).app"
    mv "$installed_app" "$backup_app"
fi

if ! mv "$staged_app" "$installed_app"; then
    if [[ -n "${backup_app:-}" ]]; then
        mv "$backup_app" "$installed_app"
    fi
    exit 1
fi

echo "Sound Mix atualizado em: $installed_app"
