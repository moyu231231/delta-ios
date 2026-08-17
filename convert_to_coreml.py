# convert_to_coreml.py —— 把三角洲公益模型 best.pt 转成 iOS CoreML (.mlmodel)
#
# 用法（CI 或 PC 上跑一次）：
#   pip install ultralytics coremltools
#   python convert_to_coreml.py
#
# 输出：模型/best.mlmodel（旧版单文件，iOS 直接加载 + xcodegen 好打包）
# 注意：coremltools 9.0 默认导出 .mlpackage（目录），这里再转成 .mlmodel 单文件
import coremltools as ct
from ultralytics import YOLO

MODEL_PT = "模型/best.pt"      # 已下载好的三角洲公益模型（v6）
IMGSZ = 640                     # 模型输入尺寸（训练时就是 640）

def main():
    model = YOLO(MODEL_PT)

    # 打印类别名（确认 head/body）
    print("=" * 50)
    print("模型类别名 names:", model.names)
    print("类别数:", len(model.names))
    print("=" * 50)

    # 导出 CoreML（nms=True 带非极大值抑制，iOS 直接拿到最终检测框）
    path = model.export(format="coreml", nms=True, imgsz=IMGSZ)
    print("✅ CoreML 导出成功:", path)

    # coremltools 9.0 导出的是 .mlpackage（目录），尽量转成 .mlmodel（单文件，好打包）
    spath = str(path)
    if spath.endswith(".mlpackage"):
        try:
            ml = ct.models.MLModel(spath)
            mlmodel_path = spath.replace(".mlpackage", ".mlmodel")
            ml.save(mlmodel_path)
            print("✅ 已转换为单文件:", mlmodel_path)
            # 删除 .mlpackage 目录，避免 xcodegen 把它当 group 打散
            import shutil
            shutil.rmtree(spath)
            print("✅ 已删除临时 .mlpackage 目录")
        except Exception as e:
            # coremltools 9.0 若已移除 .mlmodel 写入，则保留 .mlpackage（iOS 代码已兜底支持）
            print(f"⚠️ .mlmodel 保存失败（{e}），保留 .mlpackage，iOS 侧将直接加载 .mlpackage")
    else:
        print("✅ 已是 .mlmodel 单文件，无需转换")

if __name__ == "__main__":
    main()
