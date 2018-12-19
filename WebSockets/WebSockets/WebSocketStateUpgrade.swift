//
//  WebSocketStateUpgrade.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/17/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation

class WebSocketStateUpgrade : WebSocketState {
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var url : URL?
    var sendUpgrade = true
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2048)
    var webSocketStateUtils: WebSocketStateUtils?
    
    
    func enter (){}
    
    func getState() -> WebSocketTransition {
        return .Upgrade
    }
    
    func didReceiveData() -> WebSocketTransition {
        let result = inputStream?.read(buffer, maxLength: 2048)
        if let bytesRead = result {
            let a = UnsafeMutableBufferPointer(start: buffer, count: bytesRead)
            if let tempArray = String(bytes: a, encoding: .utf8) {
                if(parse(tempArray) ) {
                    return .Streaming
                }
                return .Close
            }
        }
        debugPrint("Cannot unwrap result from WebSocketStateUpgrade")
        return .Close
    }
    
    func parse(_ response : String) -> Bool {
        var lines = response.components(separatedBy: "\r\n")
        if( lines.count == 0 ){
            debugPrint("Invalid respose")
            return false;
        }
        
        if( parseStatusLine(lines[0]) == false ){
            return false
        }
        
        return true
    }
    
    fileprivate func parseStatusLine(_ line : String) ->Bool {
        var words = line.components(separatedBy: " ")
        // get status code
        if( words.count < 2 ){
            debugPrint("Invalid response, no status code found")
            return false;
        }
        
        if( words[1] != "101" ){
            debugPrint("Unexpected status code: ", words[1])
            return false
        }
        return true;
    }
    
    func canWriteData() ->WebSocketTransition {
        
        if( !sendUpgrade ){
            return .None
        }
        
        if(url == nil ){
            return .Close;
        }
        
        sendUpgrade = false
        
        func buildRequestString() -> String {
            var requestString = "GET / HTTP/1.1\r\n"
            requestString += "Host: echo.websocket.org\r\n"
            requestString += "Upgrade: websocket\r\n"
            requestString += "Connection: Upgrade\r\n"
            requestString += "Origin: ws://echo.websocket.org\r\n"
            requestString += "Sec-WebSocket-Version: 13\r\n"
            requestString += "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
            print(requestString)
            return requestString
        }
        
        let requestString = buildRequestString()
        writeString(requestString)
        return .None
    }
    
    func writeString(_ requestString : String) {
        let data = [UInt8](requestString.utf8)
        outputStream?.write(data, maxLength: data.count)
    }
    
    func sendMessage(string msg : String) -> WebSocketTransition {
        debugPrint("Warning, message sent before handshake finished.  This message will not be sent")
        return .None
    }
    
}
