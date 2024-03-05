//
//  SocketIOModel.swift
//  TestSocket
//
//  Created by Denis Blondeau on 2023-12-18.
//

import AppKit
import Combine
import Foundation
import SocketIO


final class SocketIOModel {
    
    enum SocketIOError: Error {
        case runtimeError(String)
    }
    
    private let manager: SocketManager!
    private var socket: SocketIOClient!
    let onDataReceived = PassthroughSubject<RemoteKey, Error>()
    
    init(serverURL: URL) {
        manager = SocketManager(socketURL: serverURL, config: [.log(false), .compress, .forceWebsockets(true)])
        socket = manager.defaultSocket
        addHandlers()
        socket.connect()
    }
    
    /// Set SocketIO handlers.
    private func addHandlers() {
        
        socket.on(clientEvent: .error) { data, ack in
            guard let error = data[0] as? String else { return }
            self.onDataReceived.send(completion: .failure(SocketIOError.runtimeError(error)))
        }
        
        socket.on(clientEvent: .disconnect) { data, ack in
            guard let error = data[0] as? String else { return }
            self.onDataReceived.send(completion: .failure(SocketIOError.runtimeError(error)))
        }
        
        socket.on("keypress") { data, ack in
            guard let keypress = data[0] as? String else { return }
            let keypressEnum = RemoteKey(rawValue: keypress)
            
            if let keypressEnum {
                self.onDataReceived.send(keypressEnum)
            } else {
                self.onDataReceived.send(completion: .failure(SocketIOError.runtimeError("Cannot convert keypress.")))
            }
        }
    }
}
