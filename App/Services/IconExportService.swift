import UIKit

/// Original geometric glyphs drawn with paths; no system-symbol artwork is exported.
@MainActor
enum IconExportService {
    static let count = 24
    static func export(collection: ThemeCollection) async throws -> URL {
        var files: [(String, Data)] = []
        for index in 0..<count {
            try Task.checkCancellation()
            guard let data = image(index: index, collection: collection, size: 512).pngData() else { throw IconExportError.encoding }
            files.append((String(format: "%02d.png", index + 1), data))
            await Task.yield()
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ScreenMotion-\(collection.rawValue)-\(UUID().uuidString)", isDirectory: true)
        let payload = files
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, data) in payload {
                try Task.checkCancellation()
                try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            }
        }.value
        return directory
    }

    static func image(index: Int, collection: ThemeCollection, size: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { renderer in
            let context = renderer.cgContext
            context.scaleBy(x: size / 100, y: size / 100)
            let accent: UIColor
            switch collection {
            case .vehicles: accent = UIColor(red: 1, green: 0.65, blue: 0.38, alpha: 1)
            case .ocean: accent = UIColor(red: 0.42, green: 0.9, blue: 0.88, alpha: 1)
            case .cosmos: accent = UIColor(red: 0.77, green: 0.65, blue: 1, alpha: 1)
            case .nature: accent = UIColor(red: 0.72, green: 0.9, blue: 0.63, alpha: 1)
            }
            UIColor(red: 0.045, green: 0.06, blue: 0.085, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            let colors = [accent.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.drawRadialGradient(gradient, startCenter: CGPoint(x: 20, y: 10), startRadius: 0, endCenter: CGPoint(x: 50, y: 50), endRadius: 85, options: [])
            }
            accent.setStroke()
            accent.setFill()
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(3)
            func line(_ points: [(CGFloat, CGFloat)], close: Bool = false) {
                guard let first = points.first else { return }
                context.beginPath(); context.move(to: CGPoint(x: first.0, y: first.1))
                for point in points.dropFirst() { context.addLine(to: CGPoint(x: point.0, y: point.1)) }
                if close { context.closePath() }
                context.strokePath()
            }
            func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 5) {
                let path = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
                path.lineWidth = 3; path.stroke()
            }
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
                context.strokeEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
            }
            switch ((index % count) + count) % count {
            case 0: // telephone
                line([(31,27),(25,35),(28,48),(38,61),(52,72),(65,74),(74,65),(63,56),(57,62),(43,53),(36,42),(42,36),(31,27)])
            case 1: box(25,28,50,37,radius: 12); line([(36,65),(31,75),(49,65)]); line([(36,42),(64,42)]); line([(36,52),(54,52)])
            case 2: box(25,32,50,37); line([(27,35),(50,52),(73,35)]); line([(27,66),(40,53)]); line([(73,66),(60,53)])
            case 3: circle(50,50,24); line([(58,35),(55,55),(35,65),(45,45),(58,35)],close:true)
            case 4: box(24,35,52,34); line([(34,35),(39,27),(59,27),(65,35)]); circle(50,51,11); circle(67,42,1)
            case 5: box(25,26,50,48); circle(39,40,5); line([(27,66),(43,50),(54,59),(62,48),(74,61)])
            case 6: line([(42,65),(42,32),(68,27),(68,58)]); line([(43,41),(67,36)]); circle(35,65,7); circle(61,58,7)
            case 7: circle(50,50,13); circle(50,50,5); for a in 0..<8 { let t = Double(a) * .pi / 4; line([(50 + CGFloat(cos(t))*19,50 + CGFloat(sin(t))*19),(50 + CGFloat(cos(t))*25,50 + CGFloat(sin(t))*25)]) }
            case 8: box(27,29,46,46); line([(27,42),(73,42)]); line([(38,24),(38,34)]); line([(62,24),(62,34)]); for y in [51,63] { for x in [38,50,62] { circle(CGFloat(x),CGFloat(y),1) } }
            case 9: circle(50,50,24); line([(50,33),(50,50),(63,57)]); circle(50,50,2)
            case 10: line([(25,32),(41,26),(59,33),(75,27),(75,68),(59,74),(41,67),(25,73)],close:true); line([(41,27),(41,67)]); line([(59,33),(59,73)])
            case 11: circle(41,40,12); box(35,49,39,19,radius:9); line([(41,20),(41,24)]); line([(21,40),(25,40)]); line([(25,24),(29,28)]); line([(56,24),(60,20)])
            case 12: box(29,24,42,52); for y in [39,50,61] { line([(39,CGFloat(y)),(61,CGFloat(y))]) }
            case 13: for y in [34,50,66] { line([(26,CGFloat(y)),(30,CGFloat(y+4)),(37,CGFloat(y-5))]); line([(46,CGFloat(y)),(73,CGFloat(y))]) }
            case 14: line([(25,71),(25,31),(43,31),(49,39),(75,39),(75,71)],close:true); line([(26,47),(74,47)])
            case 15: line([(22,28),(30,28),(39,61),(69,61),(77,38),(34,38)]); circle(43,73,4); circle(65,73,4)
            case 16: line([(50,34),(39,28),(25,28),(25,69),(39,69),(50,75),(61,69),(75,69),(75,28),(61,28),(50,34),(50,75)]); line([(33,41),(42,43)]); line([(58,43),(67,41)])
            case 17:
                let p = UIBezierPath(); p.move(to:CGPoint(x:50,y:73)); p.addCurve(to:CGPoint(x:27,y:36),controlPoint1:CGPoint(x:10,y:49),controlPoint2:CGPoint(x:22,y:21)); p.addQuadCurve(to:CGPoint(x:50,y:38),controlPoint:CGPoint(x:43,y:23)); p.addQuadCurve(to:CGPoint(x:73,y:36),controlPoint:CGPoint(x:60,y:23)); p.addCurve(to:CGPoint(x:50,y:73),controlPoint1:CGPoint(x:82,y:51),controlPoint2:CGPoint(x:66,y:63)); p.lineWidth=3;p.stroke()
            case 18: box(24,31,52,39,radius:9); line([(44,41),(61,51),(44,61)],close:true)
            case 19: box(42,24,16,34,radius:8); line([(32,48),(32,57),(39,66),(61,66),(68,57),(68,48)]); line([(50,66),(50,77)]); line([(39,77),(61,77)])
            case 20: box(31,23,38,54); box(38,31,24,10,radius:2); for y in [51,63] { for x in [40,50,60] { circle(CGFloat(x),CGFloat(y),1) } }
            case 21: circle(50,50,24); context.strokeEllipse(in:CGRect(x:39,y:26,width:22,height:48)); line([(27,43),(73,43)]); line([(27,57),(73,57)])
            case 22: line([(23,47),(50,25),(77,47)]); line([(31,41),(31,74),(69,74),(69,41)]); line([(44,74),(44,55),(56,55),(56,74)])
            default: line([(50,24),(58,41),(77,44),(63,58),(66,77),(50,68),(34,77),(37,58),(23,44),(42,41)],close:true)
            }
        }
    }
}

enum IconExportError: LocalizedError {
    case encoding
    var errorDescription: String? { String(localized: "icons.error.export") }
}
