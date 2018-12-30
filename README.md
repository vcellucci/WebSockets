# WebSockets
Easy to use, no dependencies, Swift 4.2 WebSockets Framework for iOS.  
This Websocket Framework is aimed at providing a swift implementation of the Websocket RFC.

## Constraint
Message sizes have a limit of 64KB.  However, streaming is supported via Websocket fragments.  See the section Streaming.  Streaming is recomended for messages over 1K.

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

#### Streaming
Streaming is done through message fragmentation.  To write a stream, the call to `openWriteStream` will return a `WebSocketOutputStream`.  From there, `WebSocketOutputStream.write` can be used
to write fragments to the websocket. `WebSocketOutputStream.close` can be called once done.   Streaming is great when the size of messages are unknown.  Fragments should not be larger than 16KB.  
There is future plans to make this value configurable, up to 64KB.

The following code assumes data that is evenly divisible by 16KB and can be partitioned at 16KB chunks.  The close data is being ignored in this example.

``` Swift
let wos = webSocket.openWriteStream(binary: false)
let chunkSize = 1024*16
let chunks = data.count / chunkSize
var totalWritten = 0
for i in 0..<chunks {
    let start = i * chunkSize
    let end   = start + chunkSize                   
    wos.write(fragment: data[start..<end])
    totalWritten += chunkSize
}

wos.close("put leftover/signals data in here")
```

To Receive a stream, the `WebSocket.didReceiveStream` will called with a `WebSocketInputStream`. Then `WebSocketInputStream.didReceiveFragment` will be called for each fragment. `WebSocketInputStream.didClose` will be called once the stream is closed.

``` Swift
webSocket.didReceiveStream = {
    (webSocketInputStream) in
    let win = webSocketInputStream
    win.didReceiveFragment = {
        (arraySlice) in
        self.handleStream(win.isBinary, arraySlice)
    }
    
    win.didClose = {
        (arraySlice) in
        os_log(.debug, "Received stream closed")
    }
}

func handleStream(_ binary : Bool, _ arraySlice : ArraySlice<UInt8> ){
    if !binary {
        receivedMessage.text += String(bytes: arraySlice, encoding: .utf8)!
        receivedMessage.setNeedsDisplay()
    }
}
```
