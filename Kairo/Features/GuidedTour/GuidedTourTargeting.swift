import SwiftUI
import UIKit

struct GuidedTourAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [GuidedTourTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [GuidedTourTarget: Anchor<CGRect>],
        nextValue: () -> [GuidedTourTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func guidedTourTarget(_ target: GuidedTourTarget) -> some View {
        anchorPreference(key: GuidedTourAnchorPreferenceKey.self, value: .bounds) {
            [target: $0]
        }
    }
}

nonisolated enum GuidedTourTargetResolver {
    static func frame(
        for target: GuidedTourTarget,
        homeFrames: [GuidedTourTarget: CGRect],
        tabFrames: [GuidedTourTarget: CGRect]
    ) -> CGRect? {
        switch target {
        case .trustScore, .passport:
            homeFrames[target]
        case .career, .verify, .more:
            tabFrames[target]
        }
    }
}

struct GuidedTourTabFrameReader: UIViewRepresentable {
    let onFramesChange: ([GuidedTourTarget: CGRect]) -> Void

    func makeUIView(context: Context) -> GuidedTourTabReaderView {
        GuidedTourTabReaderView(onFramesChange: onFramesChange)
    }

    func updateUIView(_ uiView: GuidedTourTabReaderView, context: Context) {
        uiView.onFramesChange = onFramesChange
        uiView.scheduleReport()
    }
}

final class GuidedTourTabReaderView: UIView {
    var onFramesChange: ([GuidedTourTarget: CGRect]) -> Void
    private var lastFrames: [GuidedTourTarget: CGRect] = [:]

    init(onFramesChange: @escaping ([GuidedTourTarget: CGRect]) -> Void) {
        self.onFramesChange = onFramesChange
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleReport()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleReport()
    }

    func scheduleReport() {
        DispatchQueue.main.async { [weak self] in
            self?.reportFrames()
        }
    }

    private func reportFrames() {
        guard let tabBar = findTabBarController(from: window?.rootViewController)?.tabBar,
              tabBar.bounds.width > 0,
              tabBar.bounds.height > 0 else {
            return
        }

        let tabBarFrame = tabBar.convert(tabBar.bounds, to: self)
        let slotWidth = tabBarFrame.width / CGFloat(CandidateTab.allCases.count)
        let mappings: [(GuidedTourTarget, CandidateTab)] = [
            (.career, .career),
            (.verify, .verify),
            (.more, .more)
        ]
        var frames: [GuidedTourTarget: CGRect] = [:]

        for (target, tab) in mappings {
            guard let index = CandidateTab.allCases.firstIndex(of: tab) else { continue }
            frames[target] = CGRect(
                x: tabBarFrame.minX + CGFloat(index) * slotWidth,
                y: tabBarFrame.minY,
                width: slotWidth,
                height: tabBarFrame.height
            )
        }

        guard frames != lastFrames else { return }
        lastFrames = frames
        onFramesChange(frames)
    }

    private func findTabBarController(from controller: UIViewController?) -> UITabBarController? {
        guard let controller else { return nil }
        if let tabBarController = controller as? UITabBarController {
            return tabBarController
        }
        if let presented = controller.presentedViewController,
           let match = findTabBarController(from: presented) {
            return match
        }
        for child in controller.children {
            if let match = findTabBarController(from: child) {
                return match
            }
        }
        return nil
    }
}
