//
//  WebSocketFrameParser.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/26/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
import os
class WebSocketFrameParser {
    
    var webSockStateUtils : WebSocketStateUtils?
    var outputStream : OutputStream?
    var transition : WebSocketTransition = .None
    var webSocketInputStream : WebSocketInputStream?
    
    func parse(buffer buf : UnsafeMutablePointer<UInt8>, size count : Int) -> Int{
        var processedBytes = 0
        let opcode = buf[0] & 0xf
        switch WebsocketOpCode(rawValue: opcode) {
        case .some(.Fragment):
            os_log(.debug, "==> Received Fragment Frame")
            processedBytes = handleMessageFrame(buf, count, false)
            break
        case .some(.TextFrame):
            os_log(.debug, "==> Received Text Frame")
            processedBytes = handleMessageFrame(buf, count, false)
            break
        case .some(.BinaryFrame):
            os_log(.debug, "==> Received BinaryFrame Frame")
            processedBytes = handleMessageFrame(buf, count, true)
            break
        case .some(.Ping):
            os_log(.debug, "==> Received Ping Frame")
            sendPong()
            processedBytes = 2
            break
        case .some(.Pong):
            processedBytes = 2
            os_log(.debug, "==> Received Pong Frame")
            receivedPong()
            break
        case .some(.Close):
            os_log(.debug, "==> Received Close Frame")
            receivedClose(buf)
            break
        default:
            break
        }
        os_log(.debug, "Processed %d bytes.", processedBytes)
        return processedBytes
    }
    
    private func handleMessageFrame(_ buf : UnsafeMutablePointer<UInt8>, _ size : Int, _ binary : Bool) -> Int {
        var processed = 0 // first byte
        var headersize = 2
        syncWebsocketInputStream(buf, size, binary)
        if( size >= 2 ) {
            let payloadlen = getPayloadLen(buf, size, &headersize)
            if ((payloadlen + headersize) <= size) {
                let data = ArraySlice(UnsafeBufferPointer(start: buf.advanced(by: headersize), count: payloadlen))
                processed = payloadlen + headersize
                if let wsi = webSocketInputStream {
                    notifyFragment(buf, wsi, data)
                }
                else if let ws = webSockStateUtils {
                    if binary {
                        ws.raiseBinaryMessage(data: data)
                    }
                    else {
                        let message = String(bytes: data, encoding: .utf8)
                        ws.raiseTextMessage(message: message!)
                    }
                }
            }
        }
        return processed
    }
    
    private func syncWebsocketInputStream(_ buf : UnsafeMutablePointer<UInt8>, _ size : Int, _ binary : Bool) {
        let fin = buf[0] & 0x80
        let opcode = buf[0] & 0x0f
        
        os_log(.debug, "Fin = %d", fin)
        if( (fin == 0) && webSocketInputStream == nil ){
            
            os_log(.debug, "Creating WebSocketInputStream")
            webSocketInputStream = WebSocketInputStream()
            if let ws = webSockStateUtils {
                ws.raiseReceivedStream(webSocketInputStream!)
                if opcode == WebsocketOpCode.BinaryFrame.rawValue {
                    webSocketInputStream?.isBinary = true
                }
            }
        }
    }
    
    private func getPayloadLen(_ buf : UnsafeMutablePointer<UInt8>, _ size : Int, _ headerSize : inout Int) -> Int{
        var payloadlen = Int(buf[1])
        if payloadlen <= 125 {
            return payloadlen
        }
        else if (payloadlen == 126 && size >= 4) {
            headerSize += 2
            var extendedLen : UInt16 = 0
            extendedLen = UInt16(buf[2]) << 8
            extendedLen |= UInt16(buf[3])
            payloadlen = Int(extendedLen)
        }
        return payloadlen
    }
    
    fileprivate func notifyFragment(_ buf: UnsafeMutablePointer<UInt8>, _ wsi: WebSocketInputStream, _ data: ArraySlice<UInt8>) {
        let fin = buf[0] & 0x80
        if fin == 0 {
            if let didReceiveFragmentCallback = wsi.didReceiveFragment {
                didReceiveFragmentCallback(data)
            }
        }
        else if let didCoseStream = wsi.didClose {
            didCoseStream(data)
        }
    }
    
    private func sendPong() {
        sendCode(code: WebsocketOpCode.Pong.rawValue)
    }
    
    func sendCode(code c : UInt8){
        if let os = outputStream {
            let frame : [UInt8] = [c | 0x80, 0x0]
            os.write(UnsafePointer<UInt8>(frame), maxLength: 2)
        }
    }
    
    private func receivedClose(_ buf : UnsafeMutablePointer<UInt8>) {
        let payloadLen = buf[1]
        var reason : UInt16 = 0
        
        if( payloadLen > 0 ) {
            let dataBytes = NSData(bytes: buf.advanced(by: 2), length: 2)
            dataBytes.getBytes(&reason, length: 2)
            reason = reason.byteSwapped
            
            os_log(.debug, "Close Reason: %d", reason)
        }
        
        if let os = outputStream {
            // echo back close
            let closeFrame : [UInt8] = [0x88, 0x0]
            os.write(UnsafePointer<UInt8>(closeFrame), maxLength: 2)
            webSockStateUtils?.closeStream(os)
        }
        
        webSockStateUtils?.raiseClose(reason: getReasonString(reason: reason))
        transition = .Idle
    }
    
    private func getReasonString(reason code : UInt16) ->String {
        var reasonMessage = "No reason given."
        switch code {
        case 1000:
            reasonMessage = "Clean close"
            break
        default:
            break
        }
        
        return reasonMessage
    }
    
    private func receivedPong() {
        if let ws = webSockStateUtils {
            ws.raisePong()
        }
    }
    
}
