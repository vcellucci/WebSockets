//
//  WebSocketFrameReader.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/24/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
import os

class WebSocketFrameReader {
    var inputStream: InputStream?
    var currentPayloadLen = 0
    var currentHeader = 0
    var totalBytesRead  = 0
    var raiseNotifications = true
    var needsMore = false
    var _webSocketFrame : UnsafeMutablePointer<UInt8>?
    var webSocketStateUtils : WebSocketStateUtils?
    var webSocketInputStream : WebSocketInputStream?
    
    func readData(_ binary : Bool, _ bytesRead : Int) {
        
        if let webSocketFrame = _webSocketFrame {
            if( needsMore ){
                handleNeedsMore(webSocketFrame, bytesRead, binary)
                return
            }
            
            let fin = webSocketFrame[0] & 0x80
            os_log(.debug, "fin = %d", fin)
            if( ((fin == 128) || (webSocketFrame[0] & 0x0f) != 0)){
                if let win = webSocketInputStream {
                    if let didClose = win.didClose {
                        didClose()
                    }
                }
                webSocketInputStream = nil
            }
            else if(fin == 0) {
                if webSocketInputStream == nil {
                    webSocketInputStream = WebSocketInputStream()
                    webSocketStateUtils?.raiseReceivedStream(webSocketInputStream!)
                }
            }
            
            currentHeader = 0
            
            let payloadLen = webSocketFrame[1]
            if payloadLen < 126 {
                let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by : 2), count: Int(payloadLen)))
                notifyData(data, binary)
            }
            else if(payloadLen == 126){
                currentHeader = 4 // 2 for optcode, payloadlen and 2 for 16bit payloadlen
                let dataBytes = NSData(bytes: webSocketFrame.advanced(by: 2), length: 2)
                var u16 : UInt16 = 0
                dataBytes.getBytes(&u16, length: 2)
                u16 = u16.byteSwapped
                currentPayloadLen = Int(u16) + currentHeader
                if( bytesRead < currentPayloadLen ){
                    totalBytesRead += bytesRead
                    needsMore = true
                    os_log(.debug, "Need more data")
                    return
                } else {
                    totalBytesRead = 0
                    needsMore = false
                }
                
                let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by: 4), count: Int(u16)))
                notifyData(data, binary)
            }
        }
    }
    
    fileprivate func handleNeedsMore(_ webSocketFrame : UnsafeMutablePointer<UInt8>, _ bytesRead: Int, _ binary: Bool) {
        totalBytesRead += bytesRead
        if( totalBytesRead < currentPayloadLen ){
            return
        }
        let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by: 4), count: Int(currentPayloadLen-currentHeader)))
        needsMore = false
        totalBytesRead = 0
        
        notifyData(data, binary)
    }
    
    private func notifyData(_ arraySlice : ArraySlice<UInt8>, _ binary : Bool) {
        
        if let win = webSocketInputStream {
            win.isBinary = binary
            if let drf = win.didReceiveFragment {
                drf(arraySlice)
            }
            return
        }
        
        if( binary ) {
            webSocketStateUtils?.raiseBinaryMessage(data: arraySlice)
        }
        else {
            if let message = String(bytes: arraySlice, encoding: .utf8) {
                webSocketStateUtils?.raiseTextMessage(message: message)
            }
            else {
                webSocketStateUtils?.raiseError(error: "Unexpected error while trying to decode message.", code: NSError(domain: "WebSockets", code: 500, userInfo: nil))
            }
        }
    }
    
}
