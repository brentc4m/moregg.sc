socketio = require('socket.io')
_ = require('underscore')

io = socketio.listen(5000)

players = []

io.sockets.on('connection', (socket) ->
    socket.on('createLobby', (req) ->
        player =
            id: socket.id
            name: req.name
            char_code: req.char_code
            profile_url: req.profile_url
        socket.emit('lobbyCreated', {id: player.id})
        socket.broadcast.emit('playerJoined', player)
        for otherplayer in players
            socket.emit('playerJoined', otherplayer)
        players.push(player)
    )
    socket.on('sendChat', (msg) ->
        socket.broadcast.emit('chatReceived',
            id: socket.id
            text: msg
        )
    )
    socket.on('disconnect', ->
        players = _.reject(players, (p) -> p.id == socket.id)
    )
)
