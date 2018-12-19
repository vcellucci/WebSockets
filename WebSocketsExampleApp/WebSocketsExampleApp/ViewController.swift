//
//  ViewController.swift
//  WebSocketsExampleApp
//
//  Created by Vittorio Cellucci on 12/19/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import UIKit
import WebSockets

class ViewController: UIViewController {

    var webSocket = WebSocket()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        webSocket.didConnect = {
            print("Connected")
            self.webSocket.sendMessage(string: "Hello, world!")
        }
        
        webSocket.didReceiveMessage = {
            (message) in
            print("Received a message! ", message)
        }
        
        if(!webSocket.open(location: "ws://echo.websocket.org")){
            print("Failed to open")
        }
    }


}

