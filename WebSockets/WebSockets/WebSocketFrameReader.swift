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
    var currentIndex = 0
    
    
    
    func readData(_ binary : Bool, _ bytesRead : Int) {
        if let ws = _webSocketFrame {
            var webSocketFrame = ws.advanced(by: 0)
            var hasData = true
            var currentBytesProcess = 0
            
            while( hasData ){
                if( needsMore ){
                    handleNeedsMore(webSocketFrame, bytesRead, binary)
                    return
                }
                
                syncInputStream(webSocketFrame)
                
                currentHeader = 0
                let payloadLen = webSocketFrame[1]
                if payloadLen < 126 {
                    handleSmallFrame(webSocketFrame, payloadLen, &currentBytesProcess, binary)
                }
                else if(payloadLen == 126){
                    handleMediumFrame(webSocketFrame, &currentBytesProcess, bytesRead, binary)
                }
                
                if (bytesRead <= currentBytesProcess ){
                    hasData = false
                }
                
                if hasData {
                    webSocketFrame = webSocketFrame.advanced(by: currentPayloadLen)
                    currentIndex += currentPayloadLen
                }
            }
        }
    }
    
    fileprivate func syncInputStream(_ webSocketFrame: UnsafeMutablePointer<UInt8>) {
        let fin = webSocketFrame[0] & 0x80
        os_log(.debug, "fin = %d", fin)
        if( ((fin == 128) && (webSocketFrame[0] & 0x0f) != 0)){
            if let win = webSocketInputStream {
                if let didClose = win.didClose {
                    didClose()
                }
            }
            webSocketInputStream = nil
            needsMore = false
            totalBytesRead = 0
        }
        else if(fin == 0) {
            if webSocketInputStream == nil {
                webSocketInputStream = WebSocketInputStream()
                webSocketStateUtils?.raiseReceivedStream(webSocketInputStream!)
            }
        }
    }
    
    fileprivate func handleNeedsMore(_ webSocketFrame : UnsafeMutablePointer<UInt8>, _ bytesRead: Int, _ binary: Bool) {
        totalBytesRead += bytesRead
        if( totalBytesRead < currentPayloadLen ){
            return
        }
        let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by: 4+currentIndex), count: Int(currentPayloadLen-currentHeader)))
        needsMore = false
        totalBytesRead = 0
        currentIndex = 0
        notifyData(data, binary)
    }
    
    fileprivate func handleSmallFrame(_ webSocketFrame: UnsafeMutablePointer<UInt8>, _ payloadLen: UInt8, _ currentBytesProcess: inout Int, _ binary: Bool) {
        let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by : 2), count: Int(payloadLen)))
        currentBytesProcess += Int(payloadLen) + 2
        notifyData(data, binary)
    }
    
    fileprivate func handleMediumFrame(_ webSocketFrame: UnsafeMutablePointer<UInt8>, _ currentBytesProcess: inout Int, _ bytesRead: Int, _ binary: Bool) {
        currentHeader = 4 // 2 for optcode, payloadlen and 2 for 16bit payloadlen
        let dataBytes = NSData(bytes: webSocketFrame.advanced(by: 2), length: 2)
        var u16 : UInt16 = 0
        dataBytes.getBytes(&u16, length: 2)
        u16 = u16.byteSwapped
        currentPayloadLen = Int(u16) + currentHeader
        currentBytesProcess += currentPayloadLen
        
        if( bytesRead < currentBytesProcess ){
            totalBytesRead += bytesRead
            needsMore = true
            return
        }
        else {
            totalBytesRead = 0
            needsMore = false
        }
        
        let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by: 4), count: Int(u16)))
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
