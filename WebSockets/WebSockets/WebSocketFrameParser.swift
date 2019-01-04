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
    var fin : UInt8 = 0
    
    func parse(buffer buf : CircularBuffer<UInt8>) -> Int{
        var processedBytes = 0
        if buf.availableToRead() < 0 {
            os_log(.debug, "Not enough bytes in buffer to process: %d", buf.availableToRead())
            return processedBytes
        }
        
        guard let readBuf = buf.getReadPtr() else {
            os_log(.error, "Invalid read buffer.")
            return 0
        }
        
        let opcode = readBuf[0] & 0xf
        switch WebsocketOpCode(rawValue: opcode) {
        case .some(.Fragment):
            os_log(.debug, "==> Received Fragment Frame")
            processedBytes = handleMessageFrame(buf, false)
            break
        case .some(.TextFrame):
            os_log(.debug, "==> Received Text Frame")
            processedBytes = handleMessageFrame(buf, false)
            break
        case .some(.BinaryFrame):
            os_log(.debug, "==> Received BinaryFrame Frame")
            processedBytes = handleMessageFrame(buf, true)
            break
        case .some(.Ping):
            os_log(.debug, "==> Received Ping Frame")
            processedBytes = buf.consume(count: 2)
            sendPong()
            break
        case .some(.Pong):
            processedBytes = buf.consume(count: 2)
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
    
    private func handleMessageFrame(_ buf : CircularBuffer<UInt8>, _ binary : Bool) -> Int {
        var processed = 0 // first byte
        var headersize = 2
        syncWebsocketInputStream(buf, binary)
        let payloadlen = getPayloadLen(buf, &headersize)
        if ((payloadlen + headersize) <= buf.availableToRead()) {
            _ = buf.consume(count: headersize)
            let data = buf.getData(count: payloadlen)//ArraySlice(UnsafeBufferPointer(start: buf.advanced(by: headersize), count: payloadlen))
            processed = payloadlen + headersize
            if let wsi = webSocketInputStream {
                notifyFragment(buf, wsi, data)
            }
            else if let ws = webSockStateUtils {
                if binary {
                    //ws.raiseBinaryMessage(data: data)
                }
                else {
                    let message = String(bytes: data, encoding: .utf8)
                    ws.raiseTextMessage(message: message!)
                }
            }
        }
        
        return processed
    }
    
    private func syncWebsocketInputStream(_ buf :  CircularBuffer<UInt8>, _ binary : Bool) {
        guard let readBuf = buf.getReadPtr() else {
            return
        }
        
        fin = readBuf[0] & 0x80
        let opcode = readBuf[0] & 0x0f
        
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
    
    private func getPayloadLen(_ buf : CircularBuffer<UInt8>, _ headerSize : inout Int) -> Int{
        guard let readBuf = buf.getReadPtr() else { return 0 }
        var payloadlen = Int(readBuf[1])
        if payloadlen <= 125 {
            return payloadlen
        }
        else if (payloadlen == 126 && buf.availableToRead() >= 4) {
            headerSize += 2
            var extendedLen : UInt16 = 0
            extendedLen = UInt16(readBuf[2]) << 8
            extendedLen |= UInt16(readBuf[3])
            payloadlen = Int(extendedLen)
        }
        os_log(.debug, "getPayloadLen() = %d, size = %d", payloadlen, buf.availableToRead())
        return payloadlen
    }
    
    fileprivate func notifyFragment(_ buf: CircularBuffer<UInt8>, _ wsi: WebSocketInputStream, _ data: Array<UInt8>) {
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
    
    private func receivedClose(_ buf : CircularBuffer<UInt8>) {
        guard let readBuf = buf.getReadPtr() else { return }
        let payloadLen = readBuf[1]
        var reason : UInt16 = 0

        if( payloadLen > 0 ) {
            _ = buf.consume(count: 2)
            let dataBytes = buf.getData(count: 2)
            let data = NSData(bytes: dataBytes, length: 2)
            data.getBytes(&reason, length: 2)
            reason = reason.byteSwapped
            os_log(.debug, "Close Reason: %d", dataBytes)
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
