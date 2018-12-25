//
//  WebSocketStateStreaming.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/17/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
import os

class WebSocketStateStreaming : WebSocketState {
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var url: URL?
    var webSocketStateUtils : WebSocketStateUtils?
    var binary = false
    var currentSendPayloadLen = 0
    var totalBytesLeftToSend = 0
    var lastBytesSent = 0
    var webSocketFrameReader = WebSocketFrameReader()
    var webSocektInputStream : WebSocketInputStream?
    static let maxSize : Int = ((1024*64)+16)
    
    private var bytesSent = 0
    private var webSocketFrame = UnsafeMutablePointer<UInt8>.allocate(capacity: maxSize)
    private var currentFrameSize = 0
    
    func enter() {
        webSocketStateUtils?.raiseConnect()
        webSocketFrameReader._webSocketFrame = webSocketFrame
        webSocketFrameReader.webSocketStateUtils = webSocketStateUtils
    }
    
    func didReceiveData() -> WebSocketTransition {
        var transition : WebSocketTransition = .None
        if let ins = inputStream {
            let readBuffer = webSocketFrame.advanced(by: webSocketFrameReader.totalBytesRead)
            let bytesToRead = WebSocketStateStreaming.maxSize - webSocketFrameReader.totalBytesRead
            let bytesRead = ins.read(readBuffer, maxLength: bytesToRead)
            if( webSocketFrameReader.needsMore ){
                webSocketFrameReader.readData(binary, bytesRead)
                return .None
            }
            
            if( bytesRead > 0 ){
                dispatch(bytesRead, &transition)
            }
        }
        return transition
    }
    
    fileprivate func dispatch(_ bytesRead: Int, _ transition: inout WebSocketTransition) {
        let opcode = webSocketFrame[0] & 0x0f
        
        switch WebsocketOpCode(rawValue: opcode) {
        case .some(.Fragment):
            os_log(.info, "Fragment received.")
            webSocketFrameReader.readData(binary, bytesRead)
            break
        case .some(.TextFrame):
            os_log(.debug, "Text Frame received.")
            binary = false
            webSocketFrameReader.readData(binary, bytesRead)
            break
        case .some(.BinaryFrame):
            os_log(.debug, "Binary Frame received.")
            binary = true
            webSocketFrameReader.readData(binary, bytesRead)
            break
        case .some(.Pong):
            os_log(.debug, "Pong Frame received.")
            receivedPong()
            break
        case .some(.Ping):
            os_log(.debug, "Ping Frame received.")
            pong()
            break
        case .some(.Close):
            os_log(.debug, "Close Frame received.")
            receivedClose()
            transition = .Idle
            break
        default:
            break
        }
    }
    
    func canWriteData() -> WebSocketTransition {
        if let os = outputStream {
            if currentSendPayloadLen > 0 {
                let senData = webSocketFrame.advanced(by: lastBytesSent)
                let bytesSent = os.write(senData, maxLength: currentFrameSize)
                lastBytesSent = bytesSent
                totalBytesLeftToSend = currentSendPayloadLen - lastBytesSent
                currentSendPayloadLen -= lastBytesSent
            }
            
        }
        return .None
    }
    
    func getState() -> WebSocketTransition {
        return .Streaming
    }
    
    func send(bytes data: [UInt8], binary isBinary: Bool) -> WebSocketTransition {
        if(data.count >= 65536){
            return .None
        }
        
        if( isBinary ){
            sendData(data, WebsocketOpCode.BinaryFrame.rawValue)
        }
        else {
            sendData(data, WebsocketOpCode.TextFrame.rawValue)
        }
        return .None
    }
    
    private func sendData(_ data: [UInt8], _ messageType : UInt8){
        var headerSize = 6  // 2 + 4 min headersize
        var maskByteStart = 2
        let mask : [UInt8] = [0x1, 0x2, 0x3, 0x4]
        // first setup frame data
        webSocketFrame[0] = 0x80 | messageType // unfragemented message
        
        let payloadLen =  data.count//message.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        if( payloadLen < 126) {
            webSocketFrame[1] = 0x80 | UInt8(payloadLen)
        }
        else {
            let uint16Len = UInt16(payloadLen)
            webSocketFrame[1] = 0xfe
            webSocketFrame[2] = UInt8((uint16Len & 0xff00) >> 8)
            webSocketFrame[3] = UInt8(uint16Len & 0x00ff)
            
            headerSize += 2
            maskByteStart += 2
        }
        
        currentSendPayloadLen = payloadLen + headerSize

        for ubyte in mask {
            webSocketFrame[maskByteStart] = ubyte
            maskByteStart += 1
        }
        
        // mask
        for index in 0...data.count-1 {
            webSocketFrame[index+maskByteStart] = data[index] ^ mask[index%4]
        }
        
        let bytesSent = outputStream?.write(webSocketFrame, maxLength: currentSendPayloadLen)
        lastBytesSent = bytesSent!
        totalBytesLeftToSend = currentSendPayloadLen - lastBytesSent
        currentSendPayloadLen -= lastBytesSent
        
        os_log(.debug, "Sent bytes: %d", bytesSent!)
    }
    
    private func receivedClose() {
        let payloadLen = webSocketFrame[1]
        var reason : UInt16 = 0

        if( payloadLen > 0 ){
            let dataBytes = NSData(bytes: webSocketFrame.advanced(by: 2), length: 2)
            dataBytes.getBytes(&reason, length: 2)
            reason = reason.byteSwapped
            
            os_log(.debug, "Close Reason: %d", reason)
        }
        
        if let os = outputStream {
            // echo back close
            let closeFrame : [UInt8] = [0x88, 0x0]
            os.write(UnsafePointer<UInt8>(closeFrame), maxLength: 2)
            webSocketStateUtils?.closeStream(os)
        }
        
        webSocketStateUtils?.raiseClose(reason: getReasonString(reason: reason))
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
    
    func streamClosed(stream s: Stream) ->WebSocketTransition {
        webSocketStateUtils?.closeStream(s)
        webSocketStateUtils?.raiseError(error: "Unexpected Close during streaming.", code: NSError(domain: "WebSockets", code: -1, userInfo: nil))
        
        return .Idle
    }
    
    func ping() {
        sendCode(code: WebsocketOpCode.Ping.rawValue)
    }
    
    func pong () {
        sendCode(code: WebsocketOpCode.Pong.rawValue)
    }
    
    func sendCode(code c : UInt8){
        if let os = outputStream {
            let frame : [UInt8] = [c | 0x80, 0x0]
            os.write(UnsafePointer<UInt8>(frame), maxLength: 2)
        }
    }
    
    func receivedPong() {
        webSocketStateUtils?.raisePong()
    }
    
    func openWriteStream(binary isbinary: Bool) -> WebSocketOutputStream {
        let wsos = WebSocketOutputStreamImpl()
        wsos.setBinary(binary)
        wsos.outStream = outputStream
        return wsos
    }
    
    deinit {
        webSocketFrame.deallocate()
    }
}
