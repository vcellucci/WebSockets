# WebSockets
Swift WebSockets Framework for iOS.  
This Websocket Framework is aimed at providing a swift implementation of the Websocket RFC.

## Limitations
1. The websockets only support messsage sizes up to 64K

### TODO:
1. Implement Fragmented messages
2. Implement Ping
3. Implement Clean closure
4. Implement additional Headers.

#### Getting Started

The websocket framework will do its best to determine if it's a secure socket.  by passing `wss://` as the location, it will
automatically pick TlSv1.  If for some reason, this is not possible, then set the member `secure` to true.

1. Add the Framework as an embedded binary to your app
2. This framework uses callbacks instead of a protocol for finer grain usage
3. After the callbacks of interest have been implemented, open the websocket

``` Swift

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
        
        webSocket.didReceiveError = {
            (message) in
            print("Receved error: ", message)
        }
        
        webSocket.didClose = {
            print("Closed")
        }
        
        if(!webSocket.open(location: "ws://echo.websocket.org")){
            print("Failed to open")
        }
    }
}
```

