socketio = require 'socket.io'

io = socketio.listen 5000

io.sockets.on 'connection', (socket) ->
    socket.emit 'clienttest', 'hello client!'
    socket.on 'servertest', (data) ->
        console.log data
