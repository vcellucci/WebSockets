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

class WebSocketStateUtils {
    var didReceiveError: ((String)->())?
    var didClose: (()->())?
    var didConnect : (()->())?
    var didReceiveMessage : ((String)->())?
    
    func raiseError(error msg : String ){
        debugPrint(msg)
        if let didReceiveErrorCallback = didReceiveError {
            didReceiveErrorCallback(msg)
        }
    }
    
    func raiseClose() {
        debugPrint("Clean close.")
        if let didCloseCallback = didClose {
            didCloseCallback()
        }
    }
    
    func raiseConnect() {
        debugPrint("Connected.")
        if let didConnectCallback = didConnect {
            didConnectCallback()
        }
    }
    
    func raiseTextMessage(message msg : String){
        if let didReceiveMessageCallback = didReceiveMessage {
            didReceiveMessageCallback(msg)
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
    func sendMessage(string msg : String) -> WebSocketTransition
    func sendBinary(bytes data : [UInt8]) -> WebSocketTransition
    func enter()
}
