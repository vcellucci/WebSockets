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
    
    private var bytesSent = 0
    private var webSocketFrame = UnsafeMutablePointer<UInt8>.allocate(capacity: (1024*64)+8)
    private var currentFrameSize = 0
    
    enum WebsocketOpCode : UInt8 {
        case TextFrame = 0x1
        case BinaryFrame = 0x2
        case Close = 0x8
        case Ping = 0x9
        case Pong = 0xa
    }
    
    func enter() {
        webSocketStateUtils?.raiseConnect()
    }
    
    func didReceiveData() -> WebSocketTransition {
        var transition : WebSocketTransition = .None
        if let ins = inputStream {
            ins.read(webSocketFrame, maxLength: ((1024*64) + 8))
            let opcode = webSocketFrame[0] & 0x0f
            
            switch WebsocketOpCode(rawValue: opcode) {
            case .some(.TextFrame):
                debugPrint("TextFrame data available")
                readTextData()
                break
            case .some(.Ping):
                //pong()
                break
            case .some(.Close):
                //close()
                transition = .Close
                break
            default:
                break
            }
        }
        return transition
    }
    
    private func readTextData() {
        let payloadLen = webSocketFrame[1]
        if payloadLen < 126 {
            let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by : 2), count: Int(payloadLen)))
            if let message = String(bytes: data, encoding: .utf8) {
                webSocketStateUtils?.raiseTextMessage(message: message)
            }
        }
        else if(payloadLen == 126){
            let dataBytes = NSData(bytes: webSocketFrame.advanced(by: 2), length: 2)
            var u16 : UInt16 = 0
            dataBytes.getBytes(&u16, length: 2)
            u16 = u16.byteSwapped
            
            let data = ArraySlice(UnsafeBufferPointer(start: webSocketFrame.advanced(by: 4), count: Int(u16)))
            if let message = String(bytes: data, encoding: .utf8) {
                webSocketStateUtils?.raiseTextMessage(message: message)
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
    
    func sendMessage(string msg : String) -> WebSocketTransition {
        debugPrint("Sending message: ", msg)
        let data = [UInt8](msg.utf8)
        sendData(data, WebsocketOpCode.TextFrame.rawValue)
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
    
    
    
    
}
