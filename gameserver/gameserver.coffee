request = require('request')
socketio = require('socket.io')
sqlite3 = require('sqlite3')
util = require('util')
_ = require('underscore')

logError = (err) ->
    util.log(err.stack)

process.on('uncaughtException', logError)

class Player
    constructor: (socket, request) ->
        _.extend(this, request)
        @socket = socket
        @id = socket.id

    matches: (other) =>
        if not this.regionMatches(other)
            return false
        if not this.raceMatches(other) or not other.raceMatches(this)
            return false
        if not this.leagueMatches(other) or not other.leagueMatches(this)
            return false
        if not this.blocklistOk(other) or not other.blocklistOk(this)
            return false
        series = this.seriesMatches(other)
        return false if series.length is 0
        maps = this.mapMatches(other)
        return false if maps.length is 0
        return {series: series, maps: maps}

    regionMatches: (other) ->
        return @region is other.region

    raceMatches: (other) ->
        return other.race in @params.opp_races

    leagueMatches: (other) ->
        return other.league in @params.opp_leagues

    seriesMatches: (other) ->
        return _.intersection(@params.series, other.params.series)

    mapMatches: (other) ->
        return _.intersection(@params.maps, other.params.maps)

    blocklistOk: (other) ->
        user = other.name + '.' + other.char_code
        return not @params.blocked_users[user]

    toJSON: =>
        id: @id
        name: @name
        char_code: @char_code
        profile_url: @profile_url
        region: @region
        league: @league
        race: @race
        params: @params

class Lobby
    constructor: (p1, p2, match) ->
        @players = [p1, p2]
        p1.socket.emit('playerJoined', p2)
        p2.socket.emit('playerJoined', p1)
        match.random_map = match.maps[Math.floor(
            Math.random()*match.maps.length)]
        p.socket.emit('lobbyFinished', match) for p in @players

    removePlayer: (id) =>
        to_return = _.find(@players, (p) -> p.id isnt id)
        to_return.socket.emit('playerLeft', id)
        return to_return

    sendChat: (id, text) =>
        to_player = _.reject(@players, (p) -> p.id is id)[0]
        to_player.socket.emit('chatReceived', {id: id, text: text})

class LobbyManagerGlobal
    constructor: ->
        @pending_players = []
        @lobbies_by_id = {}

    isPresent: (id) =>
        return id of @lobbies_by_id or id in (p.id for p in @pending_players)

    addPlayer: (player) =>
        return if this.isPresent(player.id)
        @pending_players.push(player)
        players = {}
        players[player.id] = player
        return players

    removePlayer: (id) =>
        if id of @lobbies_by_id
            lobby = @lobbies_by_id[id]
            other_player = lobby.removePlayer(id)
            @pending_players.push(other_player)
            delete @lobbies_by_id[id]
            delete @lobbies_by_id[other_player.id]
        else
            @pending_players = _.reject(@pending_players, (p) -> p.id is id)

    matchmake: =>
        new_pending = []
        while @pending_players.length > 0
            player = @pending_players.shift()
            continue if player.id of @lobbies_by_id
            matched = false
            for other_player in @pending_players
                match = player.matches(other_player)
                if match
                    lobby = new Lobby(player, other_player, match)
                    @lobbies_by_id[player.id] = lobby
                    @lobbies_by_id[other_player.id] = lobby
                    matched = true
                    break
            new_pending.push(player) if not matched
        @pending_players = new_pending

    sendChat: (id, text) =>
        return unless id of @lobbies_by_id
        @lobbies_by_id[id].sendChat(id, text)
LobbyManager = new LobbyManagerGlobal()
setInterval(LobbyManager.matchmake, 5000)

class GlobalLobbyGlobal
    constructor: ->
        @players = {}
        @anons = {}

    addPlayer: (player) =>
        delete @anons[player.id]
        p.socket.emit('playerJoined', player) for p in _.values(@players)
        a.emit('playerJoined', player) for a in _.values(@anons)
        @players[player.id] = player
        return @players
    
    addAnon: (socket) =>
        @anons[socket.id] = socket
        return @players
    
    isPresent: (player_id) =>
        return player_id of @players
    
    sendChat: (id, text) =>
        return if id not of @players
        chat = {id: id, text: text}
        p.socket.emit('chatReceived', chat) for p in _.values(@players) when p.id isnt id
        a.emit('chatReceived', chat) for a in _.values(@anons)

    removeByID: (id) =>
        was_player = id of @players
        delete @players[id]
        delete @anons[id]
        if was_player
            p.socket.emit('playerLeft', id) for p in _.values(@players)
            a.emit('playerLeft', id) for a in _.values(@anons)
GlobalLobby = new GlobalLobbyGlobal()

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
        @db = new sqlite3.Database('profiles.db')
        @scrapes = []

    get: (profile_url, cb) =>
        this._getFromDB(profile_url, (err, profile) =>
            return cb(err) if err
            return cb(null, profile) if profile isnt null
            this._queueScrape(profile_url, (err, profile) =>
                return cb(err) if err
                this._putInDB(profile_url, profile)
                cb(null, profile)
            )
        )

    _getFromDB: (profile_url, cb) =>
        @db.get(
            'SELECT region, name, league FROM profiles WHERE url = ?',
            profile_url,
            (err, row) =>
                if err
                    console.log(err)
                    cb('Temporary error, try again later')
                else if row is undefined
                    cb(null, null)
                else
                    cb(null, {region: row.region, name: row.name, league: row.league})
        )

    _putInDB: (profile_url, profile) =>
        @db.run(
            'INSERT INTO profiles (url, region, name, league) VALUES ($1, $2, $3, $4)',
            [profile_url, profile.region, profile.name, profile.league],
            (err) =>
                console.log(err) if err
        )

    _queueScrape: (profile_url, cb) =>
        @scrapes.push({profile_url: profile_url, cb: cb})
        return if @scrapes.length > 1
        this._scrape(profile_url, @_queuedScrapeCB)

    _queuedScrapeCB: (err, data) =>
        s = @scrapes.shift() # this should have just finished
        s.cb(err, data)
        if @scrapes.length > 0 # still more to go
            this._scrape(@scrapes[0].profile_url, @_queuedScrapeCB)

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

class GameServer
    start: ->
        @io = socketio.listen(5000)
        @io.set('log level', 2)
        @io.sockets.on('connection', (socket) =>
            fns = _.functions(this)
            fns = _.reject(fns, (fn) -> fn is 'start' or fn[0] is '_')
            socket.on(fn, this._event(this[fn], socket)) for fn in fns
        )

    _event: (fn, socket) ->
        return ->
            args = _.toArray(arguments)
            args.unshift(socket)
            try
                return fn.apply(this, args)
            catch err
                logError(err)
        
    joinGlobalLobby: (socket, req, cb) =>
        if req is null
            cb(GlobalLobby.addAnon(socket))
        else
            UserProfiles.get(req.profile_url, (err, profile) ->
                return if err
                req.league = profile.league
                player = new Player(socket, req)
                cb(GlobalLobby.addPlayer(player))
            )

    getUserProfile: (socket, profile_url, cb) =>
        UserProfiles.get(profile_url, cb)

    createLobby: (socket, req, cb) =>
        UserProfiles.get(req.profile_url, (err, profile) ->
            return if err
            req.league = profile.league
            player = new Player(socket, req)
            players = LobbyManager.addPlayer(player)
            GlobalLobby.removeByID(player.id)
            cb(players)
        )

    sendChat: (socket, text) =>
        if GlobalLobby.isPresent(socket.id)
            GlobalLobby.sendChat(socket.id, text)
        else
            LobbyManager.sendChat(socket.id, text)

    exitLobby: (socket) =>
        LobbyManager.removePlayer(socket.id)

    disconnect: (socket) =>
        GlobalLobby.removeByID(socket.id)
        LobbyManager.removePlayer(socket.id)

new GameServer().start() if require.main is module
