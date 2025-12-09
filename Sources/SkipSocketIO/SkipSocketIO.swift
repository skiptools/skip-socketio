// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
#if !SKIP_BRIDGE
import Foundation

#if !SKIP
import SocketIO
#else
import io.socket.client.Ack
import io.socket.client.IO
import io.socket.client.Socket
import io.socket.client.SocketOptionBuilder
import io.socket.emitter.Emitter
#endif

/// Abstraction of the socket.io client API for [swift](https://nuclearace.github.io/Socket.IO-Client-Swift/Classes/SocketIOClient.html) and [Java](https://socketio.github.io/socket.io-client-java/apidocs/io/socket/client/package-summary.html)
public class SkipSocketIOClient {
    #if !SKIP
    // https://nuclearace.github.io/Socket.IO-Client-Swift/Classes/SocketIOClient.html
    let socket: SocketIOClient
    #else
    // https://socketio.github.io/socket.io-client-java/socket_instance.html
    // https://socketio.github.io/socket.io-client-java/apidocs/io/socket/client/Socket.html
    let socket: Socket
    #endif

    public init(socketURL: URL, options: [SkipSocketIOClientOption] = []) {
        #if !SKIP
        // See example at https://github.com/socketio/socket.io-client-swift?tab=readme-ov-file
        var opts = SocketIOClientConfiguration()
        for option in options {
            opts.insert(option.toSocketIOClientOption())
        }
        let manager = SocketManager(socketURL: socketURL, config: opts)
        let defaultNamespaceSocket = manager.defaultSocket
        // let swiftSocket = manager.socket(forNamespace: "/swift") // namespace example
        self.socket = defaultNamespaceSocket
        #else
        // https://socketio.github.io/socket.io-client-java/initialization.html
        var optionsBuilder = IO.Options.builder()
        for option in options {
            optionsBuilder = option.addToOptionsBuilder(builder: optionsBuilder)
        }
        self.socket = IO.socket(socketURL.kotlin(), optionsBuilder.build())
        #endif
    }

    public func connect() {
        // TODO: args like withPayload
        socket.connect()
    }

    public func disconnect() {
        socket.disconnect()
        return // needed because Java API returns a Socket instance
    }

    public func on(_ event: String, callback: @escaping ([Any]) -> ()) {
        #if !SKIP
        socket.on(event) { data, ack in
            callback(data)
        }
        #else
        socket.on(event, Emitter.Listener { data in
            var dataArray: [Any] = []
            for datum in data {
                dataArray.append(datum)
            }
            callback(dataArray)
        })
        #endif
    }

    /// https://nuclearace.github.io/Socket.IO-Client-Swift/Classes/SocketIOClient.html#/s:8SocketIO0A8IOClientC4emit__10completionySS_AA0A4Data_pdyycSgtF
    /// https://socketio.github.io/socket.io-client-java/apidocs/io/socket/client/Socket.html#emit(java.lang.String,java.lang.Object%5B%5D,io.socket.client.Ack)
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
}

/// Wrapper for [`SocketIOClientOption`](https://nuclearace.github.io/Socket.IO-Client-Swift/Enums/SocketIOClientOption.html)
/// for bridging to [`SocketOptionBuilder`](https://socketio.github.io/socket.io-client-java/apidocs/io/socket/client/SocketOptionBuilder.html)
///
/// Note that some options are currently ignored on the Java side as they are not implemented in the client.
public enum SkipSocketIOClientOption {
    /// If given, the WebSocket transport will attempt to use compression.
    case compress

    /// A dictionary of GET parameters that will be included in the connect url.
    case connectParams([String: Any])

    /// An array of cookies that will be sent during the initial connection.
    //case cookies([HTTPCookie])

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

    /// The queue that all interaction with the client should occur on. This is the queue that event handlers are
    /// called on.
    ///
    /// **This should be a serial queue! Concurrent queues are not supported and might cause crashes and races**.
    //case handleQueue(DispatchQueue)

    /// If passed `true`, the client will log debug information. This should be turned off in production code.
    case log(Bool)

    /// Used to pass in a custom logger.
    //case logger(SocketLogger)

    /// A custom path to socket.io. Only use this if the socket.io server is configured to look for this path.
    case path(String)

    /// If passed `false`, the client will not reconnect when it loses connection. Useful if you want full control
    /// over when reconnects happen.
    case reconnects(Bool)

    /// The number of times to try and reconnect before giving up. Pass `-1` to [never give up](https://www.youtube.com/watch?v=dQw4w9WgXcQ).
    case reconnectAttempts(Int)

    /// The minimum number of seconds to wait before reconnect attempts.
    case reconnectWait(Int)

    /// The maximum number of seconds to wait before reconnect attempts.
    case reconnectWaitMax(Int)

    /// The randomization factor for calculating reconnect jitter.
    case randomizationFactor(Double)

    /// Set `true` if your server is using secure transports.
    case secure(Bool)

    /// Allows you to set which certs are valid. Useful for SSL pinning.
    //case security(CertificatePinning)

    /// If you're using a self-signed set. Only use for development.
    case selfSigned(Bool)

    /// Sets an NSURLSessionDelegate for the underlying engine. Useful if you need to handle self-signed certs.
    //case sessionDelegate(URLSessionDelegate)

    /// If passed `false`, the WebSocket stream will be configured with the useCustomEngine `false`.
    //case useCustomEngine(Bool)

    /// The version of socket.io being used. This should match the server version. Default is 3.
    //case version(SocketIOVersion)

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
        //case .sessionDelegate(let arg): return .sessionDelegate(arg)
        //case .useCustomEngine(let arg): return .useCustomEngine(arg)
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
        //case .sessionDelegate(let arg): builder = builder
        //case .useCustomEngine(let arg): builder = builder
        }

        return builder
    }
    #endif
}

#endif
