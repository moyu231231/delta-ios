# convert_to_coreml.py —— 把三角洲公益模型 best.pt 转成 iOS CoreML (.mlmodel)
#
# 用法（PC 上跑一次即可）：
#   pip install ultralytics coremltools
#   python convert_to_coreml.py
#
# 输出：模型/best.mlmodel（带 NMS 后处理，iOS VNCoreMLRequest 直接出检测框）
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

    # 导出 CoreML（nms=True 表示带非极大值抑制，iOS 直接拿到最终检测框）
    path = model.export(format="coreml", nms=True, imgsz=IMGSZ)
    print("✅ CoreML 导出成功:", path)

    # 导出 ONNX（备用，某些版本 coreml 导出有兼容性问题时改用 onnx→coreml）
    try:
        onnx_path = model.export(format="onnx", nms=True, imgsz=IMGSZ)
        print("✅ ONNX 导出成功（备用）:", onnx_path)
    except Exception as e:
        print("⚠️ ONNX 导出跳过:", e)

if __name__ == "__main__":
    main()
