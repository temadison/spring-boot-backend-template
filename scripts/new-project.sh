#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  ./scripts/new-project.sh --config <config.json|config.yaml|config.yml> --output <output-dir> [--force]
USAGE
}

CONFIG_FILE=""
OUTPUT_DIR=""
FORCE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$CONFIG_FILE" || -z "$OUTPUT_DIR" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_EXT="${CONFIG_FILE##*.}"
get_cfg() {
  local key="$1"
  case "$CONFIG_EXT" in
    json)
      jq -r ".${key} // empty" "$CONFIG_FILE"
      ;;
    yml|yaml)
      yq -r ".${key} // empty" "$CONFIG_FILE"
      ;;
    *)
      echo "Unsupported config extension: .$CONFIG_EXT" >&2
      exit 1
      ;;
  esac
}

command -v rsync >/dev/null || { echo "Missing required command: rsync" >&2; exit 1; }
command -v rg >/dev/null || { echo "Missing required command: rg" >&2; exit 1; }
command -v ruby >/dev/null || { echo "Missing required command: ruby" >&2; exit 1; }
if [[ "$CONFIG_EXT" == "json" ]]; then
  command -v jq >/dev/null || { echo "Missing required command: jq" >&2; exit 1; }
else
  command -v yq >/dev/null || { echo "Missing required command: yq" >&2; exit 1; }
fi

DISPLAY_NAME="$(get_cfg 'project.displayName')"
ROOT_PROJECT_NAME="$(get_cfg 'project.rootProjectName')"
MODULE_NAME="$(get_cfg 'project.moduleName')"
ARTIFACT_ID="$(get_cfg 'project.artifactId')"
GROUP_ID="$(get_cfg 'project.groupId')"
VERSION="$(get_cfg 'project.version')"
BASE_PACKAGE="$(get_cfg 'project.basePackage')"
APP_CLASS_NAME="$(get_cfg 'project.appClassName')"
APP_PORT="$(get_cfg 'project.appPort')"
DB_NAME="$(get_cfg 'project.dbName')"
DB_USER="$(get_cfg 'project.dbUser')"
ENV_PREFIX="$(get_cfg 'project.envPrefix')"

: "${DISPLAY_NAME:?Missing project.displayName}"
: "${ROOT_PROJECT_NAME:?Missing project.rootProjectName}"
: "${MODULE_NAME:?Missing project.moduleName}"
: "${ARTIFACT_ID:?Missing project.artifactId}"
: "${GROUP_ID:?Missing project.groupId}"
: "${VERSION:?Missing project.version}"
: "${BASE_PACKAGE:?Missing project.basePackage}"
: "${APP_CLASS_NAME:?Missing project.appClassName}"
: "${APP_PORT:?Missing project.appPort}"
: "${DB_NAME:?Missing project.dbName}"
: "${DB_USER:?Missing project.dbUser}"
: "${ENV_PREFIX:?Missing project.envPrefix}"

if [[ -e "$OUTPUT_DIR" ]]; then
  if [[ "$FORCE" != "true" ]]; then
    echo "Output directory already exists: $OUTPUT_DIR (use --force to replace)" >&2
    exit 1
  fi
  rm -rf "$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

rsync -a \
  --exclude='.git' \
  --exclude='.gradle' \
  --exclude='build' \
  --exclude='**/build' \
  --exclude='.idea' \
  "$TEMPLATE_ROOT"/ "$OUTPUT_DIR"/

replace_all() {
  local old="$1"
  local new="$2"
  [[ "$old" == "$new" ]] && return 0

  local files
  files=$(rg -F -l "$old" "$OUTPUT_DIR" --hidden -g '!.git/*' -g '!**/*.jar' || true)
  if [[ -z "$files" ]]; then
    return 0
  fi

  while IFS= read -r file; do
    OLD="$old" NEW="$new" ruby -pi -e 'gsub(ENV["OLD"], ENV["NEW"])' "$file"
  done <<< "$files"
}

# Baseline values from this template repository
replace_all "Spring Boot Backend Template" "$DISPLAY_NAME Template"
replace_all "stock-dashboard" "$ROOT_PROJECT_NAME"
replace_all "template-backend" "$MODULE_NAME"
replace_all "com.temadison" "$GROUP_ID"
replace_all "1.0-SNAPSHOT" "$VERSION"
replace_all "com.temadison.stockdash.backend" "$BASE_PACKAGE"
replace_all "StockDashboardApplication" "$APP_CLASS_NAME"
replace_all "18090" "$APP_PORT"
replace_all "stockdash" "$DB_NAME"
replace_all "stockdash_app" "$DB_USER"
replace_all "STOCKDASH" "$ENV_PREFIX"
replace_all "Stock Dashboard" "$DISPLAY_NAME"

# Module directory rename if needed
if [[ "$MODULE_NAME" != "template-backend" && -d "$OUTPUT_DIR/template-backend" ]]; then
  mv "$OUTPUT_DIR/template-backend" "$OUTPUT_DIR/$MODULE_NAME"
fi

# Package directory move
OLD_PKG_PATH_MAIN="$OUTPUT_DIR/$MODULE_NAME/src/main/java/com/temadison/stockdash/backend"
OLD_PKG_PATH_TEST="$OUTPUT_DIR/$MODULE_NAME/src/test/java/com/temadison/stockdash/backend"
BASE_PACKAGE_PATH=$(printf %s "$BASE_PACKAGE" | tr "." "/")
NEW_PKG_PATH_MAIN="$OUTPUT_DIR/$MODULE_NAME/src/main/java/$BASE_PACKAGE_PATH"
NEW_PKG_PATH_TEST="$OUTPUT_DIR/$MODULE_NAME/src/test/java/$BASE_PACKAGE_PATH"

if [[ -d "$OLD_PKG_PATH_MAIN" && "$OLD_PKG_PATH_MAIN" != "$NEW_PKG_PATH_MAIN" ]]; then
  mkdir -p "$(dirname "$NEW_PKG_PATH_MAIN")"
  mv "$OLD_PKG_PATH_MAIN" "$NEW_PKG_PATH_MAIN"
fi
if [[ -d "$OLD_PKG_PATH_TEST" && "$OLD_PKG_PATH_TEST" != "$NEW_PKG_PATH_TEST" ]]; then
  mkdir -p "$(dirname "$NEW_PKG_PATH_TEST")"
  mv "$OLD_PKG_PATH_TEST" "$NEW_PKG_PATH_TEST"
fi

# Clean empty package directories left behind
find "$OUTPUT_DIR/$MODULE_NAME/src/main/java" -type d -empty -delete || true
find "$OUTPUT_DIR/$MODULE_NAME/src/test/java" -type d -empty -delete || true

echo "Generated project at: $OUTPUT_DIR"
echo "Next steps:"
echo "  1) cd $OUTPUT_DIR"
echo "  2) ./gradlew :$MODULE_NAME:test :$MODULE_NAME:integrationTest"
echo "  3) docker compose --env-file .env.example up --build -d"
