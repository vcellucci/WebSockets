# WebSockets
Swift 4.2 WebSockets Framework for iOS.  
This Websocket Framework is aimed at providing a swift implementation of the Websocket RFC.

## Limitations
1. The websockets only support messsage sizes up to 64K

### TODO:
1. Implement Fragmented messages

### Getting Started

The websocket framework will do its best to determine if it's a secure socket.  by passing `wss://` as the location, it will
automatically pick TlSv1.  If for some reason, this is not possible, then set the member `secure` to true.

1. Add the Framework as an embedded binary to your app
2. This framework uses callbacks instead of a protocol for finer grain usage
3. After the callbacks of interest have been implemented, open the websocket

#### Instantiate the websocket
``` Swift
    var webSocket = WebSocket()
```

#### Setup the callbacks
``` Swift
    webSocket.didConnect = {
        print("Connected")
        self.webSocket.sendMessage(string: "Hello, world!")
    }
    
    webSocket.didReceiveMessage = {
        (message) in
        print("Received a message! ", message)
    }
    
    webSocket.didReceiveError = {
        (message, code) in
        print("Receved error: ", message, " code = ", code.localizedDescription)
    }
    
    webSocket.didClose = {
        (reason) in
        print("Closed because; ", reason)
    }
```

#### Add any additional headers like a JWT
``` Swift
    webSocket.additionalHeaders = ["Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"]
```

#### Open the websocket
As stated earlier, the WebSocket will do its best to decide on using TLS or not.  If connecting with `wss` it will use TLSv1.
Use a standard URL for the location such as `wss://foo.bar:1234/notifications`
``` Swift
    if(!webSocket.open(location: "wss://echo.websocket.org")){
        print("Failed to open")
    }
```

#### Sending pings
Websockets supports a ping frame.  The client can send a ping via `.sendPing()` method.  When it receives a pong, the `didReceivePong` method will be called.  View the Example code for an implementation.

``` Swift
    webSocket.didReceivePong = {
        self.showPongAlert()
    }

    // somewhere in code
    webSocket.sendPing()

```
In the background, if the server sends a ping, the Framework will return a pong as soon as possible.

#### Putting it all together 

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
            (message, code) in
            print("Receved error: ", message, " code = ", code.localizedDescription)
        }
        
        webSocket.didClose = {
            (reason) in
            print("Closed because; ", reason)
        }

        webSocket.additionalHeaders = ["Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"]
        
        if(!webSocket.open(location: "ws://echo.websocket.org")){
            print("Failed to open")
        }
    }
}
```
