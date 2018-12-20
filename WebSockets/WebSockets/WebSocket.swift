//
//  WebSocket.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/16/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation

public class WebSocket : NSObject, StreamDelegate {
  
    public var secure : Bool = false
    public var didConnect : (()->())?
    public var didReceiveMessage : ( (String)->() )?
    public var didReceiveBinary : ( (ArraySlice<UInt8>)->() )?
    public var didReceiveError : ( (String)->() )?
    public var didClose : (()->())?
    public var additionalHeaders  = [String:String]()
    
    private var webSocketStateUtils = WebSocketStateUtils()
    private var inputStream : InputStream?
    private var outputStream : OutputStream?
    private var currentSate : WebSocketState?
    private var currentUrl : URL?
    
    // Opens an endpoint and begins the upgrade process, the socket is not yet connected.
    public func open(location url : String) -> Bool {
        
        webSocketStateUtils.didReceiveError = self.didReceiveError

        currentUrl = URL(string: url)
        // ws://echo.websocket.org
        if( currentUrl?.host == nil ){
            webSocketStateUtils.raiseError(error : "Host cannot be nil")
            return false;
        }
        
        Stream.getStreamsToHost(withName: (currentUrl?.host)!, port: getPort(currentUrl), inputStream: &inputStream, outputStream: &outputStream)
        
        // both have to be valid
        if( inputStream == nil || outputStream == nil ) {
            webSocketStateUtils.raiseError(error: "Failed to open streams to host: " + url)
            return false
        }

        changeState(.Upgrade, currentUrl!)
    
        openStream(inputStream!)
        openStream(outputStream!)
        
        return true;
    }
    
    private func getPort(_ fullUrl : URL? ) -> Int {
        if( fullUrl?.port == nil ){
            if let scheme = fullUrl?.scheme {
                if( scheme == "ws"){
                    return 80
                }
                
                if( scheme == "wss" ){
                    secure = true
                    return 443
                }
            }
            // default return 80
            return 80
        }
        return (fullUrl?.port)!
    }
    
    private func openStream( _ stream : Stream ) {
        if secure {
            stream.setProperty(StreamSocketSecurityLevel.tlSv1, forKey: .socketSecurityLevelKey)
        }
        stream.delegate = self
        stream.schedule(in: .main, forMode: .default)
        stream.open()
    }
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        var state = WebSocketTransition.None
        if( aStream == outputStream && eventCode == .hasSpaceAvailable ){
            state = (currentSate?.canWriteData())!
        }
        
        if( aStream == inputStream && eventCode == .hasBytesAvailable ){
            state = (currentSate?.didReceiveData())!
        }
        
        if( state != .None && state != currentSate?.getState()){
            changeState(state, currentUrl!)
        }
    }
    
    fileprivate func changeState(_ state : WebSocketTransition, _ url : URL) {
        createState(state)
   
        webSocketStateUtils.didClose = didClose
        webSocketStateUtils.didConnect = didConnect
        webSocketStateUtils.didReceiveError = didReceiveError
        webSocketStateUtils.didReceiveMessage = didReceiveMessage
        webSocketStateUtils.didReceiveBinary = didReceiveBinary
        webSocketStateUtils.additionalHeaders = additionalHeaders
   
        currentSate?.webSocketStateUtils = webSocketStateUtils
        currentSate?.inputStream  = inputStream
        currentSate?.outputStream = outputStream
        currentSate?.url = url
        currentSate?.enter()
    }
    
    fileprivate func createState(_ state: WebSocketTransition) {
        switch state {
        case .Upgrade:
            currentSate = WebSocketStateUpgrade()
            debugPrint("Changing state to Upgrade.")
            break
        case .Streaming:
            debugPrint("Changing state to Streaming.")
            currentSate = WebSocketStateStreaming()
            break
        case .Close:
            debugPrint("Changing State to Close")
            currentSate = WebSocketStateClose()
        default:
            break
        }
    }
    
    public func sendMessage(string msg : String){
        let data = [UInt8](msg.utf8)
        sendData(bytes: data, binary: false)
    }
    
    public func sendBinary(bytes data: [UInt8]) {
        sendData(bytes: data, binary: true)
    }
    
    private func sendData(bytes data: [UInt8], binary : Bool){
        let result = currentSate?.send(bytes: data, binary: binary)
        if let state = result {
            if( state != .None ){
                changeState(state, currentUrl!)
            }
        }
    }
    
    public func close() {
        if let url = currentUrl {
            changeState(.Close, url)
        }
    }
}
