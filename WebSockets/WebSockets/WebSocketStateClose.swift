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
                    webSocketStateUtils?.raiseClose()
                }
                
                let payloadLen = webSocketFrame[1]
                if( payloadLen > 0 ){
                    debugPrint("Sent a resson?")
                }
            }
            webSocketStateUtils?.closeStream(ins)
        }
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
        // send close here
        let closeFrame : [UInt8] = [0x88, 0x0]
        if let os = outputStream {
            os.write(UnsafePointer<UInt8>(closeFrame), maxLength: 2)
        }
    }
}
