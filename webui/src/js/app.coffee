$ ->
    socket = io.connect 'http://localhost:5000'
    socket.on 'clienttest', (data) ->
        alert data
        socket.emit 'servertest', 'hello server!'
