#!/usr/bin/env swift
// Usage: swift scripts/geocode_schools.swift
// Reads reports/extracted/schools.json, geocodes missing lat/lon, writes back.
// Throttle 1 req/sec; failed addresses go to reports/extracted/geocode_failed.json

import CoreLocation
import Foundation

let path = "reports/extracted/schools.json"
let failPath = "reports/extracted/geocode_failed.json"

guard let data = FileManager.default.contents(atPath: path),
      var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      var items = root["items"] as? [[String: Any]]
else {
    FileHandle.standardError.write("ERROR: cannot read \(path)\n".data(using: .utf8)!)
    exit(1)
}

let geocoder = CLGeocoder()
let semaphore = DispatchSemaphore(value: 0)
var failed: [[String: String]] = []

func geocode(_ address: String) async -> CLLocationCoordinate2D? {
    do {
        let placemarks = try await geocoder.geocodeAddressString("天津市 " + address)
        return placemarks.first?.location?.coordinate
    } catch {
        return nil
    }
}

Task {
    var done = 0
    for i in items.indices {
        var item = items[i]
        let name = (item["name"] as? String) ?? "?"
        if let existingLat = item["lat"], !(existingLat is NSNull) { continue }
        guard let address = item["address"] as? String, !address.isEmpty else {
            failed.append([
                "id": (item["id"] as? String) ?? "?",
                "name": name,
                "reason": "no address",
            ])
            continue
        }
        let firstAddr = address.split(separator: "、").first.map(String.init) ?? address
        let cleaned = firstAddr.split(separator: "(").first.map(String.init) ?? firstAddr
        if let coord = await geocode(cleaned) {
            item["lat"] = coord.latitude
            item["lon"] = coord.longitude
            item["geocode_source"] = "CLGeocoder"
            item["geocode_confidence"] = "address"
            items[i] = item
            print("✓ \(name) → (\(coord.latitude), \(coord.longitude))")
        } else {
            failed.append([
                "id": (item["id"] as? String) ?? "?",
                "name": name,
                "reason": "geocode failed for: \(cleaned)",
            ])
            item["geocode_confidence"] = "failed"
            items[i] = item
            print("✗ \(name) — \(cleaned)")
        }
        done += 1
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    root["items"] = items
    let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let out = try! JSONSerialization.data(withJSONObject: root, options: opts)
    try! out.write(to: URL(fileURLWithPath: path))
    let failOut = try! JSONSerialization.data(withJSONObject: failed, options: [.prettyPrinted])
    try! failOut.write(to: URL(fileURLWithPath: failPath))
    print("\nDone. \(done) processed, \(failed.count) failed → \(failPath)")
    semaphore.signal()
}

semaphore.wait()
