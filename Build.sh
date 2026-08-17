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

echo "=== 2. 转 CoreML 模型（best.pt → best.mlmodel，已转则跳过）==="
if [ ! -f "模型/best.mlmodel" ]; then
  python3 -m pip install --quiet --upgrade ultralytics coremltools 2>/dev/null \
    || python -m pip install --quiet --upgrade ultralytics coremltools
  python3 convert_to_coreml.py || python convert_to_coreml.py
else
  echo "best.mlmodel 已存在，跳过转换"
fi

echo "=== 3. 生成 Xcode 工程 ==="
xcodegen generate

echo "=== 4. 编译 ==="
xcodebuild -project AIAimbot.xcodeproj \
  -scheme AIAimbot \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  build

echo "=== 5. 打包 ipa ==="
APP_PATH="build/Release-iphoneos/AIAimbot.app"
if [ ! -d "$APP_PATH" ]; then
  echo "错误：找不到 $APP_PATH"
  exit 1
fi

# 重签名（写进 platform-application / no-sandbox 等权限）
if command -v ldid >/dev/null 2>&1 && [ -f entitlements.plist ]; then
  echo "ldid 重签名..."
  ldid -S entitlements.plist "$APP_PATH/AIAimbot"
fi

mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -r AIAimbot.ipa Payload/ >/dev/null
rm -rf Payload

echo ""
echo "=== 完成：AIAimbot.ipa ==="
ls -lh AIAimbot.ipa
