// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation
import OSLog

#if !SKIP
import SocketIO
#else
import io.socket.client.Ack
import io.socket.client.IO
import io.socket.client.Socket
import io.socket.client.SocketOptionBuilder
import io.socket.emitter.Emitter
#endif

let logger: Logger = Logger(subsystem: "skip.socketio", category: "SkipSocketIO")

// MARK: - SocketIOStatus

/// The connection status of a socket.
public enum SocketIOStatus: String {
    case notConnected
    case connecting
    case connected
    case disconnected
}

// MARK: - SocketIOEvent

/// Well-known Socket.IO event names.
///
/// These correspond to the standard lifecycle events emitted by the Socket.IO protocol.
public enum SocketIOEvent {
    /// Fired upon connection, including a successful reconnection.
    public static let connect = "connect"
    /// Fired upon disconnection.
    public static let disconnect = "disconnect"
    /// Fired upon a connection error.
    public static let connectError = "connect_error"
}

// MARK: - SkipSocketIOManager

/// Manages one or more Socket.IO connections to a server.
///
/// Use this class when you need to connect to multiple namespaces on the same server,
/// or when you need to keep a reference to the manager for reconnection control.
///
/// https://nuclearace.github.io/Socket.IO-Client-Swift/Classes/SocketManager.html
/// https://socketio.github.io/socket.io-client-java/initialization.html
public class SkipSocketIOManager {
    #if !SKIP
    let manager: SocketManager
    #else
    let socketURL: java.net.URI
    let optionsBuilder: IO.Options
    #endif

    /// Create a manager for the given server URL.
    ///
    /// - Parameters:
    ///   - socketURL: The URL of the Socket.IO server.
    ///   - options: Configuration options for the connection.
    public init(socketURL: URL, options: [SkipSocketIOClientOption] = []) {
        #if !SKIP
        var opts = SocketIOClientConfiguration()
        for option in options {
            opts.insert(option.toSocketIOClientOption())
        }
        self.manager = SocketManager(socketURL: socketURL, config: opts)
        #else
        var builder = IO.Options.builder()
        for option in options {
            builder = option.addToOptionsBuilder(builder: builder)
        }
        self.socketURL = socketURL.kotlin()
        self.optionsBuilder = builder.build()
        #endif
    }

    /// Returns a socket for the default namespace (`/`).
    public func defaultSocket() -> SkipSocketIOClient {
        #if !SKIP
        return SkipSocketIOClient(socket: manager.defaultSocket)
        #else
        return SkipSocketIOClient(socket: IO.socket(socketURL, optionsBuilder))
        #endif
    }

    /// Returns a socket for the given namespace.
    ///
    /// - Parameter namespace: The namespace to connect to (must start with `/`).
    public func socket(forNamespace namespace: String) -> SkipSocketIOClient {
        #if !SKIP
        return SkipSocketIOClient(socket: manager.socket(forNamespace: namespace))
        #else
        let nsURI = java.net.URI.create(socketURL.toString() + namespace)
        return SkipSocketIOClient(socket: IO.socket(nsURI, optionsBuilder))
        #endif
    }
}

// MARK: - SkipSocketIOClient

/// Abstraction of the socket.io client API for
/// [Swift](https://nuclearace.github.io/Socket.IO-Client-Swift/Classes/SocketIOClient.html) and
/// [Java](https://socketio.github.io/socket.io-client-java/apidocs/io/socket/client/Socket.html).
///
/// This is the primary interface for interacting with a Socket.IO server. It supports
/// connecting, disconnecting, emitting events, listening for events, acknowledgements,
/// and connection status monitoring.
public class SkipSocketIOClient {
    #if !SKIP
    // https://nuclearace.github.io/Socket.IO-Client-Swift/Classes/SocketIOClient.html
    let socket: SocketIOClient
    private var handlerIDs: [String: UUID] = [:]
    #else
    // https://socketio.github.io/socket.io-client-java/apidocs/io/socket/client/Socket.html
    let socket: Socket
    private var listeners: [String: Emitter.Listener] = [:]
    #endif

    /// Create a client that connects to the given URL.
    ///
    /// For more control over namespaces, use `SkipSocketIOManager` instead.
    ///
    /// - Parameters:
    ///   - socketURL: The URL of the Socket.IO server.
    ///   - options: Configuration options for the connection.
    public init(socketURL: URL, options: [SkipSocketIOClientOption] = []) {
        #if !SKIP
        var opts = SocketIOClientConfiguration()
        for option in options {
            opts.insert(option.toSocketIOClientOption())
        }
        let manager = SocketManager(socketURL: socketURL, config: opts)
        self.socket = manager.defaultSocket
        #else
        var optionsBuilder = IO.Options.builder()
        for option in options {
            optionsBuilder = option.addToOptionsBuilder(builder: optionsBuilder)
        }
        self.socket = IO.socket(socketURL.kotlin(), optionsBuilder.build())
        #endif
    }

    #if !SKIP
    init(socket: SocketIOClient) {
        self.socket = socket
    }
    #else
    init(socket: Socket) {
        self.socket = socket
    }
    #endif

    // MARK: Connection

    /// Connect to the server.
    public func connect() {
        socket.connect()
        return // needed because Java API returns a Socket instance
    }

    /// Connect to the server with a timeout.
    ///
    /// If the connection is not established within the given time, the handler is called.
    ///
    /// - Parameters:
    ///   - timeoutAfter: Seconds to wait before timing out.
    ///   - handler: Called if the connection times out.
    public func connect(timeoutAfter: Double, handler: @escaping () -> ()) {
        #if !SKIP
        socket.connect(timeoutAfter: timeoutAfter, withHandler: handler)
        #else
        socket.connect()
        // The Java client does not support a native timeout; implement manually
        let delayMs = Int64(timeoutAfter * 1000.0)
        // SKIP INSERT: val timer = java.util.Timer()
        // SKIP INSERT: timer.schedule(object : java.util.TimerTask() { override fun run() { if (!socket.connected()) { handler(); socket.disconnect() } } }, delayMs)
        #endif
    }

    /// Disconnect from the server.
    public func disconnect() {
        socket.disconnect()
        return // needed because Java API returns a Socket instance
    }

    /// Whether the client is currently connected to the server.
    public var isConnected: Bool {
        #if !SKIP
        return socket.status == .connected
        #else
        return socket.connected()
        #endif
    }

    /// The session ID assigned by the server, or `nil` if not connected.
    public var socketId: String? {
        #if !SKIP
        return socket.sid
        #else
        return socket.id()
        #endif
    }

    /// The current connection status.
    public var status: SocketIOStatus {
        #if !SKIP
        switch socket.status {
        case .notConnected: return .notConnected
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .connected: return .connected
        }
        #else
        if socket.connected() {
            return .connected
        } else {
            return .disconnected
        }
        #endif
    }

    // MARK: Listening for Events

    /// Register a handler for an event. The handler is called every time the event is received.
    ///
    /// - Parameters:
    ///   - event: The event name to listen for.
    ///   - callback: Called with the event data each time the event fires.
    public func on(_ event: String, callback: @escaping ([Any]) -> ()) {
        #if !SKIP
        let id = socket.on(event) { data, ack in
            callback(data)
        }
        handlerIDs[event] = id
        #else
        let listener = Emitter.Listener { data in
            var dataArray: [Any] = []
            for datum in data {
                dataArray.append(datum)
            }
            callback(dataArray)
        }
        socket.on(event, listener)
        listeners[event] = listener
        #endif
    }

    /// Register a one-time handler for an event. The handler is called at most once,
    /// then automatically removed.
    ///
    /// - Parameters:
    ///   - event: The event name to listen for.
    ///   - callback: Called with the event data when the event fires.
    public func once(_ event: String, callback: @escaping ([Any]) -> ()) {
        #if !SKIP
        socket.once(event) { data, ack in
            callback(data)
        }
        #else
        socket.once(event, Emitter.Listener { data in
            var dataArray: [Any] = []
            for datum in data {
                dataArray.append(datum)
            }
            callback(dataArray)
        })
        #endif
    }

    /// Remove all handlers for a specific event.
    ///
    /// - Parameter event: The event name to stop listening for.
    public func off(_ event: String) {
        #if !SKIP
        socket.off(event)
        handlerIDs.removeValue(forKey: event)
        #else
        socket.off(event)
        listeners.removeValue(forKey: event)
        #endif
    }

    /// Remove all event handlers.
    public func removeAllHandlers() {
        #if !SKIP
        socket.removeAllHandlers()
        handlerIDs.removeAll()
        #else
        socket.off()
        listeners.removeAll()
        #endif
    }

    /// Register a catch-all handler that is called for every incoming event.
    ///
    /// - Parameter handler: Called with the event name and data for every received event.
    public func onAny(_ handler: @escaping (String, [Any]) -> ()) {
        #if !SKIP
        socket.onAny { event in
            handler(event.event, event.items ?? [])
        }
        #else
        // SKIP INSERT:
        // socket.onAnyIncoming(Emitter.Listener { args ->
        //     if (args.isNotEmpty()) {
        //         val eventName = args[0].toString()
        //         val data = skip.lib.Array<Any>(args.drop(1))
        //         handler(eventName, data)
        //     }
        // })
        #endif
    }

    // MARK: Emitting Events

    /// Emit an event with data to the server.
    ///
    /// - Parameters:
    ///   - event: The event name.
    ///   - items: The data to send. Supports strings, numbers, dictionaries, arrays, and `Data`.
    ///   - completion: Called after the event is sent (not an acknowledgement from the server).
    public func emit(_ event: String, _ items: [Any], completion: @escaping () -> () = { }) {
        #if !SKIP
        socket.emit(event, with: items.compactMap({ $0 as? SocketData }), completion: {
            completion()
        })
        #else
        let args = items.kotlin().toTypedArray()
        socket.emit(event, args, Ack { _ in
            completion()
        })
        #endif
    }

    /// Emit an event and wait for an acknowledgement from the server.
    ///
    /// - Parameters:
    ///   - event: The event name.
    ///   - items: The data to send.
    ///   - ackCallback: Called with the acknowledgement data from the server.
    public func emitWithAck(_ event: String, _ items: [Any], ackCallback: @escaping ([Any]) -> ()) {
        #if !SKIP
        socket.emitWithAck(event, with: items.compactMap({ $0 as? SocketData })).timingOut(after: 0) { data in
            ackCallback(data)
        }
        #else
        let args = items.kotlin().toTypedArray()
        socket.emit(event, args, Ack { ackData in
            var result: [Any] = []
            for item in ackData {
                result.append(item)
            }
            ackCallback(result)
        })
        #endif
    }
}

// MARK: - SkipSocketIOClientOption

/// Configuration options for a Socket.IO connection.
///
/// Wraps [`SocketIOClientOption`](https://nuclearace.github.io/Socket.IO-Client-Swift/Enums/SocketIOClientOption.html)
/// on iOS and [`SocketOptionBuilder`](https://socketio.github.io/socket.io-client-java/apidocs/io/socket/client/SocketOptionBuilder.html) on Android.
///
/// Note that some options are currently ignored on the Android side as they are not implemented in the Java client.
public enum SkipSocketIOClientOption {
    /// If given, the WebSocket transport will attempt to use compression.
    case compress

    /// A dictionary of GET parameters that will be included in the connect url.
    case connectParams([String: Any])

    /// Any extra HTTP headers that should be sent during the initial connection.
    case extraHeaders([String: String])

    /// If passed `true`, will cause the client to always create a new engine. Useful for debugging,
    /// or when you want to be sure no state from previous engines is being carried over.
    case forceNew(Bool)

    /// If passed `true`, the only transport that will be used will be HTTP long-polling.
    case forcePolling(Bool)

    /// If passed `true`, the only transport that will be used will be WebSockets.
    case forceWebsockets(Bool)

    /// If passed `true`, the WebSocket stream will be configured with the enableSOCKSProxy `true`.
    case enableSOCKSProxy(Bool)

    /// If passed `true`, the client will log debug information. This should be turned off in production code.
    case log(Bool)

    /// A custom path to socket.io. Only use this if the socket.io server is configured to look for this path.
    case path(String)

    /// If passed `false`, the client will not reconnect when it loses connection. Useful if you want full control
    /// over when reconnects happen.
    case reconnects(Bool)

    /// The number of times to try and reconnect before giving up. Pass `-1` to never give up.
    case reconnectAttempts(Int)

    /// The minimum number of seconds to wait before reconnect attempts.
    case reconnectWait(Int)

    /// The maximum number of seconds to wait before reconnect attempts.
    case reconnectWaitMax(Int)

    /// The randomization factor for calculating reconnect jitter.
    case randomizationFactor(Double)

    /// Set `true` if your server is using secure transports.
    case secure(Bool)

    /// If you're using a self-signed set. Only use for development.
    case selfSigned(Bool)

    /// Authentication payload sent when connecting.
    case auth([String: Any])

    #if !SKIP
    fileprivate func toSocketIOClientOption() -> SocketIOClientOption {
        switch self {
        case .compress: return .compress
        case .connectParams(let arg): return .connectParams(arg)
        case .extraHeaders(let arg): return .extraHeaders(arg)
        case .forceNew(let arg): return .forceNew(arg)
        case .forcePolling(let arg): return .forcePolling(arg)
        case .forceWebsockets(let arg): return .forceWebsockets(arg)
        case .enableSOCKSProxy(let arg): return .enableSOCKSProxy(arg)
        case .log(let arg): return .log(arg)
        case .path(let arg): return .path(arg)
        case .reconnects(let arg): return .reconnects(arg)
        case .reconnectAttempts(let arg): return .reconnectAttempts(arg)
        case .reconnectWait(let arg): return .reconnectWait(arg)
        case .reconnectWaitMax(let arg): return .reconnectWaitMax(arg)
        case .randomizationFactor(let arg): return .randomizationFactor(arg)
        case .secure(let arg): return .secure(arg)
        case .selfSigned(let arg): return .selfSigned(arg)
        case .auth(let arg): return .connectParams(arg)
        }
    }
    #else
    fileprivate func addToOptionsBuilder(builder: SocketOptionBuilder) -> SocketOptionBuilder {

        // helper to take a Skip [String: String] dictionary and coerce it into a Kotlin Map<String, List<String>>
        func dictToMapOfStrings(dict: [String: String]) -> Map<String, List<String>> {
            var mapOfStrings: MutableMap<String, List<String>> = mutableMapOf()
            for (key, value) in dict {
                mapOfStrings[key] = listOf(value)
            }
            return mapOfStrings
        }

        var builder = builder
        switch self {
        case .compress: builder = builder // https://github.com/socketio/socket.io-client-java/issues/312
        case .connectParams(let arg): builder = builder
        case .extraHeaders(let arg): builder = builder.setExtraHeaders(dictToMapOfStrings(arg))
        case .forceNew(let arg): builder = builder.setForceNew(arg)
        case .forcePolling(let arg): builder = !arg ? builder : builder.setTransports(kotlin.arrayOf(io.socket.engineio.client.transports.Polling.NAME))
        case .forceWebsockets(let arg): builder = !arg ? builder : builder.setTransports(kotlin.arrayOf(io.socket.engineio.client.transports.WebSocket.NAME))
        case .enableSOCKSProxy(let arg): builder = builder
        case .log(let arg): builder = builder // https://github.com/socketio/socket.io-client-java/issues/755
        case .path(let arg): builder = builder.setPath(arg)
        case .reconnects(let arg): builder = builder.setReconnection(arg)
        case .reconnectAttempts(let arg): builder = builder.setReconnectionAttempts(arg)
        case .reconnectWait(let arg): builder = builder.setReconnectionDelay(Long(arg))
        case .reconnectWaitMax(let arg): builder = builder.setReconnectionDelayMax(Long(arg))
        case .randomizationFactor(let arg): builder = builder.setRandomizationFactor(arg)
        case .secure(let arg): builder = builder.setSecure(arg)
        case .selfSigned(let arg): builder = builder
        case .auth(let arg): builder = builder // auth handled at connect time on Java
        }

        return builder
    }
    #endif
}

#endif
