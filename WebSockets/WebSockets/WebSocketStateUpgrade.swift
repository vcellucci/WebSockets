//
//  WebSocketStateUpgrade.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/17/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
import os

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
        os_log(.error, "Cannot unwrap result from WebSocketStateUpgrade")
        return .Close
    }
    
    func parse(_ response : String) -> Bool {
        var lines = response.components(separatedBy: "\r\n")
        if( lines.count == 0 ){
            os_log(.error, "Invalid respose")
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
            os_log(.error, "Invalid response, no status code found")
            return false;
        }
        
        if( words[1] != "101" ){
            os_log(.error, "Unexpected status code: ", words[1])
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
        
        let requestString = buildRequestString()
        writeString(requestString)
        return .None
    }
    
    func buildRequestString() -> String {
        var requestString = "GET / HTTP/1.1\r\n"
        if var path = url?.path{
            if path.isEmpty {
                path = "/"
            }
            requestString = "GET " + path + " HTTP/1.1\r\n"
        }
        requestString += "Host: echo.websocket.org\r\n"
        requestString += "Upgrade: websocket\r\n"
        requestString += "Connection: Upgrade\r\n"
        requestString += "Origin: ws://echo.websocket.org\r\n"
        requestString += "Sec-WebSocket-Version: 13\r\n"
        requestString += "Sec-WebSocket-Key: " + generateKey() + "\r\n"
        
        if let headers = webSocketStateUtils?.additionalHeaders {
            for( key, value ) in headers {
                requestString += key + ": " + value + "\r\n"
            }
        }
        
        requestString += "\r\n"
        return requestString
    }
    
    func generateKey() -> String {
        let chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let key = String((0...15).map{_ in chars.randomElement()!})
        return Data(key.utf8).base64EncodedString()
    }
    
    func writeString(_ requestString : String) {
        let data = [UInt8](requestString.utf8)
        outputStream?.write(data, maxLength: data.count)
    }
    
    func send(bytes data: [UInt8], binary isBinary: Bool) -> WebSocketTransition {
        os_log(.info, "Message sent before handshake finished.  This message will not be sent")
        return .None
    }
    
    func streamClosed(stream s: Stream) ->WebSocketTransition {
        webSocketStateUtils?.raiseError(error: "Unexpected Close during upgrade.", code: NSError(domain: "WebSockets", code: -1, userInfo: nil))
        return .Idle
    }
    
    func ping () {
        os_log(.info, "Handshake not complete, ping not sent")
    }
    
    func openWriteStream(binary isbinary: Bool) -> WebSocketOutputStream {
        os_log(.info, "Trying to open an output stream when handshake not complete.")
        return NilWebSocketOutputStreamImpl()
    }
    
    deinit {
        buffer.deallocate()
    }
    
}
