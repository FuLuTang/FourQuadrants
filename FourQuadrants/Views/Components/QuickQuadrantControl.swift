import SwiftUI

/// A compact two-by-two quadrant selector for the task form.
///
/// The four regions form one continuous colored touch surface.
struct QuickQuadrantControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var importance: ImportanceLevel
    @Binding var isUrgent: Bool

    /// When present, urgency is controlled by the target date threshold. The
    /// automatic layout then changes importance only and leaves this binding
    /// untouched.
    var effectiveUrgency: Bool? = nil

    private let panelHeight: CGFloat = 140
    /// A normalized coordinate keeps the visual position independent from the
    /// panel's current size. It deliberately does not derive from the selected
    /// value while a finger is down, so external binding updates cannot add a
    /// translation to a new selection and make the handle jump.
    @State private var handlePosition: CGPoint?
    @State private var gestureNeedsCancellationRecovery = false
    @GestureState private var isTouchActive = false

    private var selectedQuadrant: QuickQuadrant {
        QuickQuadrant(
            importance: importance,
            isUrgent: effectiveUrgency ?? isUrgent
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                Group {
                    if effectiveUrgency != nil {
                        automaticLayout(in: proxy.size)
                    } else {
                        manualLayout(in: proxy.size)
                    }
                }
                .transaction { transaction in
                    if reduceMotion {
                        transaction.animation = nil
                    }
                }
                .onAppear {
                    restoreHandleForCurrentSelection(in: proxy.size, animated: false)
                }
                .onChange(of: importance) { _, _ in
                    guard !isTouchActive else { return }
                    restoreHandleForCurrentSelection(in: proxy.size, animated: true)
                }
                .onChange(of: isUrgent) { _, _ in
                    guard effectiveUrgency == nil, !isTouchActive else { return }
                    restoreHandleForCurrentSelection(in: proxy.size, animated: true)
                }
                .onChange(of: effectiveUrgency) { _, _ in
                    guard !isTouchActive else { return }
                    restoreHandleForCurrentSelection(in: proxy.size, animated: true)
                }
                .onChange(of: isTouchActive) { _, active in
                    // DragGesture does not call onEnded when the system cancels
                    // its sequence. Restore the current selection in that case.
                    guard !active, gestureNeedsCancellationRecovery else { return }
                    gestureNeedsCancellationRecovery = false
                    restoreHandleForCurrentSelection(in: proxy.size, animated: true)
                }
            }
            .frame(height: panelHeight)
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.9),
                value: effectiveUrgency != nil
            )

            Group {
                if let selectionIcon {
                    Label(selectionTitle, systemImage: selectionIcon)
                } else {
                    Text(selectionTitle)
                }
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectionColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel(Text("quick_control_current"))
                .accessibilityValue(Text(selectionTitle))
        }
    }

    private var selectionTitle: String {
        effectiveUrgency == nil ? selectedQuadrant.title : AutomaticQuickOption(importance: importance).title
    }

    private var selectionColor: Color {
        effectiveUrgency == nil ? selectedQuadrant.color : AutomaticQuickOption(importance: importance).color
    }

    private var selectionIcon: String? {
        effectiveUrgency == nil ? selectedQuadrant.icon : nil
    }

    @ViewBuilder
    private func manualLayout(in size: CGSize) -> some View {
        let layout = GridLayout(size: size)
        let presentationPosition = currentHandlePosition(
            fallback: layout.center(for: selectedQuadrant),
            in: size,
            automatic: false
        )
        ZStack {
            manualColorField()

            ForEach(QuickQuadrant.allCases) { quadrant in
                landingPoint(at: layout.center(for: quadrant))
            }

            handle()
                .position(presentationPosition)
        }
        .clipShape(panelShape)
        .overlay { panelOutline }
        .shadow(color: .black.opacity(0.16), radius: 6, y: 2)
        .contentShape(panelShape)
        .gesture(panelDrag(in: size, automatic: false) { point in
            let quadrant = nearestQuadrant(to: point, in: layout)
            select(quadrant)
            return layout.center(for: quadrant)
        })
        .accessibilityElement(children: .contain)
        .accessibilityChildren {
            ForEach(QuickQuadrant.allCases) { quadrant in
                Button(quadrant.title) { select(quadrant) }
                    .accessibilityHint(Text("quick_control_select_hint"))
                    .accessibilityAddTraits(quadrant == selectedQuadrant ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func automaticLayout(in size: CGSize) -> some View {
        let layout = AutomaticLayout(size: size)
        let selectedOption = AutomaticQuickOption(importance: importance)
        let presentationPosition = currentHandlePosition(
            fallback: layout.center(for: selectedOption),
            in: size,
            automatic: true
        )
        ZStack {
            automaticColorField()

            ForEach(AutomaticQuickOption.allCases) { option in
                landingPoint(at: layout.center(for: option))
            }

            handle()
                .position(presentationPosition)
        }
        .clipShape(panelShape)
        .overlay { panelOutline }
        .shadow(color: .black.opacity(0.16), radius: 6, y: 2)
        .contentShape(panelShape)
        .gesture(panelDrag(in: size, automatic: true) { point in
            let option = nearestOption(to: point, in: layout)
            select(option)
            return layout.center(for: option)
        })
        .accessibilityElement(children: .contain)
        .accessibilityChildren {
            ForEach(AutomaticQuickOption.allCases) { option in
                Button(option.title) { select(option) }
                    .accessibilityHint(Text("quick_control_select_hint"))
                    .accessibilityAddTraits(option == selectedOption ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func handle() -> some View {
        let diameter = isTouchActive && !reduceMotion ? 78.0 : 26.0
        ZStack {
            if isTouchActive {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 92, height: 92)
                    .blur(radius: 13)
            }

            Circle()
                .fill(.white.opacity(isTouchActive ? 0.22 : 0.14))
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(isTouchActive ? 0.94 : 0.78), lineWidth: 1.5)
                }
                .overlay {
                    RadialGradient(
                        colors: [.white.opacity(isTouchActive ? 0.62 : 0.34), .clear],
                        center: .init(x: 0.3, y: 0.22),
                        startRadius: 0,
                        endRadius: diameter * 0.7
                    )
                }
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular, in: .circle)
                .shadow(color: .black.opacity(0.2), radius: isTouchActive ? 4 : 1.5, y: 1)

            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: isTouchActive ? 7 : 5, height: isTouchActive ? 7 : 5)
        }
        .frame(width: 100, height: 100)
            .accessibilityHidden(true)
            .animation(pressAnimation, value: isTouchActive)
    }

    private func landingPoint(at position: CGPoint) -> some View {
        Circle()
            .fill(.white.opacity(0.5))
            .frame(width: 4, height: 4)
            .shadow(color: .black.opacity(0.16), radius: 1, y: 0.5)
            .position(position)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    private var panelOutline: some View {
        panelShape
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.32), .white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.7
            )
            .allowsHitTesting(false)
    }

    private func manualColorField() -> some View {
        Rectangle().fill(manualMesh)
    }

    private func automaticColorField() -> some View {
        Rectangle().fill(automaticMesh)
    }

    private var manualMesh: MeshGradient {
        MeshGradient(width: 8, height: 7, points: meshPoints(columns: Self.manualColumns, rows: Self.manualRows), colors: manualMeshColors, background: AppTheme.Colors.normal, colorSpace: .perceptual)
    }

    private var automaticMesh: MeshGradient {
        let rows: [Float] = [0, 0.14, 0.25, 0.45, 0.58, 0.75, 1]
        let colors = [
            AppTheme.Colors.urgentImportant, AppTheme.Colors.urgentImportant,
            AppTheme.Colors.urgentImportant, AppTheme.Colors.urgentImportant,
            AppTheme.Colors.urgentImportant, AppTheme.Colors.urgentImportant,
            bridgeAmber, bridgeAmber, bridgeYellowGreen, bridgeYellowGreen,
            softGreen, softGreen, softGreen, softGreen
        ]
        return MeshGradient(width: 2, height: 7, points: meshPoints(columns: [0, 1], rows: rows), colors: colors, background: softGreen, colorSpace: .perceptual)
    }

    private var manualMeshColors: [Color] {
        let red = AppTheme.Colors.urgentImportant
        let blue = AppTheme.Colors.importantNotUrgent
        let gray = AppTheme.Colors.normal
        let top = [red, red, red, bridgePink, bridgePurple, blue, blue, blue]
        let middle = [bridgeAmber, bridgeAmber, bridgeAmber, bridgeYellowGreen, bridgeTeal, bridgeBlueViolet, gray, gray]
        let bottom = [softGreen, softGreen, softGreen, bridgeYellowGreen, bridgeTeal, gray, gray, gray]
        return top + top + top + middle + bottom + bottom + bottom
    }

    private func meshPoints(columns: [Float], rows: [Float]) -> [SIMD2<Float>] {
        rows.flatMap { y in columns.map { x in SIMD2(x, y) } }
    }

    private static let manualColumns: [Float] = [0, 0.16, 0.25, 0.45, 0.58, 0.75, 0.88, 1]
    private static let manualRows: [Float] = [0, 0.14, 0.25, 0.5, 0.75, 0.9, 1]
    private var softGreen: Color { Color(hue: 0.426, saturation: 0.72, brightness: 0.84) }
    private var bridgePink: Color { Color(.displayP3, red: 0.94, green: 0.27, blue: 0.53) }
    private var bridgePurple: Color { Color(.displayP3, red: 0.64, green: 0.32, blue: 0.85) }
    private var bridgeAmber: Color { Color(.displayP3, red: 0.96, green: 0.60, blue: 0.27) }
    private var bridgeYellowGreen: Color { Color(.displayP3, red: 0.66, green: 0.84, blue: 0.36) }
    private var bridgeTeal: Color { Color(.displayP3, red: 0.20, green: 0.72, blue: 0.65) }
    private var bridgeBlueViolet: Color { Color(.displayP3, red: 0.52, green: 0.60, blue: 0.85) }

    private func select(_ quadrant: QuickQuadrant) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.32, dampingFraction: 0.9)) {
            importance = quadrant.importance
            if effectiveUrgency == nil {
                isUrgent = quadrant.isUrgent
            }
        }
    }

    private func select(_ option: AutomaticQuickOption) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.32, dampingFraction: 0.9)) {
            importance = option.importance
        }
    }

    private var pressAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.86)
    }

    /// One recognizer owns the complete colored field. The handle remains
    /// purely presentational, which means a press that starts away from it has
    /// the same direct-manipulation behavior as one that starts on it.
    private func panelDrag(
        in size: CGSize,
        automatic: Bool,
        commit: @escaping (CGPoint) -> CGPoint
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouchActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let animation = gestureNeedsCancellationRecovery ? interactionAnimation : touchDownAnimation
                gestureNeedsCancellationRecovery = true
                moveHandle(to: value.location, in: size, automatic: automatic, animation: animation)
            }
            .onEnded { value in
                gestureNeedsCancellationRecovery = false
                let releasePoint = constrained(value.location, in: size, automatic: automatic)
                let landingPoint = commit(releasePoint)
                moveHandle(to: landingPoint, in: size, automatic: automatic, animation: settleAnimation)
            }
    }

    private var interactionAnimation: Animation? {
        reduceMotion ? nil : .interactiveSpring(response: 0.1, dampingFraction: 0.92, blendDuration: 0.05)
    }

    private var touchDownAnimation: Animation? {
        reduceMotion ? nil : .interactiveSpring(response: 0.2, dampingFraction: 0.92, blendDuration: 0.05)
    }

    private var settleAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 1)
    }

    private func restoreHandleForCurrentSelection(in size: CGSize, animated: Bool) {
        let target: CGPoint
        if effectiveUrgency != nil {
            target = AutomaticLayout(size: size).center(for: AutomaticQuickOption(importance: importance))
        } else {
            target = GridLayout(size: size).center(for: selectedQuadrant)
        }
        moveHandle(
            to: target,
            in: size,
            automatic: effectiveUrgency != nil,
            animation: animated ? settleAnimation : nil
        )
    }

    private func moveHandle(to point: CGPoint, in size: CGSize, automatic: Bool, animation: Animation?) {
        let constrainedPoint = constrained(point, in: size, automatic: automatic)
        let normalized = CGPoint(
            x: size.width > 0 ? constrainedPoint.x / size.width : 0.5,
            y: size.height > 0 ? constrainedPoint.y / size.height : 0.5
        )
        withAnimation(animation) {
            handlePosition = normalized
        }
    }

    private func currentHandlePosition(fallback: CGPoint, in size: CGSize, automatic: Bool) -> CGPoint {
        guard let handlePosition else {
            return constrained(fallback, in: size, automatic: automatic)
        }
        return constrained(
            CGPoint(x: handlePosition.x * size.width, y: handlePosition.y * size.height),
            in: size,
            automatic: automatic
        )
    }

    private func nearestQuadrant(to point: CGPoint, in layout: GridLayout) -> QuickQuadrant {
        QuickQuadrant.allCases.min {
            distanceSquared(from: point, to: layout.center(for: $0)) <
                distanceSquared(from: point, to: layout.center(for: $1))
        } ?? selectedQuadrant
    }

    private func constrained(_ point: CGPoint, in size: CGSize, automatic: Bool) -> CGPoint {
        automatic ? constrainedAutomatic(point, in: size) : constrainedManual(point, in: size)
    }

    private func constrainedManual(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let horizontalInset = GridLayout.inset
        let verticalInset = GridLayout.inset
        return CGPoint(
            x: min(max(point.x, horizontalInset + 22), size.width - horizontalInset - 22),
            y: min(max(point.y, verticalInset + 22), size.height - verticalInset - 22)
        )
    }

    private func constrainedAutomatic(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2,
            y: min(max(point.y, AutomaticLayout.inset + 22), size.height - AutomaticLayout.inset - 22)
        )
    }

    private func nearestOption(to point: CGPoint, in layout: AutomaticLayout) -> AutomaticQuickOption {
        AutomaticQuickOption.allCases.min {
            abs(point.y - layout.center(for: $0).y) < abs(point.y - layout.center(for: $1).y)
        } ?? AutomaticQuickOption(importance: importance)
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let x = lhs.x - rhs.x
        let y = lhs.y - rhs.y
        return x * x + y * y
    }

    private struct GridLayout {
        static let inset: CGFloat = 0
        let cellSize: CGSize
        let size: CGSize

    init(size: CGSize) {
        self.size = size
        cellSize = CGSize(
                width: max((size.width - Self.inset * 2) / 2, 1),
                height: max((size.height - Self.inset * 2) / 2, 1)
            )
        }

        func center(for quadrant: QuickQuadrant) -> CGPoint {
            let x = Self.inset + cellSize.width / 2 + (quadrant.column == 1 ? cellSize.width : 0)
            let y = Self.inset + cellSize.height / 2 + (quadrant.row == 1 ? cellSize.height : 0)
            return CGPoint(x: x, y: y)
        }
    }
}

private enum QuickQuadrant: CaseIterable, Identifiable, Hashable {
    case importantAndUrgent
    case importantButNotUrgent
    case urgentButNotImportant
    case notImportantAndNotUrgent

    var id: Self { self }

    var category: TaskCategory {
        switch self {
        case .importantAndUrgent: return .importantAndUrgent
        case .importantButNotUrgent: return .importantButNotUrgent
        case .urgentButNotImportant: return .urgentButNotImportant
        case .notImportantAndNotUrgent: return .notImportantAndNotUrgent
        }
    }

    var title: String { category.displayName }
    var icon: String { category.icon }
    var color: Color { category.themeColor }
    var importance: ImportanceLevel {
        switch self {
        case .importantAndUrgent, .importantButNotUrgent: return .high
        case .urgentButNotImportant, .notImportantAndNotUrgent: return .normal
        }
    }
    var isUrgent: Bool {
        switch self {
        case .importantAndUrgent, .urgentButNotImportant: return true
        case .importantButNotUrgent, .notImportantAndNotUrgent: return false
        }
    }
    var row: Int {
        switch self {
        case .importantAndUrgent, .importantButNotUrgent: return 0
        case .urgentButNotImportant, .notImportantAndNotUrgent: return 1
        }
    }
    var column: Int {
        switch self {
        case .importantAndUrgent, .urgentButNotImportant: return 0
        case .importantButNotUrgent, .notImportantAndNotUrgent: return 1
        }
    }

    init(importance: ImportanceLevel, isUrgent: Bool) {
        switch (importance == .high, isUrgent) {
        case (true, true): self = .importantAndUrgent
        case (true, false): self = .importantButNotUrgent
        case (false, true): self = .urgentButNotImportant
        case (false, false): self = .notImportantAndNotUrgent
        }
    }
}

private struct AutomaticLayout {
    static let inset: CGFloat = 0
    let size: CGSize
    let padSize: CGSize
    let centerX: CGFloat

    init(size: CGSize) {
        self.size = size
        let padHeight = max((size.height - Self.inset * 2) / 2, 1)
        padSize = CGSize(
            width: max(size.width - Self.inset * 2, 1),
            height: padHeight
        )
        centerX = size.width / 2
    }

    func center(for option: AutomaticQuickOption) -> CGPoint {
        let y = Self.inset + padSize.height / 2 + (option == .notImportant ? padSize.height : 0)
        return CGPoint(x: centerX, y: y)
    }
}

private enum AutomaticQuickOption: CaseIterable, Identifiable, Hashable {
    case important
    case notImportant

    var id: Self { self }

    var title: String {
        String(localized: self == .important ? "quick_control_important" : "quick_control_not_important")
    }

    var icon: String {
        self == .important ? "star.fill" : "minus.circle"
    }

    var color: Color {
        self == .important
            ? AppTheme.Colors.urgentImportant
            : Color(hue: 0.426, saturation: 0.72, brightness: 0.84)
    }

    var importance: ImportanceLevel {
        self == .important ? .high : .normal
    }

    var tintColor: Color {
        self == .important ? AppTheme.Colors.importantNotUrgent : AppTheme.Colors.urgentNotImportant
    }

    init(importance: ImportanceLevel) {
        self = importance == .high ? .important : .notImportant
    }
}
