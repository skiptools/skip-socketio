// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
#if !SKIP_BRIDGE
import Foundation

#if !SKIP
import SocketIO
#else
import io.socket.client.IO
import io.socket.client.Socket
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

    public init(socketURL: URL) {
        #if !SKIP
        // See example at https://github.com/socketio/socket.io-client-swift?tab=readme-ov-file
        let manager = SocketManager(socketURL: socketURL, config: [
            // TODO: options
            // .log(true), .compress
        ])
        let defaultNamespaceSocket = manager.defaultSocket
        // let swiftSocket = manager.socket(forNamespace: "/swift") // namespace example
        self.socket = defaultNamespaceSocket
        #else
        // https://socketio.github.io/socket.io-client-java/initialization.html
        let options = IO.Options.builder()
            // TODO: options
            // IO factory options
            //.setForceNew(false)
            //.setMultiplex(true)

            // low-level engine options
            //.setTransports(new String[] { Polling.NAME, WebSocket.NAME })
            //.setUpgrade(true)
            //.setRememberUpgrade(false)
            //.setPath("/socket.io/")
            //.setQuery(null)
            //.setExtraHeaders(null)

            // Manager options
            //.setReconnection(true)
            //.setReconnectionAttempts(Integer.MAX_VALUE)
            //.setReconnectionDelay(1_000)
            //.setReconnectionDelayMax(5_000)
            //.setRandomizationFactor(0.5)
            //.setTimeout(20_000)

            // Socket options
            //.setAuth(null)
            .build()
        self.socket = IO.socket(socketURL.kotlin(), options)
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

    /* TODO:

     socket.on(clientEvent: .connect) {data, ack in
         print("socket connected")
     }

     socket.on("currentAmount") {data, ack in
         guard let cur = data[0] as? Double else { return }

         socket.emitWithAck("canUpdate", cur).timingOut(after: 0) {data in
             if data.first as? String ?? "passed" == SocketAckStatus.noAck {
                 // Handle ack timeout
             }

             socket.emit("update", ["amount": cur + 2.50])
         }

         ack.with("Got your currentAmount", "dude")
     }
     */
}

#endif
