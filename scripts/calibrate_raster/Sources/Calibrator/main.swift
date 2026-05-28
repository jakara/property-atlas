import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift run Calibrator <district-name> [raster-png-path] [zones-json-path]")
    print("Example: swift run Calibrator 和平区")
    exit(1)
}

let district = CommandLine.arguments[1]
let pngPath = CommandLine.arguments.count >= 3
    ? CommandLine.arguments[2]
    : "../../PropertyAtlas/PropertyAtlas/Resources/StudioRasters/raw/\(district)学片.png"
let zonesPath = CommandLine.arguments.count >= 4
    ? CommandLine.arguments[3]
    : "../../reports/extracted/zones.json"

CalibratorApp.launch(district: district, pngPath: pngPath, zonesPath: zonesPath)
