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
                    if engine.crewedSelection != nil, engine.exploreView == .none {
                        PlaybackBar()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
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
                .font(TypeScale.label)
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
        let groupWidth = min(availableWidth, DockMetrics.maxGroupWidth)
        let compactWidth = max(120, groupWidth - DockMetrics.sideInset)
        let sheetWidth = compactWidth + (groupWidth - compactWidth) * progress
        let iconScale = 1 - progress * 0.75

        return ZStack(alignment: .bottom) {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        engine.setExploreView(engine.exploreView == .none ? engine.lastExploreSection : .none)
                    }
                    scaleMenuOpen = false
                } label: {
                    Text(viewGlyph)
                        .font(TypeScale.glyph)
                        .foregroundStyle(engine.exploreView != .none ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.9))
                        .frame(width: DockMetrics.height, height: DockMetrics.height)
                        .background(engine.exploreView != .none ? AnyShapeStyle(Color(red: 0.96, green: 0.95, blue: 1)) : AnyShapeStyle(GlassStyle.fill), in: Circle())
                        .overlay(Circle().strokeBorder(GlassStyle.border, lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())

                Spacer()

                Button {
                    scaleMenuOpen ? Haptics.shared.closed() : Haptics.shared.opened()
                    withAnimation(.easeOut(duration: 0.16)) { scaleMenuOpen.toggle() }
                } label: {
                    Text(engine.scaleShort)
                        // Une valeur, pas un pictogramme : elle se lit en corps de
                        // libellé, sinon les deux cercles se ressemblent trop.
                        .font(TypeScale.label)
                        .foregroundStyle(scaleMenuOpen ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.9))
                        .frame(width: DockMetrics.height, height: DockMetrics.height)
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
                expandedWidth: groupWidth,
                expansionProgress: $dockExpansionProgress
            )
            .frame(width: sheetWidth)
        }
        .frame(width: groupWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var viewGlyph: String {
        switch engine.exploreView {
        case .none: return "◎"
        case .missions: return "✦"
        case .crewed: return "☾"
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

/// Quatre crans, deux graisses. Neuf tailles circulaient auparavant, dont des
/// écarts d'un demi-point (11,5 vs 12) qui ne se voient pas : ce n'était pas une
/// échelle, c'était de la dérive. Tout ce qui vivait entre deux crans a choisi.
enum TypeScale {
    static let title = Font.system(size: 17, weight: .semibold)   // titre du cartouche
    static let glyph = Font.system(size: 17, weight: .semibold)   // pictogrammes
    static let row = Font.system(size: 15, weight: .semibold)     // nom dans une liste
    static let body = Font.system(size: 15)                       // texte courant
    static let label = Font.system(size: 13, weight: .semibold)   // onglets, boutons, valeurs
    static let tag = Font.system(size: 11, weight: .semibold)     // étiquettes sur la scène
    static let meta = Font.system(size: 11)                       // métadonnées
}

/// Anatomie commune aux lignes de l'explorateur : même hauteur, même rayon, même
/// pastille, quel que soit l'onglet.
enum RowStyle {
    static let minHeight: CGFloat = 48
    static let radius: CGFloat = 14
    static let chip: CGFloat = 34
    static let gap: CGFloat = 11
    static let idleFill = Color(red: 0.043, green: 0.05, blue: 0.2).opacity(0.28)
    static let selectedFill = Color(red: 0.62, green: 0.6, blue: 1).opacity(0.2)
    static let selectedBorder = Color(red: 0.78, green: 0.79, blue: 1).opacity(0.75)
    static let meta = Color.white.opacity(0.62)
}

/// Le dock est une rangée : les deux cercles et le cartouche replié partagent
/// une hauteur unique, sinon rien ne s'aligne. Les cercles restent des cercles,
/// c'est donc leur diamètre qui suit.
enum DockMetrics {
    static let height: CGFloat = 58
    /// Place à réserver de part et d'autre du cartouche : deux cercles et leurs gouttières
    static let sideInset: CGFloat = height * 2 + 20
    /// Sur iPad le dock ne s'étire pas jusqu'aux bords : au-delà, le cartouche
    /// devient une barre et les deux boutons partent aux antipodes.
    static let maxGroupWidth: CGFloat = 560
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
                    .font(TypeScale.tag)
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
    /// Largeur qu'aura le cartouche une fois déplié — le paragraphe doit être
    /// mesuré à cette largeur-là. Mesuré replié, il tenait sur sept lignes au
    /// lieu de cinq et réservait la place de deux lignes fantômes.
    let expandedWidth: CGFloat
    @Binding var expansionProgress: CGFloat
    @State private var detailExpanded = false
    @State private var sheetHeight: CGFloat = 58
    @State private var detailHeight: CGFloat = 0
    @State private var dragStartHeight: CGFloat?
    @State private var isDragging = false

    private let minHeight: CGFloat = DockMetrics.height

    private var clampedMaxHeight: CGFloat { max(minHeight, maxHeight) }
    /// Le cartouche se calait sur la moitié de l'écran quel que soit son texte —
    /// six lignes pour la Terre, et le reste en vide. Il prend maintenant la
    /// hauteur de son contenu, sans dépasser la moitié.
    private var expandedHeight: CGFloat {
        detailHeight > 1 ? min(clampedMaxHeight, minHeight + detailHeight) : clampedMaxHeight
    }
    var body: some View {
        let progress = expansionProgress
        let cornerRadius = 29 - progress * 7
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(spacing: 0) {
            sheetHeader
            if let detail = engine.selectionDetail {
                ScrollView {
                    Text(DateLinker.attributed(detail))
                    .font(TypeScale.body)
                    .lineSpacing(4.5)
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
        // Exemplaire caché du paragraphe, mesuré à hauteur libre. Mesurer le vrai
        // texte ne marche pas : il vit dans une ScrollView dont la hauteur découle
        // de la mesure, et les deux se poursuivent jusqu'à un équilibre trop haut.
        .background(detailProbe.hidden())
        .onPreferenceChange(DetailHeightKey.self) { detailHeight = $0 }
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
        // La zone libre change avec le texte : la scène doit savoir où recentrer.
        // +8 pour la marge basse du dock, qui appartient à la zone occupée.
        .onChange(of: expandedHeight, initial: true) {
            engine.setDetailCoverage(Double((expandedHeight + 8) / max(1, maxHeight * 2)))
        }
        .onChange(of: maxHeight) {
            guard detailExpanded else { return }
            withAnimation(.spring(duration: 0.32, bounce: 0)) {
                sheetHeight = expandedHeight
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
                    .font(TypeScale.title)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(TypeScale.label)
                    .foregroundStyle(.white.opacity(0.62))
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
                        // Le chevron montre où va le contenu, pas d'où il vient :
                        // vers le haut quand il reste à déplier, vers le bas quand
                        // il ne reste qu'à refermer. C'était l'inverse.
                        Image(systemName: "chevron.up")
                            .font(TypeScale.tag)
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

    /// Panneau ouvert, la capsule affichait encore « Explorer les orbites » alors
    /// qu'on choisissait une sonde : la plus large zone de l'écran portait
    /// l'information la plus périmée.
    private var subtitle: String {
        switch engine.exploreView {
        case .none: return engine.selectionSub
        case .missions: return "Choisir une sonde"
        case .crewed: return "Choisir un vol habité"
        case .satellites: return "Choisir un satellite"
        case .launches: return "Choisir un lancement"
        }
    }

    @ViewBuilder private var detailProbe: some View {
        if let detail = engine.selectionDetail {
            Text(DateLinker.attributed(detail))
                .font(TypeScale.body)
                .lineSpacing(4.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .frame(width: max(120, expandedWidth))
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: DetailHeightKey.self, value: proxy.size.height)
                })
        }
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
        if shouldExpand != detailExpanded {
            shouldExpand ? Haptics.shared.opened() : Haptics.shared.closed()
        }
        detailExpanded = shouldExpand
        withAnimation(.spring(duration: 0.32, bounce: 0)) {
            sheetHeight = shouldExpand ? expandedHeight : minHeight
            expansionProgress = shouldExpand ? 1 : 0
        }
        engine.setDetailExpansionProgress(shouldExpand ? 1 : 0, immediate: false)
    }
}

private struct DetailHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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

// MARK: - Contrôleur de rejeu

/// Barre de transport d'un vol habité, posée juste au-dessus du cartouche.
/// Elle ne paraît que pour un vol habité : c'est le seul objet de la scène qui
/// se *joue* plutôt que de se consulter.
struct PlaybackBar: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        HStack(spacing: 4) {
            button("backward.end.fill", label: "Revenir au décollage") { engine.playbackRestart() }
            button(engine.playbackIsRunning ? "pause.fill" : "play.fill",
                   label: engine.playbackIsRunning ? "Mettre en pause" : "Lire la mission",
                   prominent: true) { engine.playbackToggle() }
            button("forward.end.fill", label: "Aller à la fin") { engine.playbackToEnd() }
            Divider()
                .frame(height: 20)
                .overlay(GlassStyle.border)
                .padding(.horizontal, 3)
            // La vitesse tourne en boucle : trois crans ne méritent pas un menu.
            Button {
                engine.playbackCycleSpeed()
            } label: {
                Text(speedLabel)
                    .font(TypeScale.label)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(minWidth: 38, minHeight: 34)
            }
            .accessibilityLabel("Vitesse de lecture, \(speedLabel)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(GlassStyle.panel, in: Capsule())
        .overlay(Capsule().strokeBorder(GlassStyle.border, lineWidth: 1))
        .frame(maxWidth: .infinity)
        .transition(.scale(scale: 0.94, anchor: .bottomLeading).combined(with: .opacity))
    }

    private var speedLabel: String {
        "×" + (engine.playbackSpeed == rint(engine.playbackSpeed)
               ? String(Int(engine.playbackSpeed))
               : String(format: "%.1f", engine.playbackSpeed)
                   .replacingOccurrences(of: ".", with: ","))
    }

    private func button(_ symbol: String, label: String, prominent: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(TypeScale.label)
                .foregroundStyle(prominent ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.82))
                .frame(width: 34, height: 34)
                .background(prominent ? AnyShapeStyle(Color(red: 0.96, green: 0.95, blue: 1))
                                      : AnyShapeStyle(Color.clear),
                            in: Circle())
        }
        .accessibilityLabel(label)
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
                        .font(TypeScale.label)
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
