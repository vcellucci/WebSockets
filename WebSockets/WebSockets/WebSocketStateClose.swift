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
    
    func didReceiveData() -> WebSocketTransition {
        debugPrint("Received something while in close.")
        if let os = outputStream {
            webSocketStateUtils?.closeStream(os)
        }
        
        if let ins = inputStream {
            let webSocketFrame = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
            let bytesRead = ins.read(webSocketFrame, maxLength: 8)
            if( bytesRead >= 2 ){
                let opcode = webSocketFrame[0] & 0x0f
                
                if( opcode == WebsocketOpCode.Close.rawValue) {
                    webSocketStateUtils?.raiseClose(reason: "Close handshake completed")
                }
            }
            webSocketFrame.deallocate()
            webSocketStateUtils?.closeStream(ins)
        }
        return .Idle
    }
    
    func canWriteData() -> WebSocketTransition {
        return .None
    }
    
    func getState() -> WebSocketTransition {
        return .Close
    }
    
    func send(bytes data: [UInt8], binary isBinary: Bool) -> WebSocketTransition {
        debugPrint("Warning: Can't write data when closing.")
        return .None
    }
    
    func enter() {
        // send close here
        let closeFrame : [UInt8] = [0x88, 0x0]
        if let os = outputStream {
            os.write(UnsafePointer<UInt8>(closeFrame), maxLength: 2)
        }
    }
    
    func streamClosed(stream s: Stream) ->WebSocketTransition {
        return .None
    }
    
    func ping() {
        debugPrint("Warning, sending ping while closed.  Ignored.")
    }
}
