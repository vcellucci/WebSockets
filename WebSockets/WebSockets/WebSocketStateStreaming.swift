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
    var frameParser = WebSocketFrameParser()
    var webSocektInputStream : WebSocketInputStream?
    static let maxSize : Int = ((1024*64)+16)
    
    private var bytesSent = 0
    private var webSocketFrame = UnsafeMutablePointer<UInt8>.allocate(capacity: maxSize)
    private var currentFramData : UnsafeMutablePointer<UInt8>?
    private var currentFrameSize = 0
    private var circularBuffer = CircularBuffer<UInt8>(capacity: maxSize)

    private var bytesProcessed = 0
    
    func enter() {
        webSocketStateUtils?.raiseConnect()
        frameParser.webSockStateUtils = webSocketStateUtils
        frameParser.outputStream = outputStream
    }
    
    func didReceiveData() -> WebSocketTransition {
        var transition : WebSocketTransition = .None
        os_log(.debug, "WebSocketStateStreaming: received data.")
        if let ins = inputStream {
           
            while( ins.hasBytesAvailable ){
                os_log(.debug, "Reading %d bytes...", circularBuffer.availableToWrite())
                let bytesRead = ins.read(circularBuffer.getWritePtr()!, maxLength: circularBuffer.availableToWrite())
                _ = circularBuffer.bump(count: bytesRead)
                os_log(.debug, "Bytes read = %d, bytes in buffer = %d", bytesRead, circularBuffer.availableToRead())

                var processing = true
                while( (circularBuffer.availableToRead() > 0) && processing ){
                    let processed = frameParser.parse(buffer: circularBuffer)
                    
                    os_log(.debug, "Processed %d, left in buffer = %d", processed, circularBuffer.availableToRead())
                    if  circularBuffer.availableToRead() == 0 {
                        os_log(.debug, "Buffer now empty, resetting")
                        circularBuffer.reset()
                    }
                    else if processed == 0 {
                        os_log(.debug, "Needs more data.")
                        processing = false
                    }
                    else {
                        os_log(.debug, "Still more data in buffer: %d", circularBuffer.availableToRead())
                        currentFramData = currentFramData?.advanced(by: processed)
                    }
                }
            }
            transition = frameParser.transition
        }
        return transition
    }
    
    func canWriteData() -> WebSocketTransition {
        os_log(.debug, "Can write!")
        /*if let os = outputStream {
            if currentSendPayloadLen > 0 {
                let senData = webSocketFrame.advanced(by: lastBytesSent)
                let bytesSent = os.write(senData, maxLength: currentFrameSize)
                lastBytesSent = bytesSent
                totalBytesLeftToSend = currentSendPayloadLen - lastBytesSent
                currentSendPayloadLen -= lastBytesSent
            }
        }*/
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
    
    func streamClosed(stream s: Stream) ->WebSocketTransition {
        webSocketStateUtils?.closeStream(s)
        webSocketStateUtils?.raiseError(error: "Unexpected Close during streaming.", code: NSError(domain: "WebSockets", code: -1, userInfo: nil))
        
        return .Idle
    }
    
    func ping() {
        if let os = outputStream {
            let frame : [UInt8] = [WebsocketOpCode.Ping.rawValue | 0x80, 0x0]
            os.write(UnsafePointer<UInt8>(frame), maxLength: 2)
        }
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
