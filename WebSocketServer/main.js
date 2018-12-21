const WebSocket = require('ws');
const wss = new WebSocket.Server({port:8080});

wss.on('connection', function(ws, request){
    console.log("Received a new connection: " + request.url);
    
    ws.on('message', function(message){
        ws.send(message);
    });
    ws.on('close', function(){
        console.log("Received a close");
    });
});