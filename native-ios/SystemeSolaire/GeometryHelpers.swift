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
    /// Polyligne (line strip) — équivalent de THREE.Line
    static func lineGeometry(points: [SIMD3<Double>], color: UIColor, additive: Bool = false) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }
        let vertices = points.map { SCNVector3($0) }
        let source = SCNGeometrySource(vertices: vertices)
        var indices: [Int32] = []
        indices.reserveCapacity((points.count - 1) * 2)
        for i in 0..<(points.count - 1) {
            indices.append(Int32(i)); indices.append(Int32(i + 1))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        if additive { material.blendMode = .add }
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
