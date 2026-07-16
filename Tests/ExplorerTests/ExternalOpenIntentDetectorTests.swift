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
  override func setUp() {
    super.setUp()
    ExternalFolderOpenCenter.shared.resetForTesting()
  }

  override func tearDown() {
    ExternalPreviewOpenCenter.shared.clearSuppressExplorerWindows()
    ExternalFolderOpenCenter.shared.resetForTesting()
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

  func testWarmSessionWithoutWindowOpensFolderWindow() {
    let center = ExternalFolderOpenCenter.shared
    center.markSessionEstablished()

    var openedDirectory: String?
    center.setOpenFolderWindowHandler { request in
      openedDirectory = request.directoryPath
    }

    // 无已注册 Explorer 窗时回退到新建文件夹窗口。
    center.requestOpen(urls: [URL(fileURLWithPath: "/tmp/warm-reveal.png")])

    XCTAssertEqual(openedDirectory, "/tmp")
    XCTAssertNil(center.targetRequest)
    XCTAssertNil(center.consumePendingRequest())
  }

  func testWarmDeliverClearsStickyTargetAndUsesPendingOnce() {
    let center = ExternalFolderOpenCenter.shared
    center.markSessionEstablished()
    // 无真实宿主窗时走 openFolderWindow；此处验证冷启动 pending 仍可单次消费。
    center.resetForTesting()
    center.requestOpen(urls: [URL(fileURLWithPath: "/tmp/once.txt")])
    XCTAssertNotNil(center.targetRequest)
    XCTAssertEqual(center.consumePendingRequest()?.selectionPath, "/tmp/once.txt")
    XCTAssertNil(center.targetRequest)
    XCTAssertNil(center.consumePendingRequest())
  }

  func testConsumePendingRequestClearsStickyTarget() {
    let center = ExternalFolderOpenCenter.shared
    center.requestOpen(urls: [URL(fileURLWithPath: "/tmp/sticky.txt")])
    XCTAssertNotNil(center.targetRequest)

    let consumed = center.consumePendingRequest()
    XCTAssertEqual(consumed?.directoryPath, "/tmp")
    XCTAssertNil(center.targetRequest)
    XCTAssertNil(center.consumePendingRequest())
  }
}
