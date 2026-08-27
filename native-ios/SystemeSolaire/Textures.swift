import UIKit

// Textures procédurales : port du canvas 2D du prototype (repli hors ligne),
// puis vraies cartes équirectangulaires téléchargées quand le réseau répond.

struct SeededRandom {
    private var seed: UInt32
    init(name: String) {
        seed = name.utf16.reduce(UInt32(1)) { $0 &+ UInt32($1) }
    }
    mutating func next() -> Double {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Double(seed) / 4_294_967_296
    }
}

func uiColor(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

/// Le dégradé des listes de l'explorateur, et sa seule définition.
///
/// Une pastille ne porte plus la couleur propre de l'objet mais son rang dans
/// la liste : chacune reste un aplat qu'on peut nommer, et la liste entière se
/// lit comme un seul ruban, ce qui donne au défilement une direction. La scène
/// s'accorde à la même règle — trace, maquette et anneau d'un objet prennent la
/// couleur de sa pastille — sinon la liste et le ciel parleraient deux langues.
///
/// Le ruban reste dans la famille de l'écran : menthe des valeurs, lavande des
/// panneaux, orchidée en fin de course. Pas un arc-en-ciel de plus.
enum RampPalette {
    private static let stops: [(r: Double, g: Double, b: Double)] = [
        (0.49, 0.92, 0.82), (0.56, 0.82, 1.00), (0.73, 0.71, 1.00), (0.91, 0.66, 0.94),
    ]

    /// `position` : 0 pour la première ligne, 1 pour la dernière.
    static func rgb(at position: Double) -> (r: Double, g: Double, b: Double) {
        let t = min(max(position, 0), 1) * Double(stops.count - 1)
        let low = min(Int(t), stops.count - 2)
        let f = t - Double(low)
        let a = stops[low], b = stops[low + 1]
        return (a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f)
    }

    static func uiColor(at position: Double, alpha: CGFloat = 1) -> UIColor {
        let c = rgb(at: position)
        return UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: alpha)
    }

    /// Place d'une ligne dans le ruban. Une liste d'un seul élément prend le
    /// départ plutôt qu'une division par zéro.
    static func position(_ index: Int, of count: Int) -> Double {
        count > 1 ? Double(index) / Double(count - 1) : 0
    }
}

enum ProceduralTexture {
    static func surface(for b: PlanetSpec) -> UIImage {
        let w: CGFloat = 256, h: CGFloat = 128
        var rnd = SeededRandom(name: b.name)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: {
            let f = UIGraphicsImageRendererFormat()
            f.scale = 1
            return f
        }())
        return renderer.image { rendererCtx in
            let ctx = rendererCtx.cgContext
            ctx.setFillColor(uiColor(b.color).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            switch b.name {
            case "Terre":
                let colors = [uiColor(0x78b9df).cgColor, uiColor(0x2774aa).cgColor, uiColor(0x164b7c).cgColor]
                let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 0.5, 1])!
                ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
                for _ in 0..<22 {
                    ctx.saveGState()
                    ctx.translateBy(x: rnd.next() * w, y: 18 + rnd.next() * (h - 36))
                    ctx.rotate(by: (rnd.next() - 0.5) * 1.4)
                    ctx.scaleBy(x: 1.8 + rnd.next() * 2, y: 0.5 + rnd.next())
                    let radius = 5 + rnd.next() * 10
                    let land = rnd.next() > 0.4 ? uiColor(0x83a66f) : uiColor(0xb5a77a)
                    ctx.setFillColor(land.withAlphaComponent(0.72).cgColor)
                    ctx.fillEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
                    ctx.restoreGState()
                }
                ctx.setFillColor(uiColor(0xeef5f7, alpha: 0.72).cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: w, height: 8))
                ctx.fill(CGRect(x: 0, y: h - 7, width: w, height: 7))
            case "Jupiter", "Saturne":
                let isJupiter = b.name == "Jupiter"
                var y: CGFloat = 0
                while y < h {
                    let light = 0.08 + 0.12 * sin(Double(y) * 0.22) + rnd.next() * 0.07
                    let base = isJupiter ? (126.0, 78.0, 55.0) : (172.0, 135.0, 83.0)
                    ctx.setFillColor(UIColor(red: base.0 / 255, green: base.1 / 255, blue: base.2 / 255, alpha: max(0.04, light)).cgColor)
                    ctx.fill(CGRect(x: 0, y: y, width: w, height: 3 + rnd.next() * 4))
                    y += 5
                }
                if isJupiter {
                    ctx.saveGState()
                    ctx.translateBy(x: 190, y: 78)
                    ctx.scaleBy(x: 2.2, y: 0.7)
                    ctx.setFillColor(UIColor(red: 174 / 255, green: 79 / 255, blue: 54 / 255, alpha: 0.72).cgColor)
                    ctx.fillEllipse(in: CGRect(x: -9, y: -9, width: 18, height: 18))
                    ctx.restoreGState()
                }
            case "Uranus", "Neptune":
                let colors = [UIColor(white: 1, alpha: 0.22).cgColor, UIColor(white: 1, alpha: 0).cgColor, uiColor(0x181d70, alpha: 0.2).cgColor]
                let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 0.45, 1])!
                ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
                var y: CGFloat = 8
                while y < h {
                    ctx.setFillColor(UIColor(white: 1, alpha: 0.045).cgColor)
                    ctx.fill(CGRect(x: 0, y: y, width: w, height: 2))
                    y += 12
                }
            case "Vénus":
                for _ in 0..<34 {
                    ctx.setStrokeColor(UIColor(red: 1, green: 241 / 255, blue: 194 / 255, alpha: 0.035 + rnd.next() * 0.08).cgColor)
                    ctx.setLineWidth(2 + rnd.next() * 5)
                    let y = rnd.next() * h
                    ctx.move(to: CGPoint(x: -20, y: y))
                    ctx.addCurve(
                        to: CGPoint(x: w + 20, y: y),
                        control1: CGPoint(x: 55, y: y - 25 + rnd.next() * 50),
                        control2: CGPoint(x: 170, y: y - 25 + rnd.next() * 50)
                    )
                    ctx.strokePath()
                }
            default:
                for _ in 0..<420 {
                    let v: CGFloat = rnd.next() > 0.5 ? 1 : 25 / 255
                    ctx.setFillColor(UIColor(red: v, green: v, blue: v, alpha: 0.018 + rnd.next() * 0.065).cgColor)
                    let s = 0.4 + rnd.next() * 2.6
                    ctx.fill(CGRect(x: rnd.next() * w, y: rnd.next() * h, width: s, height: s))
                }
                for _ in 0..<18 {
                    let radius = 1 + rnd.next() * 5
                    ctx.setStrokeColor(uiColor(0x23181f, alpha: 0.12).cgColor)
                    ctx.setLineWidth(1 + rnd.next() * 2)
                    ctx.strokeEllipse(in: CGRect(x: rnd.next() * w - radius, y: rnd.next() * h - radius, width: radius * 2, height: radius * 2))
                }
            }
        }
    }

    /// Pastille lumineuse pour les constellations : dégradé radial, pas de modèle 3D
    /// Panache de moteur : u = le long de la traînée (transparent au pas de tir,
    /// vif sous la fusée), v = travers du ruban (bords fondus).
    static func flameSprite() -> UIImage {
        let w = 128, h = 32
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            let v = (Double(y) + 0.5) / Double(h)
            let across = pow(max(0, 1 - abs(2 * v - 1)), 1.7)
            for x in 0..<w {
                let u = (Double(x) + 0.5) / Double(w)
                let alpha = pow(u, 1.6) * across
                // prémultiplié : blanc pur, la teinte vient du `multiply` du matériau
                let value = UInt8(max(0, min(255, alpha * 255)))
                let i = (y * w + x) * 4
                pixels[i] = value; pixels[i + 1] = value; pixels[i + 2] = value; pixels[i + 3] = value
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cg = CGImage(
                width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              )
        else { return UIImage() }
        return UIImage(cgImage: cg)
    }

    static func dotSprite() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: {
            let f = UIGraphicsImageRendererFormat()
            f.scale = 1
            return f
        }())
        return renderer.image { rendererCtx in
            let ctx = rendererCtx.cgContext
            let colors = [
                UIColor(white: 1, alpha: 1).cgColor,
                UIColor(white: 1, alpha: 0.9).cgColor,
                UIColor(white: 1, alpha: 0.3).cgColor,
                UIColor(white: 1, alpha: 0).cgColor,
            ]
            let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 0.22, 0.5, 1])!
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 32, y: 32), startRadius: 0, endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
    }
}

// MARK: - Vraies textures (CDN), avec cache disque

final class TextureLoader {
    static let shared = TextureLoader()
    static let base = "https://cdn.jsdelivr.net/gh/jeromeetienne/threex.planets@master/images/"
    static let planetMaps: [String: String] = [
        "Mercure": "mercurymap.jpg", "Vénus": "venusmap.jpg", "Mars": "marsmap1k.jpg",
        "Jupiter": "jupitermap.jpg", "Saturne": "saturnmap.jpg", "Uranus": "uranusmap.jpg", "Neptune": "neptunemap.jpg",
    ]
    static let earthURL = "https://cdn.jsdelivr.net/gh/mrdoob/three.js@r160/examples/textures/planets/earth_atmos_2048.jpg"

    private var cacheDir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("maps")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Ordre : textures livrées dans le bundle → cache disque → CDN.
    func load(_ urlString: String, apply: @escaping (UIImage) -> Void) {
        guard let url = URL(string: urlString) else { return }
        if let image = Self.bundled(url.lastPathComponent) {
            apply(image)
            return
        }
        let local = cacheDir.appendingPathComponent(url.lastPathComponent)
        if let data = try? Data(contentsOf: local), let image = UIImage(data: data) {
            apply(Self.normalized(image))
            return
        }
        Task.detached(priority: .utility) {
            guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { return }
            try? data.write(to: local)
            let safe = Self.normalized(image)
            await MainActor.run { apply(safe) }
        }
    }

    /// Les .jpg de `Textures/` sont copiés à plat dans le bundle par Xcode ;
    /// on tente quand même le sous-dossier au cas où il resterait une référence de dossier.
    private static func bundled(_ fileName: String) -> UIImage? {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext)
                ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Textures"),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        return normalized(image)
    }

    /// Certaines cartes (niveaux de gris, CMJN…) donnent un format de pixel que Metal refuse :
    /// on redessine tout en RGBA standard.
    static func normalized(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
