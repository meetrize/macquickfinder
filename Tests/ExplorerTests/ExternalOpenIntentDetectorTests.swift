import AppKit
import CoreServices
import XCTest
@testable import Explorer

final class ExternalOpenIntentDetectorTests: XCTestCase {
  func testRevealSelectionIntent() {
    let event = NSAppleEventDescriptor(
      eventClass: AEEventClass(kCoreEventClass),
      eventID: AEEventID(kAERevealSelection),
      targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.explorer.app"),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    XCTAssertEqual(ExternalOpenIntentDetector.intent(for: event), .revealInFileViewer)
  }

  func testRevealSelectionIntentOnFinderEventClass() {
    let event = NSAppleEventDescriptor(
      eventClass: AEEventClass(kAEFinderEvents),
      eventID: AEEventID(kAERevealSelection),
      targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.explorer.app"),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    XCTAssertEqual(ExternalOpenIntentDetector.intent(for: event), .revealInFileViewer)
  }

  func testOpenSelectionIntent() {
    let event = NSAppleEventDescriptor(
      eventClass: AEEventClass(kAEFinderEvents),
      eventID: AEEventID(kAEOpenSelection),
      targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.explorer.app"),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    XCTAssertEqual(ExternalOpenIntentDetector.intent(for: event), .openDocument)
  }

  func testOpenDocumentsIntent() {
    let event = NSAppleEventDescriptor(
      eventClass: AEEventClass(kCoreEventClass),
      eventID: AEEventID(kAEOpenDocuments),
      targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.explorer.app"),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    XCTAssertEqual(ExternalOpenIntentDetector.intent(for: event), .openDocument)
  }

  func testExtractsFileURLsFromStringList() {
    let list = NSAppleEventDescriptor.list()
    list.insert(NSAppleEventDescriptor(string: "/tmp/a.png"), at: 1)
    list.insert(NSAppleEventDescriptor(string: "/tmp/b.pdf"), at: 2)

    let event = NSAppleEventDescriptor(
      eventClass: AEEventClass(kAEFinderEvents),
      eventID: AEEventID(kAERevealSelection),
      targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.explorer.app"),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
        event.setParam(list, forKeyword: AEKeyword(keyDirectObject))

    let urls = ExternalAppleEventFileURLExtractor.fileURLs(from: event)
    XCTAssertEqual(urls.map(\.path), ["/tmp/a.png", "/tmp/b.pdf"])
  }
}

@MainActor
final class ExternalOpenRouterTests: XCTestCase {
  override func tearDown() {
    ExternalPreviewOpenCenter.shared.clearSuppressExplorerWindows()
    super.tearDown()
  }

  func testRevealIntentSkipsPreviewOpen() {
    var previewOpened = false
    ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { _ in
      previewOpened = true
    }

    ExternalOpenRouter.handleOpen(
      urls: [URL(fileURLWithPath: "/tmp/reveal.png")],
      intent: .revealInFileViewer
    )

    XCTAssertFalse(previewOpened)
    XCTAssertFalse(ExternalPreviewOpenCenter.shared.shouldSuppressExplorerWindows)
    XCTAssertEqual(
      ExternalFolderOpenCenter.shared.targetRequest?.selectionPath,
      "/tmp/reveal.png"
    )
  }
}
