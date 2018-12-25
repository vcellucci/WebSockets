//
//  WebSocketOutputStream.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/24/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
import os

public protocol WebSocketOutputStream {
    func setBinary(_ binary : Bool)
    func write(fragment data : ArraySlice<UInt8>)
    func reset()
    func close()
}

class NilWebSocketOutputStreamImpl : WebSocketOutputStream {
    
    func setBinary(_ binary : Bool){
    }

    func write(fragment data: ArraySlice<UInt8>) {
    }
    
    func reset(){
        
    }
    func close() {
    }
}

class WebSocketOutputStreamImpl : WebSocketOutputStream {
    private var isBinary = false
    private var isClosed = false
    private var isFirstFragment = true
    private var webSocketFrame = UnsafeMutablePointer<UInt8>.allocate(capacity: (1024*16)+8)
    
    var outStream : OutputStream?

    func setBinary(_ binary : Bool) {
        isBinary = binary
    }
    
    func reset() {
        isClosed = false
    }

    func write(fragment data: ArraySlice<UInt8>) {
        if let os = outStream {
            var headerSize = 6 // header size + mask
            var totalBytesToSend = data.count + headerSize
            var maskByteStart = 2
            let mask : [UInt8] = [0x1, 0x2, 0x3, 0x4]

            if isFirstFragment {
                if isBinary {
                    webSocketFrame[0] = WebsocketOpCode.BinaryFrame.rawValue
                }
                else {
                    webSocketFrame[0] = WebsocketOpCode.TextFrame.rawValue
                }
                isFirstFragment = false

            } else {
                webSocketFrame[0] = 0
            }
            
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
                totalBytesToSend += 2
            }
            
            for ubyte in mask {
                webSocketFrame[maskByteStart] = ubyte
                maskByteStart += 1
            }
            
            // mask
            for index in 0...data.count-1 {
                webSocketFrame[index+maskByteStart] = data[index] ^ mask[index%4]
            }
            
            let bytesSent = os.write(webSocketFrame, maxLength: totalBytesToSend)
            os_log(.debug, "Bytes sent %d", bytesSent)
        }
    }
    
    func close() {
        isClosed = true
        if let os = outStream {
            let data : [UInt8] = [0x80, 0x00]
            os.write(UnsafePointer<UInt8>(data), maxLength: 2)
        }
    }
    
    deinit {
        if !isClosed {
            os_log(.info, "Warning!!!  Output Stream is going away without a close")
        }
        webSocketFrame.deallocate()
    }
}
