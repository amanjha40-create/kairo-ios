import SwiftUI

/// Presentation clocks only. Never persisted, shared between accounts or used as product truth.
nonisolated struct KairoMotionEntry: Equatable, Sendable {
    var generation = 0
    var active = true
    var identityRevision = 0
}
private struct KairoMotionEntryKey: EnvironmentKey {
    static let defaultValue = KairoMotionEntry()
}
extension EnvironmentValues {
    var kairoMotionEntry: KairoMotionEntry {
        get { self[KairoMotionEntryKey.self] }
        set { self[KairoMotionEntryKey.self] = newValue }
    }
}

nonisolated enum PremiumMotion {
    static let signature = 0.72
    static let reduced = 0.14
    static func score(from: Int, to: Int, elapsed: Double) -> Int {
        let t = min(1, max(0, elapsed / signature))
        let smooth = t * t * (3 - 2 * t)
        return Int((Double(from) + Double(to - from) * smooth).rounded())
    }
    static func shouldCelebrate(previous: Int?, current: Int, target: Int) -> Bool {
        guard let previous else { return false }
        return previous < target && current == target
    }
}

/// Owned by the screen, outside loading/error content, so retry/refetch cannot replay entry.
nonisolated struct PremiumScoreMemory: Equatable {
    var entry: Int?
    var value: Int?
    mutating func begin(entry nextEntry: Int, value nextValue: Int, animate: Bool) -> Int? {
        let previousEntry = entry, previousValue = value
        entry = nextEntry; value = nextValue
        guard animate, previousEntry != nextEntry || previousValue != nextValue else { return nil }
        return previousEntry == nextEntry ? (previousValue ?? 0) : 0
    }
}

nonisolated enum KairoTrustSymbol: Sendable { case shield, verified, references, connected, location }

/// Finite 720ms draw/settle; no timers survive background, disappearance or Reduce Motion.
struct KairoTrustSignature: View {
    var kind: KairoTrustSymbol = .shield
    let trigger: Int
    var animateInitially = false
    var size: CGFloat = 64
    var history: Binding<Int?>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.kairoMotionEntry) private var entry
    @State private var seen: Int?
    @State private var run = UUID()
    @State private var drawing: CGFloat = 1
    @State private var scale: CGFloat = 1
    @State private var opacity = 1.0
    @State private var pulse = 0.0
    private var lastSeen: Int? { history?.wrappedValue ?? seen }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(KairoColors.accent.opacity(0.12))
            Circle().fill(KairoColors.accent.opacity(pulse)).scaleEffect(1.12)
            TrustStroke(kind: kind).trim(from: 0, to: drawing)
                .stroke(KairoColors.brandPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .padding(size / 8)
        }
        .frame(width: size, height: size)
        .scaleEffect(scale).opacity(opacity)
        .accessibilityHidden(true)
        .onAppear { considerTrigger() }
        .onChange(of: trigger) { _, _ in considerTrigger() }
        .onChange(of: entry.active) { _, active in if !active { settle() } else { considerTrigger() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { settle() }
            else if lastSeen == nil { considerTrigger() }
        }
        .onChange(of: reduceMotion) { _, _ in settle() }
        .onDisappear { settle() }
        .task(id: run) {
            guard opacity < 1, entry.active, scenePhase == .active else { return }
            if reduceMotion {
                withAnimation(.linear(duration: PremiumMotion.reduced)) { opacity = 1 }
                return
            }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5)) { scale = 1.02; opacity = 1 }
            do {
                try await Task.sleep(for: .milliseconds(100))
                withAnimation(.linear(duration: 0.44)) { drawing = 1 }
                try await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeOut(duration: 0.1)) { pulse = 0.32; scale = 1 }
                try await Task.sleep(for: .milliseconds(100))
                withAnimation(.easeOut(duration: 0.12)) { pulse = 0 }
            } catch { /* Cancellation is settled synchronously by the lifecycle hooks. */ }
        }
    }
    private func considerTrigger() {
        guard lastSeen != trigger else { return }
        guard entry.active else { return }
        if lastSeen == nil && scenePhase != .active { return }
        let shouldPlay = lastSeen != nil || animateInitially
        if let history { history.wrappedValue = trigger } else { seen = trigger }
        guard shouldPlay, entry.active, scenePhase == .active,
              !UITestLaunchConfiguration.current().disablesAnimations else { settle(); return }
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            drawing = reduceMotion ? 1 : 0; scale = reduceMotion ? 1 : 0.9
            opacity = 0.65; pulse = 0; run = UUID()
        }
    }
    private func settle() {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { run = UUID(); drawing = 1; scale = 1; opacity = 1; pulse = 0 }
    }
}

private nonisolated struct TrustStroke: Shape {
    let kind: KairoTrustSymbol
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        switch kind {
        case .shield, .verified:
            p.move(to: point(0.5, 0.04)); p.addLine(to: point(0.88, 0.2)); p.addLine(to: point(0.84, 0.59))
            p.addQuadCurve(to: point(0.5, 0.95), control: point(0.78, 0.85))
            p.addQuadCurve(to: point(0.16, 0.59), control: point(0.22, 0.85))
            p.addLine(to: point(0.12, 0.2)); p.closeSubpath()
            p.move(to: point(0.3, 0.49)); p.addLine(to: point(0.44, 0.64)); p.addLine(to: point(0.72, 0.35))
        case .references, .connected:
            p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.04, y: rect.midY - rect.height * 0.18, width: rect.width * 0.36, height: rect.height * 0.36))
            p.move(to: point(0.3, 0.5)); p.addLine(to: point(0.7, 0.5))
            p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.6, y: rect.midY - rect.height * 0.18, width: rect.width * 0.36, height: rect.height * 0.36))
            p.move(to: point(0.42, 0.78)); p.addLine(to: point(0.5, 0.87)); p.addLine(to: point(0.66, 0.7))
        case .location:
            p.move(to: point(0.5, 0.95))
            p.addCurve(to: point(0.5, 0.08), control1: point(-0.15, 0.4), control2: point(0.18, 0.08))
            p.addCurve(to: point(0.5, 0.95), control1: point(0.82, 0.08), control2: point(1.15, 0.4))
            p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.28, width: rect.width * 0.24, height: rect.height * 0.24))
        }
        return p
    }
}

struct KairoAnimatedScore: View {
    let value: Int
    @Binding var memory: PremiumScoreMemory
    @Environment(\.kairoMotionEntry) private var entry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var from = 0
    @State private var start: Date?
    private var clockKey: String { "\(entry.identityRevision):\(entry.generation):\(entry.active):\(value):\(reduceMotion):\(phase == .active)" }
    var body: some View {
        Group {
            if let start {
                TimelineView(.animation) { clock in
                    Text(String(PremiumMotion.score(from: from, to: value, elapsed: clock.date.timeIntervalSince(start))))
                        .monospacedDigit()
                }
            } else { Text(String(value)).monospacedDigit() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trust Score")
        .accessibilityValue("\(value) out of 100")
        .task(id: clockKey) {
            guard entry.active, phase == .active, !reduceMotion,
                  !UITestLaunchConfiguration.current().disablesAnimations else {
                start = nil
                if memory.entry != nil || reduceMotion { _ = memory.begin(entry: entry.generation, value: value, animate: false) }
                return
            }
            guard let origin = memory.begin(entry: entry.generation, value: value, animate: true) else { start = nil; return }
            from = origin
            await Task.yield() // The clock starts at presentation, not before route rendering.
            guard !Task.isCancelled else { return }
            start = Date()
            do { try await Task.sleep(for: .milliseconds(720)); start = nil } catch { }
        }
        .onDisappear { start = nil }
    }
}

/// Keep form state mounted, but collapsed children cannot receive focus or taps.
struct KairoDisclosure<Content: View>: View {
    let title: String
    var summary: String? = nil
    var identifier: String? = nil
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    init(title: String, summary: String? = nil, identifier: String? = nil, initiallyExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title; self.summary = summary; self.identifier = identifier
        self.content = content(); _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 8 : 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { expanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(KairoTypography.recordTitle)
                        if let summary { Text(summary).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary) }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").rotationEffect(.degrees(expanded ? 90 : 0)).accessibilityHidden(true)
                }
                .foregroundStyle(KairoColors.textPrimary).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(KairoActionStyle())
            .accessibilityLabel([title, summary].compactMap { $0 }.joined(separator: ", ")).accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier(identifier ?? "disclosure.\(title)")
            content.frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: expanded ? nil : 0, alignment: .top).clipped()
                .opacity(expanded ? 1 : 0).allowsHitTesting(expanded).accessibilityHidden(!expanded)
        }
    }
}
