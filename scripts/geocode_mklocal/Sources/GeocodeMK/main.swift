import AppKit
import Foundation
import MapKit

/// Path resolution: caller usually `cd scripts/geocode_mklocal && swift run GeocodeMK`
/// So schools.json lives at ../../reports/extracted/schools.json
let path = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1]
    : "../../reports/extracted/schools.json"

guard let raw = FileManager.default.contents(atPath: path),
      var root = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
      var items = root["items"] as? [[String: Any]]
else {
    FileHandle.standardError.write("ERROR: cannot read \(path)\n".data(using: .utf8)!)
    exit(1)
}

/// District search-region map (lat, lon, span deg). Centered on each district.
let regions: [String: (Double, Double, Double)] = [
    "和平区": (39.117, 117.195, 0.04),
    "河西区": (39.100, 117.225, 0.06),
    "南开区": (39.120, 117.150, 0.06),
    "河东区": (39.125, 117.235, 0.06),
    "河北区": (39.170, 117.205, 0.06),
    "红桥区": (39.180, 117.165, 0.06),
    "北辰区": (39.230, 117.140, 0.12),
    "西青区": (39.060, 117.090, 0.14),
    "津南区": (38.980, 117.320, 0.14),
    "东丽区": (39.115, 117.370, 0.14),
    "武清区": (39.450, 117.040, 0.20),
    "宝坻区": (39.700, 117.400, 0.20),
    "静海区": (38.940, 116.890, 0.20),
    "宁河区": (39.380, 117.720, 0.20),
    "蓟州区": (40.040, 117.490, 0.20),
    "滨海新区": (39.090, 117.700, 0.30),
    "塘沽区": (39.030, 117.700, 0.10),
    "大港区": (38.760, 117.470, 0.10),
]

/// Bounds for sanity-check (Tianjin lat 38.5-40.3, lon 116.7-118.0)
func inTianjin(_ c: CLLocationCoordinate2D) -> Bool {
    c.latitude >= 38.5 && c.latitude <= 40.3
        && c.longitude >= 116.7 && c.longitude <= 118.0
}

func search(name: String, district: String) async -> CLLocationCoordinate2D? {
    // Special: "_TIANJIN_" = whole-city wide region (for full addresses)
    let center: (Double, Double, Double) = if district == "_TIANJIN_" {
        (39.13, 117.20, 0.8)
    } else {
        regions[district] ?? (39.13, 117.20, 0.6)
    }
    let req = MKLocalSearch.Request()
    req.naturalLanguageQuery = name
    req.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: center.0, longitude: center.1),
        span: MKCoordinateSpan(latitudeDelta: center.2, longitudeDelta: center.2)
    )
    req.resultTypes = [.pointOfInterest, .address]
    return await withCheckedContinuation { (cont: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
        MKLocalSearch(request: req).start { resp, err in
            if let items = resp?.mapItems {
                for item in items {
                    let c = item.placemark.coordinate
                    if inTianjin(c) { cont.resume(returning: c)
                        return
                    }
                }
            }
            cont.resume(returning: nil)
        }
    }
}

func save(_ root: [String: Any]) {
    let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? JSONSerialization.data(withJSONObject: root, options: opts) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

let app = NSApplication.shared
let delegate = AppDelegate(items: items, root: root)
app.delegate = delegate
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    var items: [[String: Any]]
    var root: [String: Any]
    init(items: [[String: Any]], root: [String: Any]) {
        self.items = items
        self.root = root
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            var hit = 0
            var miss = 0
            for i in items.indices {
                var item = items[i]
                let name = (item["name"] as? String) ?? ""
                let district = (item["district"] as? String) ?? ""
                let address = (item["address"] as? String) ?? ""
                // Re-geocode if source is auto-bbox (low confidence) or missing
                let src = item["geocode_source"] as? String
                let conf = item["geocode_confidence"] as? String
                let needsRedo = src == nil || src == "auto-bbox" || conf == "failed"
                if !needsRedo { continue }
                // Pass 0: if address has explicit 市/区 (full address), search verbatim — broader region (whole Tianjin)
                var found: CLLocationCoordinate2D?
                var confidence = "name"
                if address.contains("市"), address.contains("区") {
                    let firstAddr = address.split(separator: "、").first.map(String.init) ?? address
                    let cleaned = firstAddr.split(separator: "(").first.map(String.init) ?? firstAddr
                    // Whole-Tianjin region for accurate addresses
                    found = await search(name: cleaned, district: "_TIANJIN_")
                    if found != nil { confidence = "address" }
                }
                // Pass 1: by name w/ district region (POI match)
                if found == nil {
                    found = await search(name: name, district: district)
                    if found != nil { confidence = "name" }
                }
                // Pass 2: name miss + address present → district-prefixed addr
                if found == nil, !address.isEmpty {
                    let firstAddr = address.split(separator: "、").first.map(String.init) ?? address
                    let cleaned = firstAddr.split(separator: "(").first.map(String.init) ?? firstAddr
                    found = await search(name: "天津市\(district)\(cleaned)", district: district)
                    if found != nil { confidence = "address" }
                }
                if let c = found {
                    item["lat"] = c.latitude
                    item["lon"] = c.longitude
                    item["geocode_source"] = "mklocalsearch"
                    item["geocode_confidence"] = confidence
                    items[i] = item
                    hit += 1
                    if hit % 25 == 0 { print("hit=\(hit) miss=\(miss)") }
                } else {
                    item["geocode_source"] = "mklocalsearch"
                    item["geocode_confidence"] = "failed"
                    items[i] = item
                    miss += 1
                }
                // Throttle: Apple POI API has no documented limit but be polite
                try? await Task.sleep(nanoseconds: 200_000_000)
                if (hit + miss) % 50 == 0 {
                    root["items"] = items
                    save(root)
                    print("snapshot saved at \(hit + miss)")
                }
            }
            root["items"] = items
            save(root)
            print("DONE hit=\(hit) miss=\(miss)")
            NSApp.terminate(nil)
        }
    }
}
