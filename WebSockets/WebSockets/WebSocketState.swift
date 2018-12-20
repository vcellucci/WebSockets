//
//  WebSocketState.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/17/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation

enum WebSocketTransition {
    case None
    case Upgrade
    case Streaming
    case Close
}

enum WebsocketOpCode : UInt8 {
    case TextFrame = 0x1
    case BinaryFrame = 0x2
    case Close = 0x8
    case Ping = 0x9
    case Pong = 0xa
}

class WebSocketStateUtils {
    var didReceiveError: ((String)->())?
    var didClose: (()->())?
    var didConnect : (()->())?
    var didReceiveMessage : ((String)->())?
    var didReceiveBinary : ((ArraySlice<UInt8>)->())?
    var additionalHeaders = [String:String]()
    
    func raiseError(error msg : String ){
        debugPrint(msg)
        if let didReceiveErrorCallback = didReceiveError {
            didReceiveErrorCallback(msg)
        }
    }
    
    func raiseClose() {
        if let didCloseCallback = didClose {
            didCloseCallback()
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
}
