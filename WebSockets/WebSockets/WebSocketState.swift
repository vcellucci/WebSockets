//
//  WebSocketState.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/17/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
import os

enum WebSocketTransition {
    case None
    case Upgrade
    case Streaming
    case Close
    case Idle
}

enum WebsocketOpCode : UInt8 {
    case Fragment = 0x0
    case TextFrame = 0x1
    case BinaryFrame = 0x2
    case Close = 0x8
    case Ping = 0x9
    case Pong = 0xa
}

class WebSocketStateUtils {
    var didReceiveError: ((String, Error)->())?
    var didClose: ((String)->())?
    var didConnect : (()->())?
    var didReceiveMessage : ((String)->())?
    var didReceiveBinary : ((ArraySlice<UInt8>)->())?
    var additionalHeaders = [String:String]()
    var didReceivePong : (()->())?
    var didReceiveStream : ((WebSocketInputStream)->())?
    
    func raiseError(error msg : String, code c : Error ){
        os_log(.debug,"%{public}@", msg)
        if let didReceiveErrorCallback = didReceiveError {
            didReceiveErrorCallback(msg, c)
        }
    }
    
    func raiseClose(reason msg : String) {
        if let didCloseCallback = didClose {
            didCloseCallback(msg)
        }
    }
    
    func raiseConnect() {
        if let didConnectCallback = didConnect {
            didConnectCallback()
        }
    }
    
    func raiseTextMessage(message msg : String){
        if let didReceiveMessageCallback = didReceiveMessage {
            didReceiveMessageCallback(msg)
        }
    }
    
    func raiseBinaryMessage(data bytes: ArraySlice<UInt8>){
        if let didReceiveBinaryCallback = didReceiveBinary {
            didReceiveBinaryCallback(bytes)
        }
    }
    
    func closeStream(_ stream : Stream ){
        stream.remove(from: .main, forMode: .default)
        stream.close()
    }
    
    func raisePong() {
        if let didReceivePongCallback = didReceivePong {
            didReceivePongCallback()
        }
    }
    
    func raiseReceivedStream(_ stream : WebSocketInputStream) {
        if let didReceiveStreamCb = didReceiveStream {
            didReceiveStreamCb(stream)
        }
    }
}

protocol WebSocketState {
    var inputStream  : InputStream?     { get set }
    var outputStream : OutputStream?    { get set }
    var url : URL? { get set }
    var webSocketStateUtils : WebSocketStateUtils?  { get set }
    
    func didReceiveData() -> WebSocketTransition
    func canWriteData() -> WebSocketTransition
    func getState() -> WebSocketTransition
    func send(bytes data : [UInt8], binary isBinary : Bool) -> WebSocketTransition
    func enter()
    func streamClosed(stream s : Stream) -> WebSocketTransition
    func ping()
    func openWriteStream(binary isbinary : Bool) -> WebSocketOutputStream
}
