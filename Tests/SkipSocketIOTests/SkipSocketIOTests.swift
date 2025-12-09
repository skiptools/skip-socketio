// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
import XCTest
import OSLog
import Foundation
@testable import SkipSocketIO

let logger: Logger = Logger(subsystem: "SkipSocketIO", category: "Tests")

@available(macOS 13, *)
final class SkipSocketIOTests: XCTestCase {

    func testSkipSocketIO() throws {
        logger.log("running testSkipSocketIO")
        let socket = SkipSocketIOClient(socketURL: URL(string: "https://example.org")!, options: [
            .compress,
            .path("/mypath/"),
            .secure(false),
            .forceNew(false),
            .forcePolling(false),
            .reconnects(true),
            .reconnectAttempts(5),
            .reconnectWait(2),
            .reconnectWaitMax(10),
            .extraHeaders(["X-Custom-Header": "Value"]),
        ])

        socket.on("connection") { params in
            logger.log("socket connection established")
        }

        socket.connect()

        socket.on("onUpdate") { params in
            logger.log("onUpdate event received with parameters: \(params)")
        }

        socket.emit("update", ["hello", 1, "2", Data()])

        socket.disconnect()
    }
}
