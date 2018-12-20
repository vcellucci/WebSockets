//
//  WebSocketStateStreaming.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/17/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
class WebSocketStateStreaming : WebSocketState{
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var url: URL?
    var webSocketStateUtils : WebSocketStateUtils?
    var initiatedClose = false
    
    private var bytesSent = 0
    private var webSocketFrame = UnsafeMutablePointer<UInt8>.allocate(capacity: (1024*64)+8)
    private var currentFrameSize = 0
    
    func enter() {
        webSocketStateUtils?.raiseConnect()
    }
    
    func didReceiveData() -> WebSocketTransition {
        var transition : WebSocketTransition = .None
        if let ins = inputStream {
            let bytesRead = ins.read(webSocketFrame, maxLength: ((1024*64) + 8))
            if( bytesRead > 0 ){
                let opcode = webSocketFrame[0] & 0x0f
                
                switch WebsocketOpCode(rawValue: opcode) {
                case .some(.TextFrame):
                    debugPrint("TextFrame data available")
                    readData(false)
                    break
                case .some(.BinaryFrame):
                    readData(true)
                    break
                case .some(.Ping):
                    //pong()
                    break
                case .some(.Close):
                    receivedClose()
                    transition = .Idle
                    break
                default:
                    break
                }
            }
        }
        return transition
    }
    
    private func readData(_ binary : Bool) {
        let payloadLen = webSocketFrame[1]
        if payloadLen < 126 {
            let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by : 2), count: Int(payloadLen)))
            notifyData(data, binary)
        }
        else if(payloadLen == 126){
            let dataBytes = NSData(bytes: webSocketFrame.advanced(by: 2), length: 2)
            var u16 : UInt16 = 0
            dataBytes.getBytes(&u16, length: 2)
            u16 = u16.byteSwapped
            
            let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by: 4), count: Int(u16)))
            notifyData(data, binary)
        }
    }
    
    private func notifyData(_ arraySlice : ArraySlice<UInt8>, _ binary : Bool) {
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
    
    func canWriteData() -> WebSocketTransition {
        if let os = outputStream {
            var totalSent = bytesSent
            while currentFrameSize > 0 && os.hasSpaceAvailable {
                let sendData = webSocketFrame.advanced(by: totalSent)
                bytesSent = os.write(sendData, maxLength: currentFrameSize)
                currentFrameSize -= bytesSent
                totalSent += bytesSent
            }
        }
        return .None
    }
    
    func getState() -> WebSocketTransition {
        return .Streaming
    }
    
    func send(bytes data: [UInt8], binary isBinary: Bool) -> WebSocketTransition {
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
        
        for ubyte in mask {
            webSocketFrame[maskByteStart] = ubyte
            maskByteStart += 1
        }
        
        // mask
        for index in 0...data.count-1 {
            webSocketFrame[index+maskByteStart] = data[index] ^ mask[index%4]
        }
        
        let bytesSent = outputStream?.write(webSocketFrame, maxLength: (headerSize + data.count))
        debugPrint("Sent bytes:", bytesSent!)
    }
    
    private func receivedClose() {
        let payloadLen = webSocketFrame[1]
        var reason : UInt16 = 0

        if( payloadLen > 0 ){
            let dataBytes = NSData(bytes: webSocketFrame.advanced(by: 2), length: 2)
            dataBytes.getBytes(&reason, length: 2)
            reason = reason.byteSwapped
            debugPrint("Close Reason: ", reason)
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
}
