// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
import XCTest
//import OSLog
import Foundation
@testable import SkipSocketIO

//let logger: Logger = Logger(subsystem: "SkipSocketIO", category: "Tests")

@available(macOS 13, *)
final class SkipSocketIOTests: XCTestCase {

    func testSkipSocketIO() throws {
        //logger.log("running testSkipSocketIO")
        let socket = SkipSocketIOClient(socketURL: URL(string: "https://example.org")!)
        socket.connect()
        socket.disconnect()
    }
}
