import XCTest
import SwiftUI
@testable import AbletonPushDisplayKit

final class AbletonPushDisplayKitTests: XCTestCase {
    func Push2ViewController_doesNot_throw() throws {
        XCTAssertNoThrow(Push2ViewController(push2View: Text("Hellow world!").eraseToAnyView()))
    }
}
