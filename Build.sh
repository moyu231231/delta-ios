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
# ldid 对某些新版二进制会断言失败，失败则用 codesign 兜底，再不行 TrollStore 安装时兜底
if [ -f entitlements.plist ]; then
  SIGNED=0
  if command -v ldid >/dev/null 2>&1; then
    echo "ldid 重签名..."
    if ldid -S entitlements.plist "$APP_PATH/AIAimbot" 2>&1; then
      echo "✅ ldid 签名成功"
      SIGNED=1
    else
      echo "⚠️ ldid 签名失败，尝试 codesign..."
    fi
  fi
  if [ "$SIGNED" -eq 0 ] && command -v codesign >/dev/null 2>&1; then
    if codesign --force --sign - --entitlements entitlements.plist "$APP_PATH/AIAimbot" 2>&1; then
      echo "✅ codesign 签名成功"
      SIGNED=1
    else
      echo "⚠️ codesign 签名也失败"
    fi
  fi
  if [ "$SIGNED" -eq 0 ]; then
    echo "⚠️ 签名都失败，跳过（TrollStore 安装时会自动签 platform-application）"
  fi
fi

mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -r AIAimbot.ipa Payload/ >/dev/null
rm -rf Payload

echo ""
echo "=== 完成：AIAimbot.ipa ==="
ls -lh AIAimbot.ipa
