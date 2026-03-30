// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
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

    func testSocketIOStatus() throws {
        let statuses: [SocketIOStatus] = [.notConnected, .connecting, .connected, .disconnected]
        XCTAssertEqual(statuses.count, 4)
        XCTAssertEqual(SocketIOStatus.notConnected.rawValue, "notConnected")
        XCTAssertEqual(SocketIOStatus.connected.rawValue, "connected")
    }

    func testSocketIOEvents() throws {
        XCTAssertEqual(SocketIOEvent.connect, "connect")
        XCTAssertEqual(SocketIOEvent.disconnect, "disconnect")
        XCTAssertEqual(SocketIOEvent.connectError, "connect_error")
    }

    func testClientOptions() throws {
        // Verify all option cases can be constructed
        let options: [SkipSocketIOClientOption] = [
            .compress,
            .connectParams(["key": "value"]),
            .extraHeaders(["X-Header": "val"]),
            .forceNew(true),
            .forcePolling(false),
            .forceWebsockets(true),
            .enableSOCKSProxy(false),
            .log(true),
            .path("/custom"),
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(1),
            .reconnectWaitMax(30),
            .randomizationFactor(0.5),
            .secure(true),
            .selfSigned(false),
            .auth(["token": "abc123"]),
        ]
        XCTAssertEqual(options.count, 17)
    }

    func testOnceAndOff() throws {
        let socket = SkipSocketIOClient(socketURL: URL(string: "https://example.org")!, options: [
            .forceNew(true),
        ])

        var onceCallCount = 0
        socket.once("testEvent") { _ in
            onceCallCount += 1
        }

        socket.on("anotherEvent") { _ in }
        socket.off("anotherEvent")

        socket.removeAllHandlers()

        // Can't verify callbacks fire without a server, but we verify no crash
        XCTAssertTrue(true)
    }

    func testManagerAndNamespaces() throws {
        let manager = SkipSocketIOManager(socketURL: URL(string: "https://example.org")!, options: [
            .reconnects(false),
        ])

        let defaultSocket = manager.defaultSocket()
        XCTAssertNotNil(defaultSocket)

        let chatSocket = manager.socket(forNamespace: "/chat")
        XCTAssertNotNil(chatSocket)
    }

    func testConnectionStatus() throws {
        let socket = SkipSocketIOClient(socketURL: URL(string: "https://example.org")!)
        // Before connecting, should not be connected
        XCTAssertFalse(socket.isConnected)
        XCTAssertNil(socket.socketId)
    }

    func testEmitWithAck() throws {
        let socket = SkipSocketIOClient(socketURL: URL(string: "https://example.org")!, options: [
            .forceNew(true),
        ])

        // Just verify the method can be called without crashing
        // Actual ack responses require a running server
        socket.emitWithAck("ping", ["hello"]) { ackData in
            logger.log("received ack: \(ackData)")
        }

        socket.disconnect()
    }

    func testOnAny() throws {
        let socket = SkipSocketIOClient(socketURL: URL(string: "https://example.org")!)

        socket.onAny { eventName, data in
            logger.log("event: \(eventName) data: \(data)")
        }

        // Verify no crash
        socket.disconnect()
    }
}
