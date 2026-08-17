# convert_to_coreml.py —— 把三角洲公益模型 best.pt 转成 iOS CoreML (.mlpackage)
#
# 用法（CI 或 PC 上跑一次）：
#   pip install ultralytics coremltools
#   python convert_to_coreml.py
#
# 输出：模型/best.mlpackage（ML Program 格式，iOS 15+ 直接加载）
# 说明：CoreML 的 ML Program 类型只支持 .mlpackage（目录），不支持旧 .mlmodel（单文件），
#       iOS 15+ 原生支持 .mlpackage，VNCoreMLModel 直接加载。
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
    # 输出 .mlpackage（ML Program 格式，目录）
    path = model.export(format="coreml", nms=True, imgsz=IMGSZ)
    print("✅ CoreML 导出成功:", path)

if __name__ == "__main__":
    main()
