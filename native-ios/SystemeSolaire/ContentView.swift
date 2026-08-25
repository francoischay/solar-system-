import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: Engine
    @State private var scaleMenuOpen = false
    @State private var dockExpansionProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpaceBackground()
                SceneContainer()
                    .ignoresSafeArea()
                LabelsOverlay()
                TimelineBar()
                if engine.showTodayButton, abs(engine.handleTopPercent - 50) > 9 {
                    todayButton
                }
                VStack {
                    Spacer()
                    if scaleMenuOpen {
                        ScaleMenu(open: $scaleMenuOpen)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                    }
                    if engine.exploreView != .none {
                        ExplorerPanel()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                            .frame(maxWidth: 520)
                    }
                    dock(
                        maxSheetHeight: max(58, proxy.size.height * 0.5),
                        availableWidth: max(0, proxy.size.width - 32)
                    )
                }
            }
            .onAppear { engine.requestLocation() }
        }
    }

    private var todayButton: some View {
        HStack {
            Spacer()
            Button("Aujourd’hui") { engine.goToToday() }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.14, green: 0.12, blue: 0.38).opacity(0.72), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                .padding(.trailing, 8)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .transition(.opacity)
    }

    private func dock(maxSheetHeight: CGFloat, availableWidth: CGFloat) -> some View {
        let progress = max(0, min(1, dockExpansionProgress))
        let compactWidth = max(120, availableWidth - 112)
        let sheetWidth = compactWidth + (availableWidth - compactWidth) * progress
        let iconScale = 1 - progress * 0.75

        return ZStack(alignment: .bottom) {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        engine.setExploreView(engine.exploreView == .none ? .missions : .none)
                    }
                    scaleMenuOpen = false
                } label: {
                    Text(viewGlyph)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(engine.exploreView != .none ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.9))
                        .frame(width: 46, height: 46)
                        .background(engine.exploreView != .none ? AnyShapeStyle(Color(red: 0.96, green: 0.95, blue: 1)) : AnyShapeStyle(GlassStyle.fill), in: Circle())
                        .overlay(Circle().strokeBorder(GlassStyle.border, lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.16)) { scaleMenuOpen.toggle() }
                } label: {
                    Text(engine.scaleShort)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(scaleMenuOpen ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.9))
                        .frame(width: 46, height: 46)
                        .background(scaleMenuOpen ? AnyShapeStyle(Color(red: 0.96, green: 0.95, blue: 1)) : AnyShapeStyle(GlassStyle.fill), in: Circle())
                        .overlay(Circle().strokeBorder(GlassStyle.border, lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .opacity(1 - progress)
            .scaleEffect(iconScale)
            .blur(radius: progress * 4)
            .allowsHitTesting(progress < 0.08)
            .accessibilityHidden(progress > 0.5)

            InfoCard(
                maxHeight: maxSheetHeight,
                expansionProgress: $dockExpansionProgress
            )
            .frame(width: sheetWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var viewGlyph: String {
        switch engine.exploreView {
        case .none: return "◎"
        case .missions: return "✦"
        case .satellites: return "▣"
        case .launches: return "↑"
        }
    }
}

// MARK: - Fond

struct SpaceBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.067, green: 0.075, blue: 0.24),
                    Color(red: 0.09, green: 0.094, blue: 0.345),
                    Color(red: 0.16, green: 0.125, blue: 0.39),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 0.51, green: 0.29, blue: 0.92).opacity(0.68), .clear],
                center: UnitPoint(x: 0.12, y: 0.86), startRadius: 0, endRadius: 320
            )
            RadialGradient(
                colors: [Color(red: 0.19, green: 0.24, blue: 0.71).opacity(0.24), .clear],
                center: UnitPoint(x: 0.8, y: 0.18), startRadius: 0, endRadius: 300
            )
        }
        .ignoresSafeArea()
    }
}

enum GlassStyle {
    static let fill = LinearGradient(
        colors: [Color(red: 0.48, green: 0.46, blue: 0.88).opacity(0.26), Color(red: 0.12, green: 0.13, blue: 0.36).opacity(0.3)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let border = Color(red: 0.75, green: 0.76, blue: 1).opacity(0.3)
    static let panel = LinearGradient(
        colors: [Color(red: 0.18, green: 0.17, blue: 0.47).opacity(0.93), Color(red: 0.08, green: 0.08, blue: 0.26).opacity(0.95)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Étiquettes 3D

struct LabelsOverlay: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        ZStack {
            ForEach(engine.labels) { label in
                Text(label.text)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.086, green: 0.106, blue: 0.267).opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0.5, green: 0.88, blue: 1).opacity(0.42), lineWidth: 1))
                    .position(x: label.x, y: label.y - 26)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Cartouche de sélection

struct InfoCard: View {
    @EnvironmentObject var engine: Engine
    let maxHeight: CGFloat
    @Binding var expansionProgress: CGFloat
    @State private var detailExpanded = false
    @State private var sheetHeight: CGFloat = 58
    @State private var dragStartHeight: CGFloat?
    @State private var isDragging = false

    private let minHeight: CGFloat = 58

    private var clampedMaxHeight: CGFloat { max(minHeight, maxHeight) }
    var body: some View {
        let progress = expansionProgress
        let cornerRadius = 29 - progress * 7
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(spacing: 0) {
            sheetHeader
            if let detail = engine.selectionDetail {
                ScrollView {
                    Text(DateLinker.attributed(detail))
                    .font(.system(size: 12.5))
                    .lineSpacing(3.5)
                    .foregroundStyle(.white.opacity(0.74))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .opacity(progress)
                .offset(y: (1 - progress) * 8)
                .allowsHitTesting(detailExpanded && !isDragging)
                .accessibilityHidden(progress < 0.5)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "sscale", let value = Double(url.lastPathComponent) {
                        engine.jump(toDay: value)
                        return .handled
                    }
                    return .systemAction
                })
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: sheetHeight, alignment: .top)
        .background(GlassStyle.fill, in: shape)
        .background(.ultraThinMaterial, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(GlassStyle.border, lineWidth: 1))
        .accessibilityAction(named: Text(detailExpanded ? "Réduire le détail" : "Agrandir le détail")) {
            snap(expanded: !detailExpanded)
        }
        .onChange(of: engine.selectionTitle) {
            snap(expanded: false)
        }
        .onChange(of: engine.selectionDetail) {
            if engine.selectionDetail == nil { snap(expanded: false) }
        }
        .onChange(of: maxHeight) {
            guard detailExpanded else { return }
            withAnimation(.spring(duration: 0.32, bounce: 0)) {
                sheetHeight = clampedMaxHeight
            }
        }
        .onAppear {
            sheetHeight = minHeight
            expansionProgress = 0
            engine.setDetailExpansionProgress(0, immediate: true)
        }
        .onDisappear {
            expansionProgress = 0
            engine.setDetailExpansionProgress(0, immediate: true)
        }
    }

    private var sheetHeader: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .gesture(sheetDragGesture)
                .onTapGesture {
                    if engine.selectionIsSpacecraft { engine.infoCardTapped() }
                }

            if engine.selectionDetail != nil {
                Capsule()
                    .fill(.white.opacity(0.34))
                    .frame(width: 36, height: 5)
                    .padding(.top, 5)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 2) {
                Text(engine.selectionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(engine.selectionSub)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .padding(.horizontal, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 3)
            .allowsHitTesting(false)

            if engine.selectionDetail != nil {
                HStack {
                    Spacer()
                    Button {
                        snap(expanded: !detailExpanded)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.1), in: Circle())
                            .rotationEffect(.degrees(detailExpanded ? 180 : 0))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(detailExpanded ? "Réduire le détail" : "Agrandir le détail")
                }
                .padding(.trailing, 4)
                .padding(.top, 9)
            }
        }
        .frame(height: minHeight)
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                guard engine.selectionDetail != nil else { return }
                let start = dragStartHeight ?? sheetHeight
                if dragStartHeight == nil {
                    dragStartHeight = start
                    isDragging = true
                }
                let next = max(minHeight, min(clampedMaxHeight, start - value.translation.height))
                sheetHeight = next
                let range = clampedMaxHeight - minHeight
                let progress = range > 0 ? (next - minHeight) / range : 0
                expansionProgress = progress
                engine.setDetailExpansionProgress(Double(progress), immediate: true)
            }
            .onEnded { value in
                guard let start = dragStartHeight else { return }
                let predicted = max(
                    minHeight,
                    min(clampedMaxHeight, start - value.predictedEndTranslation.height)
                )
                let threshold = minHeight + (clampedMaxHeight - minHeight) * 0.42
                dragStartHeight = nil
                isDragging = false
                snap(expanded: predicted > threshold)
            }
    }

    private func snap(expanded: Bool) {
        let shouldExpand = expanded && engine.selectionDetail != nil
        detailExpanded = shouldExpand
        withAnimation(.spring(duration: 0.32, bounce: 0)) {
            sheetHeight = shouldExpand ? clampedMaxHeight : minHeight
            expansionProgress = shouldExpand ? 1 : 0
        }
        engine.setDetailExpansionProgress(shouldExpand ? 1 : 0, immediate: false)
    }
}

/// Chaque date du texte devient un lien qui cale la timeline dessus
enum DateLinker {
    static let months: [String: Int] = [
        "janvier": 1, "février": 2, "mars": 3, "avril": 4, "mai": 5, "juin": 6,
        "juillet": 7, "août": 8, "septembre": 9, "octobre": 10, "novembre": 11, "décembre": 12,
    ]
    static let pattern: NSRegularExpression = {
        let names = months.keys.joined(separator: "|")
        return try! NSRegularExpression(
            pattern: "(\\d{1,2})(?:er)?\\s+(\(names))\\s+((?:19|20)\\d{2})|(\(names))\\s+((?:19|20)\\d{2})|\\b((?:19|20)\\d{2})\\b"
        )
    }()

    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let ns = text as NSString
        for match in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            var day: Double?
            func group(_ i: Int) -> String? {
                let r = match.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            if let d = group(1), let m = group(2), let y = group(3), let month = months[m] {
                day = Astro.dayFromUTC(year: Int(y)!, month: month, dayOfMonth: Int(d)!)
            } else if let m = group(4), let y = group(5), let month = months[m] {
                day = Astro.dayFromUTC(year: Int(y)!, month: month, dayOfMonth: 15)
            } else if let y = group(6) {
                day = Astro.dayFromUTC(year: Int(y)!, month: 7, dayOfMonth: 1)
            }
            guard let day, let range = Range(match.range, in: text),
                  let attrRange = result.range(of: String(text[range])) else { continue }
            result[attrRange].link = URL(string: "sscale://day/\(day)")
            result[attrRange].foregroundColor = Color(red: 0.86, green: 0.9, blue: 1)
            result[attrRange].underlineStyle = .single
        }
        return result
    }
}

// MARK: - Timeline

struct TimelineBar: View {
    @EnvironmentObject var engine: Engine
    @State private var draggingHandle = false

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height - 132 - 112
            ZStack(alignment: .topTrailing) {
                Color.clear
                Text(engine.dateText.isEmpty ? "—" : engine.dateText)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(red: 0.09, green: 0.095, blue: 0.24))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.96), in: Capsule())
                    .shadow(color: Color(red: 0.03, green: 0.03, blue: 0.16).opacity(draggingHandle ? 0.34 : 0.2), radius: draggingHandle ? 15 : 12, y: 8)
                    .scaleEffect(draggingHandle ? 1.06 : 1)
                    .offset(x: draggingHandle ? -72 : 0)
                    .animation(.easeOut(duration: 0.16), value: draggingHandle)
                    .offset(y: 132 + height * engine.handleTopPercent / 100 - 17)
                    .padding(.trailing, 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !draggingHandle {
                                    draggingHandle = true
                                    engine.timelineDragBegan()
                                }
                                engine.timelineDragChanged(offsetY: value.translation.height, height: height)
                            }
                            .onEnded { _ in
                                draggingHandle = false
                                engine.timelineDragEnded()
                            }
                    )
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Menu d'échelle

struct ScaleMenu: View {
    @EnvironmentObject var engine: Engine
    @Binding var open: Bool
    private let options: [(String, String, Double)] = [
        ("Heure", "H", 4.2), ("Jour", "J", 100), ("Mois", "M", 3044), ("Année", "A", 36525),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(options, id: \.1) { option in
                let active = engine.scaleShort == option.1
                Button {
                    engine.setDayRange(option.2, short: option.1)
                    withAnimation(.easeOut(duration: 0.16)) { open = false }
                } label: {
                    Text(option.0)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(active ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.68))
                        .frame(minWidth: 92, alignment: .leading)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(active ? Color(red: 0.96, green: 0.95, blue: 1) : .clear, in: RoundedRectangle(cornerRadius: 15))
                }
            }
        }
        .padding(5)
        .background(GlassStyle.panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(GlassStyle.border, lineWidth: 1))
        .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
    }
}
