pg = require('pg')
request = require('request')
socketio = require('socket.io')
_ = require('underscore')

raceMatches = (p1, p2) ->
    return p2.race in p1.params.opp_races

leagueMatches = (p1, p2) ->
    return p2.league in p1.params.opp_leagues

seriesMatches = (p1, p2) ->
    return _.intersection(p1.params.series, p2.params.series)

mapMatches = (p1, p2) ->
    return _.intersection(p1.params.maps, p2.params.maps)

class Player
    constructor: (socket, request) ->
        _.extend(this, request)
        @socket = socket
        @id = socket.id

    matches: (p2) =>
        p1 = this
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

    toJSON: =>
        id: @id
        name: @name
        char_code: @char_code
        profile_url: @profile_url
        region: @region
        league: @league
        race: @race

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

class UserProfilesGlobal
    LEAGUES:
        'none': 'n'
        'bronze': 'b'
        'silver': 's'
        'gold': 'g'
        'platinum': 'p'
        'diamond': 'd'
        'master': 'm'
        'grandmaster': 'gm'

    constructor: ->
        @client = new pg.Client('tcp://postgres:pgpass1@localhost/cgf')
        @client.connect()

    get: (profile_url, cb) =>
        this._getFromDB(profile_url, (err, profile) =>
            return cb(err) if err
            return cb(null, profile) if profile isnt null
            this._scrape(profile_url, (err, profile) =>
                return cb(err) if err
                this._putInDB(profile_url, profile)
                cb(null, profile)
            )
        )

    _getFromDB: (profile_url, cb) =>
        @client.query({
            name: 'get',
            text: 'SELECT region, name, league FROM profiles WHERE url = $1',
            values: [profile_url]
        }, (err, result) =>
            if err
                console.log(err)
                return cb('Temporary error, try again later')
            if result.rows.length is 0
                cb(null, null)
            else
                row = result.rows[0]
                cb(null, {region: row.region, name: row.name, league: row.league})
        )

    _putInDB: (profile_url, profile) =>
        @client.query({
            name: 'put',
            text: 'INSERT INTO profiles (url, region, name, league) VALUES ($1, $2, $3, $4)',
            values: [profile_url, profile.region, profile.name, profile.league]
        })

    _scrape: (profile_url, cb) =>
        error = 'Bad profile URL or an error occurred, try again.'
        if profile_url.indexOf('http://us.battle.net') is 0
            region = 'AM'
        else if profile_url.indexOf('http://kr.battle.net') is 0
            region = 'KR'
        else if profile_url.indexOf('http://www.battlenet.com.cn') is 0
            region = 'CN'
        else if profile_url.indexOf('http://sea.battle.net') is 0
            region = 'SEA'
        else if profile_url.indexOf('http://eu.battle.net') is 0
            region = 'EU'
        else
            return cb(error)
        request(profile_url, (err, res, body) =>
            return cb(err) if err
            return cb(error) if res.statusCode isnt 200

            match = body.match(/<title>(\S+)/)
            return cb(error) if match is null
            name = match[1]

            match = body.match(/#best-team-1[\s\S]+?badge-(\w+)/)
            league = if match is null then 'none' else match[1]
            return cb('Error parsing league, please report') if not league of @LEAGUES
            league = @LEAGUES[league]
            cb(null, {region: region, name: name, league: league})
        )
UserProfiles = new UserProfilesGlobal()

io = socketio.listen(5000)
io.set('log level', 2)

io.sockets.on('connection', (socket) ->
    socket.on('getUserProfile', (profile_url, cb) ->
        UserProfiles.get(profile_url, cb)
    )
    socket.on('createLobby', (req, cb) ->
        UserProfiles.get(req.profile_url, (err, profile) ->
            return cb(err) if err
            req.league = profile.league
            player = new Player(socket, req)
            LobbyManager.addPlayer(player)
            cb()
        )
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
