#!/bin/bash
# Build.sh —— 一键编译 AI 自瞄 ipa（含自动转 CoreML 模型）
# 流程：装依赖 → 转模型(best.pt→best.mlmodel) → 生成工程 → 编译 → 打包 ipa
set -e

echo "=== 1. 安装依赖 ==="
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
if ! command -v ldid >/dev/null 2>&1; then
  brew install ldid || true
fi

echo "=== 2. 转 CoreML 模型（best.pt → best.mlpackage，已转则跳过）==="
if [ ! -d "模型/best.mlpackage" ]; then
  # 安装 ultralytics + coremltools（转模型用）
  python3 -m pip install --quiet --upgrade "ultralytics" "coremltools" 2>/dev/null \
    || python -m pip install --quiet --upgrade "ultralytics" "coremltools"
  python3 convert_to_coreml.py || python convert_to_coreml.py
else
  echo "best.mlpackage 已存在，跳过转换"
fi

echo "=== 3. 生成 Xcode 工程 ==="
xcodegen generate
# 修复 objectVersion：xcodegen 2.45.4 生成 77（Xcode16 格式），Xcode 15.4 打不开，改成 60
sed -i '' 's/objectVersion = 77/objectVersion = 60/g' AIAimbot.xcodeproj/project.pbxproj
echo "objectVersion 已修正为 60"

echo "=== 4. 编译 ==="
xcodebuild -project AIAimbot.xcodeproj \
  -scheme AIAimbot \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  build

echo "=== 5. 打包 ipa ==="
APP_PATH="build/Build/Products/Release-iphoneos/AIAimbot.app"
if [ ! -d "$APP_PATH" ]; then
  echo "错误：找不到 $APP_PATH"
  exit 1
fi

# 重签名（把 no-sandbox / platform-application 写进二进制，TrollStore 才能脱离沙盒注入触摸）
# 注意：旧版 ldid 对 Xcode 15 的 chained fixups 会断言崩（已用 -no_chained_fixups 规避），
#       万一还失败就不中断打包，TrollStore 安装时仍会自动签 platform-application。
if command -v ldid >/dev/null 2>&1 && [ -f entitlements.plist ]; then
  echo "ldid 重签名..."
  ldid -S entitlements.plist "$APP_PATH/AIAimbot" 2>&1 || echo "⚠️ ldid 重签名失败，跳过（TrollStore 安装时会自动签名）"
fi

mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -r AIAimbot.ipa Payload/ >/dev/null
rm -rf Payload

echo ""
echo "=== 完成：AIAimbot.ipa ==="
ls -lh AIAimbot.ipa
