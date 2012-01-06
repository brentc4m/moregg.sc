socketio = require('socket.io')
_ = require('underscore')

raceMatches = (p1, p2) ->
    return p2.race in p1.opp_races

leagueMatches = (p1, p2) ->
    return p2.league in p1.opp_leagues

seriesMatches = (p1, p2) ->
    return _.intersection(p1.series, p2.series)

mapMatches = (p1, p2) ->
    return _.intersection(p1.maps, p2.maps)

paramsMatch = (p1, p2) ->
    if p1.region isnt p2.region
        return false
    if not raceMatches(p1, p2) or not raceMatches(p2, p1)
        return false
    if not leagueMatches(p1, p2) or not leagueMatches(p2, p1)
        return false
    series = seriesMatches(p1, p2)
    return false if series.length is 0
    maps = mapMatches(p1, p2)
    return false if maps.length is 0
    return {series: series, maps: maps}

class Player
    constructor: (socket, name, char_code, profile_url, params) ->
        @socket = socket
        @id = socket.id
        @name = name
        @char_code = char_code
        @profile_url = profile_url
        @params = params

    matches: (other_player) =>
        return paramsMatch(@params, other_player.params)

    toJSON: =>
        id: @id
        name: @name
        char_code: @char_code
        profile_url: @profile_url

class Lobby
    constructor: (player) ->
        @players = [player]

    removePlayer: (id) =>
        @players = _.reject(@players, (p) -> p.id is id)
        for player in @players
            player.socket.emit('playerLeft', id)

    match: (other_lobby) =>
        return false if this.finished() or other_lobby.finished()
        match = @players[0].matches(other_lobby.players[0])
        return unless match
        @players.push(other_lobby.players[0])
        @players[0].socket.emit('playerJoined', @players[1])
        @players[1].socket.emit('playerJoined', @players[0])
        if this.finished()
            match.random_map = match.maps[Math.floor(
                Math.random()*match.maps.length)]
            p.socket.emit('lobbyFinished', match) for p in @players

    finished: =>
        return @players.length is 2
    
    sendChat: (id, text) =>
        to_players = _.reject(@players, (p) -> p.id is id)
        for p in to_players
            p.socket.emit('chatReceived', {id: id, text: text})

class LobbyManagerGlobal
    constructor: ->
        @pending_lobbies = []
        @lobbies_by_id = {}

    addPlayer: (player) =>
        lobby = new Lobby(player)
        @pending_lobbies.push(lobby)
        @lobbies_by_id[player.id] = lobby

    removePlayer: (id) =>
        return unless id of @lobbies_by_id
        lobby = @lobbies_by_id[id]
        if lobby.players.length > 1
            if lobby.finished()
                @pending_lobbies.push(lobby)
            lobby.removePlayer(id)
        else
            delete @lobbies_by_id[id]
            @pending_lobbies = _.without(@pending_lobbies, lobby)

    matchmake: =>
        new_pending = []
        while @pending_lobbies.length > 0
            lobby = @pending_lobbies.shift()
            continue if lobby.finished()
            merged = false
            for other_lobby in @pending_lobbies
                if other_lobby.match(lobby)
                    for player in other_lobby.players
                        @lobbies_by_id[player.id] = other_lobby
                    merged = true
                    break
            new_pending.push(lobby) if not merged
        @pending_lobbies = new_pending

    sendChat: (id, text) =>
        @lobbies_by_id[id].sendChat(id, text)
LobbyManager = new LobbyManagerGlobal()
setInterval(LobbyManager.matchmake, 5000)

io = socketio.listen(5000)
io.set('log level', 2)

io.sockets.on('connection', (socket) ->
    socket.on('createLobby', (req, ack) ->
        player = new Player(socket, req.name, req.char_code, req.profile_url,
            req.params)
        LobbyManager.addPlayer(player)
        ack()
    )
    socket.on('sendChat', (text) ->
        LobbyManager.sendChat(socket.id, text)
    )
    socket.on('exitLobby', ->
        LobbyManager.removePlayer(socket.id)
    )
    socket.on('disconnect', ->
        LobbyManager.removePlayer(socket.id)
    )
)
