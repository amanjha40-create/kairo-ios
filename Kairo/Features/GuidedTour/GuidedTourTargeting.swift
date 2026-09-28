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
    static func orderedTabFrames(_ frames: [CGRect], expectedCount: Int) -> [CGRect]? {
        // Floating tab bars may render selected/unselected layers at identical
        // positions. Collapse those layers, not distinct or ambiguous targets.
        var unique: [CGRect] = []
        for frame in frames where frame.width > 0 && frame.height > 0 {
            if !unique.contains(frame) { unique.append(frame) }
        }
        guard unique.count == expectedCount else { return nil }
        return unique.sorted { $0.midX < $1.midX }
    }

    /// UIKit window coordinates and SwiftUI overlay coordinates must be reconciled
    /// before either tab or content geometry is drawn by the overlay.
    static func overlayFrame(windowFrame: CGRect, overlayOrigin: CGPoint) -> CGRect {
        windowFrame.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y)
    }

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

        guard let window else { return }
        // Measure the actual controls: modern floating tab bars do not occupy
        // equal full-height slices of UITabBar.bounds. Do not guess if unavailable.
        let controlFrames = tabControls(in: tabBar).filter {
            !$0.isHidden && $0.alpha > 0 && $0.bounds.width > 0 && $0.bounds.height > 0
        }.map {
            $0.convert($0.bounds, to: window)
        }
        guard let slots = GuidedTourTargetResolver.orderedTabFrames(
            controlFrames, expectedCount: CandidateTab.allCases.count
        ) else {
            if !lastFrames.isEmpty {
                lastFrames = [:]
                onFramesChange([:])
            }
            return
        }
        let orderedFrames = effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? Array(slots.reversed()) : slots
        let mappings: [(GuidedTourTarget, CandidateTab)] = [
            (.career, .career),
            (.verify, .verify),
            (.more, .more)
        ]
        var frames: [GuidedTourTarget: CGRect] = [:]

        for (target, tab) in mappings {
            guard let index = CandidateTab.allCases.firstIndex(of: tab) else { continue }
            frames[target] = orderedFrames[index]
        }

        guard frames != lastFrames else { return }
        lastFrames = frames
        onFramesChange(frames)
    }

    private func tabControls(in view: UIView) -> [UIControl] {
        view.subviews.flatMap { child -> [UIControl] in
            guard !child.isHidden, child.alpha > 0 else { return [] }
            if let control = child as? UIControl { return [control] }
            return tabControls(in: child)
        }
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
