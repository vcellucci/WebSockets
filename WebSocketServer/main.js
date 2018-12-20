const WebSocket = require('ws');
const wss = new WebSocket.Server({port:8080});

wss.on('connection', function(ws){
    console.log("Received a new connection");
    setTimeout(function(){
        console.log("closing socket...");
        ws.close(1000);
    }, 3000);

    ws.on('message', function(message){
        ws.send(message);
    });
    ws.on('close', function(){
        console.log("Received a close");
    });
});