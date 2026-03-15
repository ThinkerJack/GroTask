#!/bin/bash
#
# GroTask iOS TestFlight 上传脚本
#
# 用法:
#   ./scripts/testflight.sh
#
# 前提条件:
#   1. 已安装 fastlane (brew install fastlane)
#   2. fastlane 已登录过 App Store Connect (有缓存 session)
#   3. Keychain 中已存储 App 专用密码 (GroTask-Notarize profile)
#

set -euo pipefail

SCHEME="GroTaskiOS"
CONFIGURATION="Release"
TEAM_ID="4KT56S2BX6"
USERNAME="jimwuemail@gmail.com"
APP_SPECIFIC_PASSWORD="fsfl-kraz-oens-febj"

BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/GroTaskiOS.xcarchive"
EXPORT_PATH="${BUILD_DIR}/ios-export"
EXPORT_OPTIONS="ExportOptions-iOS.plist"
IPA_PATH="${EXPORT_PATH}/GroTask.ipa"

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---- 自动递增 build number ----
bump_build_number() {
    local current
    current=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')
    local next=$((current + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION: \"${current}\"/CURRENT_PROJECT_VERSION: \"${next}\"/g" project.yml
    info "Build number: ${current} → ${next}"
    xcodegen generate >/dev/null 2>&1
    info "Xcode 项目已重新生成"
}

# ---- 步骤 1: Archive ----
archive() {
    info "步骤 1/3: Archive..."
    rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

    xcodebuild archive \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination 'generic/platform=iOS' \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        | tail -3

    if [ ! -d "$ARCHIVE_PATH" ]; then
        error "Archive 失败"
    fi
    info "Archive 成功"
}

# ---- 步骤 2: 导出 IPA ----
export_ipa() {
    info "步骤 2/3: 导出 IPA..."

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -allowProvisioningUpdates \
        | tail -3

    if [ ! -f "$IPA_PATH" ]; then
        error "导出失败"
    fi
    info "导出成功: $IPA_PATH"
}

# ---- 步骤 3: 上传 TestFlight ----
upload() {
    info "步骤 3/3: 上传 TestFlight..."

    FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="$APP_SPECIFIC_PASSWORD" \
    fastlane pilot upload \
        --ipa "$IPA_PATH" \
        --username "$USERNAME" \
        --team_id "$TEAM_ID" \
        --skip_waiting_for_build_processing true

    info "上传成功！等待 App Store Connect 处理后即可在 TestFlight 安装"
}

# ---- 主流程 ----
main() {
    echo "========================================"
    echo "  GroTask iOS TestFlight 上传"
    echo "========================================"
    echo

    bump_build_number
    archive
    export_ipa
    upload

    echo
    info "全部完成!"
}

main "$@"
