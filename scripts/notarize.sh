#!/bin/bash
#
# GroTask macOS 公证脚本
#
# 用法:
#   ./scripts/notarize.sh
#
# 环境变量 (可通过 .env 文件或命令行设置):
#   APPLE_ID          - Apple ID 邮箱
#   TEAM_ID           - 开发者团队 ID
#   APP_PASSWORD      - App 专用密码 (appleid.apple.com 生成)
#
# 前提条件:
#   1. 已安装 Developer ID Application 证书到钥匙串
#   2. 已在 Apple Developer 后台创建 Developer ID Provisioning Profile
#      - App ID: com.grotask.app (启用 iCloud + Push Notifications)
#      - 关联正确的 Developer ID Application 证书
#      - 下载后安装到 ~/Library/MobileDevice/Provisioning Profiles/<UUID>.provisionprofile
#   3. entitlements 文件包含 com.apple.application-identifier 和 com.apple.developer.team-identifier
#

set -euo pipefail

# ---- 配置 ----
SCHEME="GroTask"
CONFIGURATION="Release"
SIGNING_IDENTITY="Developer ID Application: Chao Wu (4KT56S2BX6)"
PROFILE_NAME="GroTask Developer ID"
BUNDLE_ID="com.grotask.app"
TEAM_ID="${TEAM_ID:-4KT56S2BX6}"
APPLE_ID="${APPLE_ID:-jimwuemail@gmail.com}"
APP_PASSWORD="${APP_PASSWORD:-}"
KEYCHAIN_PROFILE="GroTask-Notarize"

BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/GroTask.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
ZIP_PATH="${BUILD_DIR}/GroTask.zip"
EXPORT_OPTIONS="ExportOptions.plist"

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---- 检查前提条件 ----
check_prerequisites() {
    info "检查前提条件..."

    # 检查签名证书
    if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
        error "未找到签名证书: $SIGNING_IDENTITY"
    fi

    # 检查凭证: 优先使用 Keychain profile, 其次使用 APP_PASSWORD
    if [ -n "$APP_PASSWORD" ]; then
        info "使用 APP_PASSWORD 环境变量"
        USE_KEYCHAIN=false
    elif xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" 2>/dev/null | head -1 | grep -q .; then
        info "使用 Keychain profile: $KEYCHAIN_PROFILE"
        USE_KEYCHAIN=true
    else
        warn "未找到 Keychain profile '$KEYCHAIN_PROFILE'，请先运行:"
        warn "  xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" --apple-id \"$APPLE_ID\" --team-id \"$TEAM_ID\" --password <APP_PASSWORD>"
        read -rsp "或直接输入 App 专用密码: " APP_PASSWORD
        echo
        USE_KEYCHAIN=false
    fi

    # 检查 ExportOptions.plist
    if [ ! -f "$EXPORT_OPTIONS" ]; then
        warn "未找到 ${EXPORT_OPTIONS}，正在生成..."
        generate_export_options
    fi

    info "前提条件检查通过"
}

# ---- 生成 ExportOptions.plist ----
generate_export_options() {
    cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${PROFILE_NAME}</string>
	</dict>
</dict>
</plist>
EOF
    info "已生成 ${EXPORT_OPTIONS}"
}

# ---- 步骤 1: Archive ----
archive() {
    info "步骤 1/5: Archive..."
    rm -rf "$ARCHIVE_PATH"

    xcodebuild archive \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        ENABLE_HARDENED_RUNTIME=YES \
        OTHER_CODE_SIGN_FLAGS="--options=runtime" \
        | tail -3

    if [ ! -d "$ARCHIVE_PATH" ]; then
        error "Archive 失败"
    fi
    info "Archive 成功"
}

# ---- 步骤 2: 导出 ----
export_archive() {
    info "步骤 2/5: 导出签名后的 App..."
    rm -rf "$EXPORT_PATH"

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        | tail -3

    if [ ! -d "${EXPORT_PATH}/GroTask.app" ]; then
        error "导出失败"
    fi

    # 验证签名
    codesign --verify --deep --strict "${EXPORT_PATH}/GroTask.app"
    info "导出成功，签名验证通过"
}

# ---- 步骤 3: 打包 ----
package() {
    info "步骤 3/5: 打包 zip..."
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "${EXPORT_PATH}/GroTask.app" "$ZIP_PATH"
    info "打包完成: $(du -h "$ZIP_PATH" | cut -f1)"
}

# ---- 步骤 4: 提交公证 ----
notarize() {
    info "步骤 4/5: 提交公证..."

    if [ "$USE_KEYCHAIN" = true ]; then
        xcrun notarytool submit "$ZIP_PATH" \
            --keychain-profile "$KEYCHAIN_PROFILE" \
            --wait
    else
        xcrun notarytool submit "$ZIP_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" \
            --wait
    fi

    # 检查结果
    if [ $? -ne 0 ]; then
        error "公证失败，请检查日志"
    fi
    info "公证通过"
}

# ---- 步骤 5: Staple ----
staple() {
    info "步骤 5/5: Staple 公证票据..."
    xcrun stapler staple "${EXPORT_PATH}/GroTask.app"

    # 最终验证
    spctl -a -v "${EXPORT_PATH}/GroTask.app" 2>&1
    info "Staple 完成，App 已可分发: ${EXPORT_PATH}/GroTask.app"
}

# ---- 主流程 ----
main() {
    echo "========================================"
    echo "  GroTask macOS 公证流程"
    echo "========================================"
    echo

    check_prerequisites
    archive
    export_archive
    package
    notarize
    staple

    echo
    info "全部完成! 公证后的 App 位于: ${EXPORT_PATH}/GroTask.app"
}

main "$@"
