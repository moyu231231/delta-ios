#!/bin/sh
PASSWORD="0000"

# GitHub Actions 环境没有 /opt/homebrew/bin/ldid，跳过本地签名打包
# （签名 + ipa 打包已由 workflow 的"签名 + 打包"步骤完成）
if [ ! -x /opt/homebrew/bin/ldid ]; then
    echo "Build.sh: 未找到 /opt/homebrew/bin/ldid，跳过（由 workflow 签名打包）"
    exit 0
fi

set -eo pipefail

echo "📌 目录: $TARGET_BUILD_DIR"

echo "目录 $SRCROOT"
echo "开始处理 Payload 文件夹及应用..."
rm -rf "$TARGET_BUILD_DIR/Payload"
rm -rf "$TARGET_BUILD_DIR/$INFOPLIST_KEY_CFBundleDisplayName.tipa"

echo "创建 Payload 文件夹"
mkdir -p "$TARGET_BUILD_DIR/Payload"

EXE_PATH="$TARGET_BUILD_DIR/$EXECUTABLE_PATH"

echo "对应用签名 $EXE_PATH"
ENT_PATH="$PROJECT_DIR/权限/Entitlements.plist"
/opt/homebrew/bin/ldid -S"$ENT_PATH" "$EXE_PATH"

if [ $? -eq 0 ]; then
    echo "签名成功！"
else
    echo "签名失败！"
    exit 1
fi

echo "删除 PkgInfo 文件"
rm -rf "$CODESIGNING_FOLDER_PATH/PkgInfo"

echo "删除 Entitlements.plist 文件"
rm -rf "$CODESIGNING_FOLDER_PATH/Entitlements.plist"

echo "移动 $CONTENTS_FOLDER_PATH 文件夹"
cp -R "$CODESIGNING_FOLDER_PATH" "$TARGET_BUILD_DIR/Payload/$CONTENTS_FOLDER_PATH"

echo "不清理隐藏文件"

echo "压缩生成 ipa 文件"
cd "$TARGET_BUILD_DIR"
zip -rq "$INFOPLIST_KEY_CFBundleDisplayName.tipa" Payload
rm -rf Payload
cd - > /dev/null

echo "$INFOPLIST_KEY_CFBundleDisplayName.tipa 已生成！"
