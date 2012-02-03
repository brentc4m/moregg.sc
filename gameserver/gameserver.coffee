request = require('request')
socketio = require('socket.io')
sqlite3 = require('sqlite3')
util = require('util')
uuid = require('node-uuid')
_ = require('underscore')

logError = (err) ->
    util.log(err.stack)

process.on('uncaughtException', logError)

class Player
    constructor: (socket, player_info, lobby_opts) ->
        _.extend(this, player_info)
        @socket = socket
        @id = socket.id
        @params = lobby_opts

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

    isCustom: =>
        return false

class CustomLobby
    constructor: (name, map, max_players) ->
        @id = uuid.v1()
        @name = name
        @map = map
        @max_players = max_players
        @players = {}

    isFull: =>
        return this.numPlayers() is @max_players

    addPlayer: (player) =>
        p.socket.emit('playerJoined', player) for p in _.values(@players)
        @players[player.id] = player
        return @players

    removePlayer: (id) =>
        delete @players[id]
        p.socket.emit('playerLeft', id) for p in _.values(@players)

    sendChat: (id, text) =>
        for p in _.values(@players)
            continue if p.id is id
            p.socket.emit('chatReceived', {id: id, text: text})

    isCustom: =>
        return true
    
    numPlayers: =>
        return _.keys(@players).length

    toJSON: =>
        id: @id
        name: @name
        map: @map
        num_players: this.numPlayers()
        max_players: @max_players

class LobbyManager
    constructor: ->
        @pending_players = []
        @lobbies_by_id = {}
        @custom_lobbies = {}
        @custom_order = []

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
            if lobby.isCustom()
                if lobby.isFull()
                    @custom_order.unshift(lobby.id)
                lobby.removePlayer(id)
                if lobby.numPlayers() is 0
                    delete @custom_lobbies[lobby.id]
                    @custom_order = _.without(@custom_order, lobby.id)
            else
                other_player = lobby.removePlayer(id)
                @pending_players.push(other_player)
                delete @lobbies_by_id[other_player.id]
            delete @lobbies_by_id[id]
        else
            @pending_players = _.reject(@pending_players, (p) -> p.id is id)

    addCustom: (name, map, max_players) =>
        lobby = new CustomLobby(name, map, max_players)
        @custom_lobbies[lobby.id] = lobby
        @custom_order.unshift(lobby.id)
        return lobby.id
    
    joinCustom: (id, player) =>
        return if this.isPresent(player.id) or not (id of @custom_lobbies)
        lobby = @custom_lobbies[id]
        return false if lobby.isFull()
        players = lobby.addPlayer(player)
        @lobbies_by_id[player.id] = lobby
        if lobby.isFull()
            @custom_order = _.without(@custom_order, lobby.id)
        return players

    getCustoms: =>
        return _.map(@custom_order, (id) => return @custom_lobbies[id])

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

class GlobalLobby
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

class UserProfiles
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

class GameServer
    constructor: ->
        @io = null
        @profiles = new UserProfiles()
        @lobby_managers = {}
        @global_lobbies = {}

    start: ->
        @io = socketio.listen(5000)
        @io.set('log level', 2)
        @io.sockets.on('connection', (socket) =>
            fns = _.functions(this)
            fns = _.reject(fns, (fn) -> fn is 'start' or fn[0] is '_')
            socket.on(fn, this._event(this[fn], socket)) for fn in fns
        )
        
    joinGlobalLobby: (socket, player_info, cb) =>
        if player_info is null
            cb(this._globalLobby('AM').addAnon(socket))
        else
            @profiles.get(player_info.profile_url, (err, profile) =>
                return if err
                player_info = _.extend(player_info, profile)
                player = new Player(socket, player_info)
                cb(this._globalLobby(player.region).addPlayer(player))
            )

    getUserProfile: (socket, profile_url, cb) =>
        @profiles.get(profile_url, cb)

    createLobby: (socket, player_info, lobby_opts, cb) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            player_info = _.extend(player_info, profile)
            player = new Player(socket, player_info, lobby_opts)
            players = this._lobbyManager(player.region).addPlayer(player)
            this._globalLobby(player.region).removeByID(player.id)
            cb(players)
        )

    sendChat: (socket, text) =>
        sent = false
        for gl in _.values(@global_lobbies)
            if gl.isPresent(socket.id)
                gl.sendChat(socket.id, text)
                sent = true
                break
        if not sent
            l.sendChat(socket.id, text) for l in _.values(@lobby_managers)

    hostCustom: (socket, player_info, name, map, max_players, cb) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            manager = this._lobbyManager(profile.region)
            lobby_id = manager.addCustom(name, map, max_players)
            _.extend(player_info, profile)
            player = new Player(socket, player_info)
            players = manager.joinCustom(lobby_id, player)
            this._globalLobby(player.region).removeByID(player.id)
            cb(players)
        )

    refreshCustoms: (socket, player_info, cb) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            lobbies = this._lobbyManager(profile.region).getCustoms()
            cb(lobbies)
        )

    joinCustom: (socket, lobby_id, player_info, cb) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            player_info = _.extend(player_info, profile)
            player = new Player(socket, player_info)
            manager = this._lobbyManager(profile.region)
            players = manager.joinCustom(lobby_id, player)
            if not players
                cb('Custom game is full, try another.')
            else
                this._globalLobby(player.region).removeByID(player.id)
                cb(null, players)
        )

    exitLobby: (socket) =>
        l.removePlayer(socket.id) for l in _.values(@lobby_managers)

    disconnect: (socket) =>
        gl.removeByID(socket.id) for gl in _.values(@global_lobbies)
        l.removePlayer(socket.id) for l in _.values(@lobby_managers)

    _globalLobby: (region) =>
        if not @global_lobbies[region]
            @global_lobbies[region] = new GlobalLobby()
        return @global_lobbies[region]
    
    _lobbyManager: (region) =>
        if not @lobby_managers[region]
            @lobby_managers[region] = new LobbyManager()
            setInterval(@lobby_managers[region].matchmake, 5000)
        return @lobby_managers[region]

    _event: (fn, socket) ->
        return ->
            args = _.toArray(arguments)
            args.unshift(socket)
            try
                return fn.apply(this, args)
            catch err
                logError(err)

new GameServer().start() if require.main is module
