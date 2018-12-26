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
    
    func parse(buffer buf : UnsafeMutablePointer<UInt8>, size count : Int) -> Int{
        var processedBytes = 0
        let opcode = buf[0] & 0xf
        switch WebsocketOpCode(rawValue: opcode) {
        case .some(.TextFrame):
            os_log(.debug, "Received Text Frame")
            processedBytes = handleTextFrame(buf, count)
            break
        case .some(.Ping):
            os_log(.debug, "Received Ping Frame")
            sendPong()
            processedBytes = 2
            break
        case .some(.Pong):
            processedBytes = 2
            receivedPong()
            break
        case .some(.Close):
            receivedClose(buf)
            break
        default:
            break
        }
        os_log(.debug, "Processed %d bytes.", processedBytes)
        return processedBytes
    }
    
    private func handleTextFrame(_ buf : UnsafeMutablePointer<UInt8>, _ size : Int) -> Int {
        var processed = 0 // first byte
        var headersize = 2
        if( size >= 2 ) {
            var payloadlen = Int(buf[1])
            if payloadlen <= 125 && payloadlen <= size {
                let data = ArraySlice(UnsafeBufferPointer(start: buf.advanced(by: 2), count: payloadlen))
                let message = String(bytes: data, encoding: .utf8)
                processed = headersize + payloadlen
                notifyTextMessage(message!)
            }
            else if payloadlen == 126 {
                headersize += 2
                var extendedLen : UInt16 = 0
                extendedLen = UInt16(buf[2]) << 8
                extendedLen |= UInt16(buf[3])
                payloadlen = Int(extendedLen)
                if( (payloadlen+headersize) <= size) {
                    let data = ArraySlice(UnsafeBufferPointer(start: buf.advanced(by: 4), count: payloadlen))
                    let message = String(bytes: data, encoding: .utf8)
                    processed = headersize + payloadlen
                    notifyTextMessage(message!)
                }
            }
            
        }
        return processed
    }
    
    private func notifyTextMessage(_ message : String) {
        if let utils = webSockStateUtils {
            utils.raiseTextMessage(message: message)
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
