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
    var count = 0
    @IBOutlet weak var serverAddress: UITextField!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var messageToSend: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var receivedMessage: UITextView!
    @IBOutlet weak var pingButton: UIButton!
    @IBOutlet weak var generateButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        updateUiToClosed()
        
        messageToSend.layer.borderWidth = 1
        receivedMessage.layer.borderWidth = 1
        
        webSocket.didConnect = {
            print("Connected")
            self.updateUiToOpened()
        }
        
        webSocket.didReceiveMessage = {
            (message) in
            self.receivedMessage.text = message
            self.receivedMessage.setNeedsDisplay()
        }
        
        webSocket.didReceiveBinary = {
            (data) in
            print("Received binary data")
        }
        
        webSocket.didReceiveError = {
            (message, code) in
            print("Receved error: ", message, " code = ", code.localizedDescription)
            self.updateUiToClosed()
        }
        
        webSocket.didReceivePong = {
            self.showPongAlert()
        }
        
        webSocket.didClose = {
            (reason) in
            print("Closed because; ", reason)
            self.updateUiToClosed()
        }
    }
    
    private func updateUiToClosed() {
        closeButton.isEnabled = false
        sendButton.isEnabled = false
        messageToSend.isEditable = false
        pingButton.isEnabled = false
        generateButton.isEnabled = false
        
        connectButton.isEnabled = true
    }
    
    private func updateUiToOpened() {
        closeButton.isEnabled = true
        sendButton.isEnabled = true
        messageToSend.isEditable = true
        pingButton.isEnabled = true
        generateButton.isEnabled = true

        connectButton.isEnabled = false
    }
    
    private func showPongAlert() {
        let alertController = UIAlertController(title: "Pong!", message: "", preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.default, handler: nil))
        self.present(alertController, animated: true)
    }
    
    @IBAction func onConnect(_ sender: UIButton) {
        if let host = serverAddress.text {
            connectButton.isEnabled = false
            webSocket.additionalHeaders = ["Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"]
            
            if(!webSocket.open(location: host)){
                print("Failed to open")
            }
        }
    }
    
    @IBAction func onSend(_ sender: UIButton) {
        if let message = messageToSend.text {
            if !message.isEmpty {
                webSocket.sendMessage(string: message)
            }
        }
    }
    
    @IBAction func onClose(_ sender: UIButton) {
        closeButton.isEnabled = false
        webSocket.close()
    }
    
    @IBAction func onPingButton(_ sender: UIButton) {
        webSocket.sendPing()
    }
    
    @IBAction func onGenerate(_ sender: UIButton) {
        let chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let message = String((0...62000).map{_ in chars.randomElement()!})
        messageToSend.text = message
    }
    
    @IBAction func onVerify(_ sender: UIButton) {
        let sent = messageToSend.text
        let recv = receivedMessage.text
        if( sent == recv ){
            showMessage("Strings match")
        }
        else {
            showMessage("Mistmatched strings.")
        }
    }
    
    private func showMessage(_ message : String) {
        let alertController = UIAlertController(title: "Message", message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.default, handler: nil))
        self.present(alertController, animated: true)
    }
    
    @IBAction func onClearMessageToSend(_ sender: UIButton) {
        messageToSend.text = ""
        messageToSend.setNeedsDisplay()
    }
}

