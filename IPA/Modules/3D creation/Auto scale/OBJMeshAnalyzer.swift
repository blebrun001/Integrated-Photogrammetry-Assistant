//  OBJMeshAnalyzer.swift
//  OBJ parsing and UV-region distance measurement for Auto Scale.

import Foundation
import CoreGraphics
import simd

final class OBJMeshAnalyzer {
    struct Candidate {
        let vertex: SIMD3<Double>
        let uv: SIMD2<Double>
    }

    func measureDistance(objURL: URL, boundingBox: CGRect, textureSize: CGSize, corners: [CGPoint] = []) throws -> AutoScaleMeasurement {
        let mesh = try parseMesh(at: objURL)

        let width = Double(textureSize.width)
        let height = Double(textureSize.height)

        guard width > 0, height > 0 else { throw AutoScaleError.noVerticesInRegion }
        if corners.count == 4 {
            let uv = corners.map { SIMD2<Double>($0.x / width, $0.y / height) }
            let points = uv.compactMap { surfacePoint(at: $0, in: mesh) }
            guard points.count == 4 else { throw AutoScaleError.noVerticesInRegion }
            let diagonal = ((points[0] - points[2]).length + (points[1] - points[3]).length) / 2
            return AutoScaleMeasurement(distance: diagonal, uv1: uv[0], uv2: uv[2])
        }
        let uMin = Double(boundingBox.minX) / width
        let uMax = Double(boundingBox.maxX) / width
        let vMin = Double(boundingBox.minY) / height
        let vMax = Double(boundingBox.maxY) / height

        let candidates = collectCandidates(mesh: mesh, uMin: uMin, uMax: uMax, vMin: vMin, vMax: vMax)
        guard candidates.count >= 2 else {
            throw AutoScaleError.noVerticesInRegion
        }

        var maxDistance: Double = 0
        var bestPair: (SIMD2<Double>, SIMD2<Double>)?

        for i in 0..<(candidates.count - 1) {
            for j in (i + 1)..<candidates.count {
                let v1 = candidates[i].vertex
                let v2 = candidates[j].vertex
                let distance = (v1 - v2).length
                if distance > maxDistance {
                    maxDistance = distance
                    bestPair = (candidates[i].uv, candidates[j].uv)
                }
            }
        }

        return AutoScaleMeasurement(distance: maxDistance, uv1: bestPair?.0, uv2: bestPair?.1)
    }

    // Locate each detected marker corner inside a UV triangle, even on a coarse mesh.
    private func surfacePoint(at point: SIMD2<Double>, in mesh: OBJMesh) -> SIMD3<Double>? {
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
        for face in mesh.faces where face.vertexIndices.count >= 3 && face.vertexIndices.count == face.textureIndices.count {
            for i in 1..<(face.vertexIndices.count - 1) {
                let indices = [0, i, i + 1]
                let tex = indices.compactMap { face.textureIndices[$0] }
                let vertices = indices.map { face.vertexIndices[$0] }
                guard tex.count == 3, tex.allSatisfy(mesh.texcoords.indices.contains),
                      vertices.allSatisfy(mesh.vertices.indices.contains) else { continue }
                let origin = mesh.texcoords[tex[0]]
                let u = mesh.texcoords[tex[1]] - origin, v = mesh.texcoords[tex[2]] - origin
                let determinant = cross(u,v)
                guard abs(determinant) > 1e-15 else { continue }
                let b = cross(point-origin,v) / determinant, c = cross(u,point-origin) / determinant
                if b >= -1e-7, c >= -1e-7, b+c <= 1.0000001 {
                    return mesh.vertices[vertices[0]]*(1-b-c) + mesh.vertices[vertices[1]]*b + mesh.vertices[vertices[2]]*c
                }
            }
        }
        return nil
    }

    func parseMesh(at url: URL) throws -> OBJMesh {
        let content = try String(contentsOf: url, encoding: .utf8)
        var vertices: [SIMD3<Double>] = []
        var texcoords: [SIMD2<Double>] = []
        var faces: [OBJFace] = []

        let lines = content.split(whereSeparator: { $0.isNewline })
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("v ") {
                let components = line.split(separator: " ")
                guard components.count >= 4,
                      let x = Double(components[1]),
                      let y = Double(components[2]),
                      let z = Double(components[3]) else { continue }
                vertices.append(SIMD3<Double>(x, y, z))
            } else if line.hasPrefix("vt ") {
                let components = line.split(separator: " ")
                guard components.count >= 3,
                      let u = Double(components[1]),
                      let v = Double(components[2]) else { continue }
                texcoords.append(SIMD2<Double>(u, v))
            } else if line.hasPrefix("f ") {
                let tokens = line.split(separator: " ").dropFirst()
                var vertexIndices: [Int] = []
                var textureIndices: [Int?] = []
                for token in tokens {
                    let parts = token.split(separator: "/", omittingEmptySubsequences: false)
                    if let first = parts.first, let vIndex = Int(first) {
                        vertexIndices.append(vIndex < 0 ? vertices.count + vIndex : vIndex - 1)
                    }
                    if parts.indices.contains(1), let tIndex = Int(parts[1]), tIndex != 0 {
                        textureIndices.append(tIndex < 0 ? texcoords.count + tIndex : tIndex - 1)
                    } else {
                        textureIndices.append(nil)
                    }
                }
                faces.append(OBJFace(vertexIndices: vertexIndices, textureIndices: textureIndices))
            }
        }

        return OBJMesh(vertices: vertices, texcoords: texcoords, faces: faces)
    }

    private func collectCandidates(mesh: OBJMesh, uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> [Candidate] {
        var candidates: [Candidate] = []
        for face in mesh.faces {
            for (vertexIndex, texIndex) in zip(face.vertexIndices, face.textureIndices) {
                guard let texIndex else { continue }
                guard mesh.vertices.indices.contains(vertexIndex), mesh.texcoords.indices.contains(texIndex) else { continue }
                let uv = mesh.texcoords[texIndex]
                if uv.x >= uMin && uv.x <= uMax && uv.y >= vMin && uv.y <= vMax {
                    let vertex = mesh.vertices[vertexIndex]
                    candidates.append(Candidate(vertex: vertex, uv: uv))
                }
            }
        }
        return candidates
    }
}

struct OBJMesh {
    let vertices: [SIMD3<Double>]
    let texcoords: [SIMD2<Double>]
    let faces: [OBJFace]
}

struct OBJFace {
    let vertexIndices: [Int]
    let textureIndices: [Int?]
}
