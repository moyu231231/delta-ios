import SwiftUI
import UIKit

@objc public protocol ModernUIDelegate: AnyObject {
    func onToggleDraw(isOn: Bool)
    func onToggleAimbot(isOn: Bool)
    func onDeploy()
}

class UIViewModel: ObservableObject {
    @Published var drawEnabled: Bool
    @Published var aimbotEnabled: Bool

    weak var delegate: ModernUIDelegate?

    init(dict: [String: Any], delegate: ModernUIDelegate) {
        self.drawEnabled = dict["drawEnabled"] as? Bool ?? false
        self.aimbotEnabled = dict["aimbotEnabled"] as? Bool ?? true
        self.delegate = delegate
    }
}

struct PremiumBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea()

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                Circle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: width, height: width)
                    .blur(radius: 100)
                    .offset(x: -width/4, y: height/4)
                    .rotationEffect(.degrees(phase))

                Circle()
                    .fill(LinearGradient(colors: [Color.cyan.opacity(0.5), Color.blue.opacity(0.2)], startPoint: .bottomLeading, endPoint: .topTrailing))
                    .frame(width: width * 1.2, height: width * 1.2)
                    .blur(radius: 120)
                    .offset(x: width/3, y: -height/6)
                    .rotationEffect(.degrees(-phase * 0.8))
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.black.opacity(0.2))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}

struct SettingsIcon: View {
    let icon: String
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String; let color: Color; let title: String
    @Binding var isOn: Bool
    let action: (Bool) -> Void
    let impact = UISelectionFeedbackGenerator()

    var body: some View {
        HStack(spacing: 16) {
            SettingsIcon(icon: icon, color: color)
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    impact.selectionChanged()
                    isOn = newValue
                    action(newValue)
                }
            ))
            .labelsHidden()
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct MainControlView: View {
    @StateObject var viewModel: UIViewModel

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {

                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                        }

                        Text("ZERO 核心引擎")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 10)

                    Button(action: {
                        viewModel.delegate?.onDeploy()
                    }) {
                        Text("一键部署环境")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("功能").font(.system(size: 13, weight: .regular)).foregroundColor(.white.opacity(0.5)).padding(.leading, 32)
                        SettingsGroup {
                            SettingsToggleRow(icon: "eye.fill", color: .green, title: "绘制总开关", isOn: $viewModel.drawEnabled) {
                                viewModel.delegate?.onToggleDraw(isOn: $0)
                            }
                            SettingsToggleRow(icon: "scope", color: .orange, title: "自瞄开关", isOn: $viewModel.aimbotEnabled) {
                                viewModel.delegate?.onToggleAimbot(isOn: $0)
                            }
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}

@objc public class ModernUIBridge: NSObject {
    @objc public static func createControlCenter(dict: [String: Any], delegate: ModernUIDelegate) -> UIViewController {
        let vm = UIViewModel(dict: dict, delegate: delegate)
        let host = UIHostingController(rootView: MainControlView(viewModel: vm))
        host.view.backgroundColor = .clear
        return host
    }
}
