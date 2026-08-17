# AI 自瞄（三角洲行动 iOS）—— 纯视觉方案，不碰游戏内存

## 为什么不被封

AI 自瞄走**纯视觉**：截屏 → 识别敌人 → 模拟手指滑动瞄准。全程在系统层操作，
**不读游戏内存、不注入游戏进程、不 hook、不拿 task port**。
tersafe 的所有检测点（task_get_special_port / vm_read / proc_regionfilename / inline_hook）全部失效。

## 文件清单

| 文件 | 职责 |
|---|---|
| `触摸注入.h/.mm` | 跨进程 IOHIDEvent 触摸注入（模拟手指滑动，注入前台游戏） |
| `屏幕捕获.h/.mm` | 截屏（`_UICreateScreenUIImage` 私有 API，root 无提示） |
| `目标识别.h/.mm` | Vision/CoreML 识别敌人（内置 Vision 或自定义 YOLO 模型） |
| `自瞄引擎.h/.mm` | 主循环：截屏→识别→选目标→算偏移→滑动瞄准 |
| `悬浮球.h/.mm` | 悬浮开关（点击开关自瞄，长按退出） |
| `main.mm` | 入口 |
| `Info.plist` | 打包配置 |

## 编译（GitHub Actions macOS）

把这整个目录推到 GitHub 仓库，用 macos runner 编译：

```yaml
- name: Build
  run: |
    xcodebuild -project AIAimbot.xcodeproj \
      -scheme AIAimbot \
      -configuration Release \
      -sdk iphoneos \
      -destination 'generic/platform=iOS' \
      CODE_SIGNING_ALLOWED=NO \
      build
```

> ⚠️ 目前只有源码文件，`.xcodeproj` 工程文件需要你本地 Xcode 新建一个 App 工程，
> 把这 8 个源文件拖进去（或我后续生成 pbxproj）。也可以复用你 `translate.xcodeproj` 的结构。

## 签名 + 打包（巨魔 TrollStore）

```bash
# 1. 重签名（把 task_for_pid-allow 等权限写进二进制）
ldid -S entitlements.plist AI自瞄.app/AI自瞄

# 2. 打包 ipa
zip -r AI自瞄.ipa Payload/
```

用 TrollStore 安装 ipa。

## 真机校准（关键！）

**唯一需要调的就是「灵敏度 sensitivity」**，在 `main.mm` 里：

1. 进游戏训练场，开悬浮球
2. 站一个敌人，准星故意偏一点
3. 观察：准星有没有朝敌人移动？
   - **移动过头**（甩过敌人）→ 调小 sensitivity（如 0.5）
   - **移动不够**（差一截）→ 调大 sensitivity（如 2.0）
4. 反复调到"一次瞄准基本套住敌人"

其他参数：
- `fovRadius`（400）：太远的敌人不瞄，防止误瞄
- `aimAtHead`（YES）：锁头；NO 锁胸
- `smoothness`（0.6）：越小越平滑，越大越猛
- `minConfidence`（0.4）：低于这个置信度的识别结果忽略

## ✅ 三角洲公益模型（已下载，头身分离，锁头准）

已经帮你找到并下载了**三角洲行动的公益 YOLO 模型**，就在 `模型/` 目录：

| 文件 | 说明 |
|---|---|
| `模型/best.pt` | PyTorch 权重（6MB，转 CoreML 用） |
| `模型/best.onnx` | ONNX 格式（12MB，备用） |

**模型来源**：GitHub 开源项目 `advent259141/YOLO_DeltaForce`（AimMaster），
YOLOv8n（最小模型，640 输入，A15 NPU 无压力），**头身分离标注**：
- `cls 0 = body`（身体框，检测敌人位置）
- `cls 1 = head`（头部框，精确锁头）

自瞄时 `aimAtHead=YES` 会**优先锁头部框**，这正是"锁码"要的效果。

### 转 CoreML（PC 上跑一次）

```bash
pip install ultralytics coremltools
python convert_to_coreml.py
```

生成 `模型/best.mlmodel`（带 NMS，iOS 直接出检测框）。

> 代码已自动集成：`best.mlmodel` 存在就用它（头身分离锁头），
> 不存在则回退内置 Vision（识别人，精度一般）。

## 提升识别精度（可选：自己训练）

如果公益模型在你的设备/画质下识别不准，可以自己训练：
- 用 `QQ767172261` 的三角洲数据集（GitHub 搜"三角洲行动 数据集 YOLOv8"）
- 或标注自己的截图，用 `ultralytics` 训练后转 CoreML

## 屏幕捕获说明

- 优先 `_UICreateScreenUIImage`（root 无提示，纯巨魔可用）
- 若截到的不是游戏画面（黑屏/只截到本 App），改用 ReplayKit 录屏方案：
  在 `屏幕捕获.mm` 里替换为 `RPScreenRecorder` 的 `startCaptureWithHandler`，
  会有系统录屏红点提示，但能稳定截到游戏画面。

## ⚠️ 诚实提醒

1. **只能自瞄，不能透视**——墙后敌人看不到（视觉识别只看屏幕）。
2. **识别延迟**——截屏 + 识别 + 注入有几十 ms 延迟，高速移动目标可能跟不上。
3. **屏幕捕获在纯巨魔环境有不确定性**——`_UICreateScreenUIImage` 可能被系统限制，
   若失败需改用 ReplayKit（有提示）。

## 风险

纯视觉方案不碰游戏内存，理论上 tersafe 检测不到。但腾讯可能有**服务器端行为检测**
（命中率异常、瞄准轨迹过于机械等）。建议：
- `smoothness` 别调太小（太准会被行为检测）
- 加入随机抖动（人体工学），让瞄准轨迹像真人
- 不要长时间 100% 锁头命中
