import AppKit
import CoreServices
import Foundation

enum ExternalOpenDiagnostic {
    private static let logURL = URL(fileURLWithPath: "/tmp/meofind-external-open.log")

    static func logRouter(
        urls: [URL],
        intent: ExternalOpenIntent,
        source: String
    ) {
        var lines = "[\(source)] intent=\(intent) urls=\(urls.map(\.path).joined(separator: ", "))"
        if let event = NSAppleEventManager.shared().currentAppleEvent {
            lines += " event=\(describe(event))"
            lines += " params=\(describeParams(event))"
        }
        write(lines)
    }

    static func logRevealHandler(event: NSAppleEventDescriptor, urls: [URL]) {
        write("[reveal-handler] urls=\(urls.map(\.path).joined(separator: ", ")) event=\(describe(event))")
    }

    static func logRaw(_ line: String) {
        write("[delegate] \(line)")
    }

    private static func describe(_ event: NSAppleEventDescriptor) -> String {
        "\(fourCC(UInt32(event.eventClass)))/\(fourCC(UInt32(event.eventID)))"
    }

    private static func describeParams(_ event: NSAppleEventDescriptor) -> String {
        var parts: [String] = []
        let keywords: [AEKeyword] = [
            AEKeyword(keyDirectObject),
            AEKeyword(keyAEFile),
            AEKeyword(keySelection),
            AEKeyword(keyAESearchText),
            AEKeyword(keyAEPropData),
        ]
        for keyword in keywords {
            guard let param = event.paramDescriptor(forKeyword: keyword) else { continue }
            parts.append("\(fourCC(UInt32(keyword))):\(describeValue(param))")
        }
        if let attr = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)) {
            parts.append("addr:\(describeValue(attr))")
        }
        return parts.isEmpty ? "none" : parts.joined(separator: "; ")
    }

    private static func describeValue(_ descriptor: NSAppleEventDescriptor) -> String {
        switch descriptor.descriptorType {
        case typeBoolean:
            return descriptor.booleanValue ? "true" : "false"
        case typeAEList:
            var items: [String] = []
            for index in 1...descriptor.numberOfItems {
                if let item = descriptor.atIndex(index) {
                    items.append(describeValue(item))
                }
            }
            return "[\(items.joined(separator: ", "))]"
        default:
            if let s = descriptor.stringValue { return "\"\(s)\"" }
            return "type(\(fourCC(UInt32(descriptor.descriptorType))))"
        }
    }

    private static func fourCC(_ code: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff),
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? "????"
    }

    private static func write(_ line: String) {
        let entry = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(Data(entry.utf8))
            try? handle.close()
        } else {
            try? entry.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}
