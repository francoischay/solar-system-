import SceneKit
import simd

extension SCNVector3 {
    init(_ v: SIMD3<Double>) { self.init(Float(v.x), Float(v.y), Float(v.z)) }
    var simd3: SIMD3<Double> { SIMD3(Double(x), Double(y), Double(z)) }
}

extension SCNQuaternion {
    init(_ q: simd_quatd) { self.init(Float(q.imag.x), Float(q.imag.y), Float(q.imag.z), Float(q.real)) }
}

enum Geo {
    /// Polyligne (line strip) — équivalent de THREE.Line.
    /// Avec `texture`, chaque sommet reçoit u = progression le long de la ligne
    /// (v au centre) : la teinte et l'alpha suivent alors le dégradé de l'image.
    static func lineGeometry(points: [SIMD3<Double>], color: UIColor, additive: Bool = false,
                             texture: UIImage? = nil) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }
        let vertices = points.map { SCNVector3($0) }
        var sources = [SCNGeometrySource(vertices: vertices)]
        if texture != nil {
            let uvs = (0..<points.count).map {
                CGPoint(x: CGFloat($0) / CGFloat(points.count - 1), y: 0.5)
            }
            sources.append(SCNGeometrySource(textureCoordinates: uvs))
        }
        var indices: [Int32] = []
        indices.reserveCapacity((points.count - 1) * 2)
        for i in 0..<(points.count - 1) {
            indices.append(Int32(i)); indices.append(Int32(i + 1))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: sources, elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        if let texture {
            material.diffuse.contents = texture
            material.diffuse.wrapS = .clamp
            material.diffuse.wrapT = .clamp
            material.multiply.contents = color
        } else {
            material.diffuse.contents = color
        }
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        if additive { material.blendMode = .add }
        geometry.materials = [material]
        return geometry
    }

    /// Ruban tourné vers la caméra (panache de moteur) : deux sommets par point,
    /// u = progression le long de la traînée, v = travers du ruban. La largeur
    /// est donnée point par point, la texture porte le dégradé vers le transparent.
    static func ribbonGeometry(points: [SIMD3<Double>], halfWidths: [Double],
                               viewPoint: SIMD3<Double>, color: UIColor, texture: UIImage) -> SCNGeometry? {
        guard points.count >= 2, halfWidths.count == points.count else { return nil }
        var vertices: [SCNVector3] = [], uvs: [CGPoint] = []
        vertices.reserveCapacity(points.count * 2)
        uvs.reserveCapacity(points.count * 2)
        var previousSide = SIMD3<Double>(0, 1, 0)
        for (i, p) in points.enumerated() {
            var tangent = points[min(i + 1, points.count - 1)] - points[max(i - 1, 0)]
            if simd_length_squared(tangent) < 1e-12 { tangent = SIMD3(0, 1, 0) }
            // Le ruban se tourne vers l'œil : il garde son épaisseur sous tous les angles.
            var side = simd_cross(simd_normalize(tangent), viewPoint - p)
            if simd_length_squared(side) < 1e-12 { side = previousSide } else { side = simd_normalize(side) }
            previousSide = side
            let u = CGFloat(i) / CGFloat(points.count - 1)
            vertices.append(SCNVector3(p - side * halfWidths[i]))
            vertices.append(SCNVector3(p + side * halfWidths[i]))
            uvs.append(CGPoint(x: u, y: 0))
            uvs.append(CGPoint(x: u, y: 1))
        }
        var indices: [Int32] = []
        indices.reserveCapacity((points.count - 1) * 6)
        for i in 0..<(points.count - 1) {
            let o = Int32(i * 2)
            indices.append(contentsOf: [o, o + 1, o + 2, o + 2, o + 1, o + 3])
        }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(textureCoordinates: uvs)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = texture
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.multiply.contents = color
        material.blendMode = .add
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        geometry.materials = [material]
        return geometry
    }

    /// Nuage de points — équivalent de THREE.Points
    static func pointsGeometry(points: [SIMD3<Double>], color: UIColor, sprite: UIImage? = nil,
                               pointSize: CGFloat, minScreenRadius: CGFloat, maxScreenRadius: CGFloat,
                               additive: Bool = false) -> SCNGeometry {
        let vertices = points.map { SCNVector3($0) }
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: (0..<Int32(points.count)).map { $0 }, primitiveType: .point)
        element.pointSize = pointSize
        element.minimumPointScreenSpaceRadius = minScreenRadius
        element.maximumPointScreenSpaceRadius = maxScreenRadius
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = sprite ?? color
        if sprite != nil { material.multiply.contents = color }
        material.writesToDepthBuffer = false
        if additive { material.blendMode = .add }
        geometry.materials = [material]
        return geometry
    }

    /// Anneau plat à UV radiales (bande d'anneaux de Saturne)
    static func ringGeometry(inner: Double, outer: Double, segments: Int) -> SCNGeometry {
        var vertices: [SCNVector3] = [], uvs: [CGPoint] = [], normals: [SCNVector3] = []
        var indices: [Int32] = []
        for i in 0...segments {
            let a = Double(i) / Double(segments) * Astro.TAU
            let c = cos(a), s = sin(a)
            vertices.append(SCNVector3(Float(c * inner), 0, Float(s * inner)))
            vertices.append(SCNVector3(Float(c * outer), 0, Float(s * outer)))
            // UV radiales : u = position dans la bande, la division de Cassini apparaît
            uvs.append(CGPoint(x: 0, y: 0.5))
            uvs.append(CGPoint(x: 1, y: 0.5))
            normals.append(SCNVector3(0, 1, 0)); normals.append(SCNVector3(0, 1, 0))
        }
        for i in 0..<segments {
            let o = Int32(i * 2)
            indices.append(contentsOf: [o, o + 1, o + 2, o + 2, o + 1, o + 3])
        }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        return geometry
    }

    /// Sphère avec le mapping UV de THREE.SphereGeometry : x = -r·cosφ·sinθ, y = r·cosθ, z = r·sinφ·sinθ.
    /// Indispensable pour que lat/lon (geoToLocal), pas de tir et trace au sol tombent juste sur la texture.
    static func sphereGeometry(radius: Double, widthSegments: Int = 40, heightSegments: Int = 28) -> SCNGeometry {
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], uvs: [CGPoint] = []
        var indices: [Int32] = []
        for iy in 0...heightSegments {
            let v = Double(iy) / Double(heightSegments)
            let theta = v * .pi
            for ix in 0...widthSegments {
                let u = Double(ix) / Double(widthSegments)
                let phi = u * Astro.TAU
                let p = SIMD3(-cos(phi) * sin(theta), cos(theta), sin(phi) * sin(theta))
                vertices.append(SCNVector3(p * radius))
                normals.append(SCNVector3(p))
                uvs.append(CGPoint(x: u, y: v))
            }
        }
        let stride = widthSegments + 1
        for iy in 0..<heightSegments {
            for ix in 0..<widthSegments {
                let a = Int32(iy * stride + ix), b = a + 1
                let c = a + Int32(stride), d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    /// Anneau dans le plan XY, pour un liseré d'atmosphère face à la caméra.
    ///
    /// Deux différences avec `ringGeometry`, et elles comptent toutes les deux.
    /// Le plan est XY et non XZ : l'anneau est fait pour être tourné vers l'oeil,
    /// pas posé à plat autour d'une planète. Et `v` porte l'angle le long du
    /// cercle au lieu d'une constante — c'est ce qui permet d'éteindre le liseré
    /// du côté nuit. `u` reste le radial, de 0 au bord intérieur à 1 au bord
    /// extérieur. `v = 0` tombe sur +X : c'est de ce côté qu'on met le Soleil.
    static func limbRing(inner: Double, outer: Double, segments: Int = 96) -> SCNGeometry {
        var vertices: [SCNVector3] = [], uvs: [CGPoint] = [], normals: [SCNVector3] = []
        var indices: [Int32] = []
        for i in 0...segments {
            let v = Double(i) / Double(segments)
            let a = v * Astro.TAU
            let c = cos(a), sn = sin(a)
            vertices.append(SCNVector3(Float(c * inner), Float(sn * inner), 0))
            vertices.append(SCNVector3(Float(c * outer), Float(sn * outer), 0))
            uvs.append(CGPoint(x: 0, y: v)); uvs.append(CGPoint(x: 1, y: v))
            normals.append(SCNVector3(0, 0, 1)); normals.append(SCNVector3(0, 0, 1))
        }
        for i in 0..<segments {
            let o = Int32(i * 2)
            indices.append(contentsOf: [o, o + 1, o + 2, o + 2, o + 1, o + 3])
        }
        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    /// Calotte sphérique centrée sur +Y, posée sur une sphère de ce rayon.
    /// Sert à peindre une tache *sur* le globe : une pastille plate flotterait
    /// au-dessus, et l'ombre d'une éclipse couvre un tiers du disque terrestre.
    /// L'UV est radiale — u va de 0 au centre à 1 au bord — pour qu'un dégradé
    /// horizontal s'y enroule en cercle.
    static func sphericalCap(radius: Double, halfAngle: Double,
                             rings: Int = 14, segments: Int = 48) -> SCNGeometry {
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], uvs: [CGPoint] = []
        var indices: [Int32] = []
        for iy in 0...rings {
            let v = Double(iy) / Double(rings)
            let theta = v * halfAngle
            for ix in 0...segments {
                let phi = Double(ix) / Double(segments) * Astro.TAU
                // Même main que `sphereGeometry` — le signe de x compte : à
                // l'envers, l'enroulement des triangles s'inverse et la calotte
                // n'est plus visible que de l'intérieur du globe.
                let p = SIMD3(-sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
                vertices.append(SCNVector3(p * radius))
                normals.append(SCNVector3(p))
                uvs.append(CGPoint(x: v, y: 0.5))
            }
        }
        let stride = segments + 1
        for iy in 0..<rings {
            for ix in 0..<segments {
                let a = Int32(iy * stride + ix), b = a + 1
                let c = a + Int32(stride), d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    /// Octaèdre (maquette de sonde)
    static func octahedron(radius: Float) -> SCNGeometry {
        let r = radius
        let vertices: [SCNVector3] = [
            SCNVector3(r, 0, 0), SCNVector3(-r, 0, 0),
            SCNVector3(0, r, 0), SCNVector3(0, -r, 0),
            SCNVector3(0, 0, r), SCNVector3(0, 0, -r),
        ]
        let indices: [Int32] = [
            0, 2, 4, 0, 4, 3, 0, 3, 5, 0, 5, 2,
            1, 4, 2, 1, 3, 4, 1, 5, 3, 1, 2, 5,
        ]
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [source], elements: [element])
    }
}

/// Traînée : ligne dont la géométrie est reconstruite à la volée (équivalent du buffer dynamique Three.js)
final class TrailLine {
    let node = SCNNode()
    private let color: UIColor
    private let additive: Bool

    init(color: UIColor, additive: Bool = true) {
        self.color = color
        self.additive = additive
        node.isHidden = true
        node.castsShadow = false
    }

    func update(points: [SIMD3<Double>], opacity: Double) {
        guard opacity > 0.006, points.count >= 2 else {
            node.isHidden = true
            return
        }
        node.geometry = Geo.lineGeometry(points: points, color: color, additive: additive)
        node.opacity = CGFloat(opacity)
        node.isHidden = false
    }
}
