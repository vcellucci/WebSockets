//
//  WebSocketStateClose.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/19/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation

class WebSocketStateClose: WebSocketState {
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var url: URL?
    var webSocketStateUtils: WebSocketStateUtils?
    
    var sentClose = false
    
    func didReceiveData() -> WebSocketTransition {
        return .None
    }
    
    func canWriteData() -> WebSocketTransition {
        return .None
    }
    
    func getState() -> WebSocketTransition {
        return .Close
    }
    
    func send(bytes data: [UInt8], binary isBinary: Bool) -> WebSocketTransition {
        return .None
    }
    
    func enter() {
    }

}
