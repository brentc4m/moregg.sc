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

    regionMatches: (other) =>
        return @region is other.region

    raceMatches: (other) =>
        return other.race in @params.opp_races

    leagueMatches: (other) =>
        return other.league in @params.opp_leagues

    seriesMatches: (other) =>
        return _.intersection(@params.series, other.params.series)

    mapMatches: (other) =>
        return _.intersection(@params.maps, other.params.maps)

    blocklistOk: (other) =>
        user = other.name + '.' + other.char_code
        return not @params.blocked_users[user]

    lobbyJoined: (players) =>
        @socket.emit('lobbyJoined', players)

    globalLobbyJoined: (players) =>
        @socket.emit('globalLobbyJoined', players)

    playerJoined: (player) =>
        @socket.emit('playerJoined', player)

    playerLeft: (player_id) =>
        @socket.emit('playerLeft', player_id)

    chatReceived: (player_id, text) =>
        @socket.emit('chatReceived', {id: player_id, text: text})

    lobbyFinished: (match) =>
        @socket.emit('lobbyFinished', match)

    joinCustomFailed: (msg) =>
        @socket.emit('joinCustomFailed', msg)

    sendMsg: (msg) =>
        this.sendMsgs([msg])

    sendMsgs: (msgs) =>
        @socket.emit('lobbyMessages', msgs)

    toJSON: =>
        id: @id
        name: @name
        char_code: @char_code
        profile_url: @profile_url
        region: @region
        league: @league
        race: @race

class BaseLobby
    _generateChatroom: =>
        return 'mgg-' + uuid.v4().slice(0, 8)

class Lobby extends BaseLobby
    constructor: (p1, p2, match) ->
        @players = [p1, p2]
        p1.playerJoined(p2)
        p2.playerJoined(p1)
        match.random_map = match.maps[Math.floor(
            Math.random()*match.maps.length)]
        match.chatroom = this._generateChatroom()
        p.lobbyFinished(match) for p in @players

    removePlayer: (id) =>
        to_return = _.find(@players, (p) -> p.id isnt id)
        to_return.playerLeft(id)
        return to_return

    sendChat: (id, text) =>
        to_player = _.reject(@players, (p) -> p.id is id)[0]
        to_player.chatReceived(id, text)

class CustomLobby extends BaseLobby
    constructor: (name, map, max_players) ->
        @id = uuid.v1()
        @name = name
        @map = map
        @max_players = max_players
        @players = {}

    isFull: =>
        return this.numPlayers() is @max_players

    addPlayer: (player) =>
        p.playerJoined(player) for p in _.values(@players)
        @players[player.id] = player
        player.lobbyJoined(@players)
        player.sendMsgs(['Lobby name: ' + @name, 'Map: ' + @map])
        if this.isFull()
            match = {chatroom: this._generateChatroom()}
            p.lobbyFinished(match) for p in _.values(@players)
        else
            player.sendMsg('Waiting for more players..')

    removePlayer: (id) =>
        was_full = this.isFull()
        delete @players[id]
        p.playerLeft(id) for p in _.values(@players)
        if was_full
            p.sendMsg('Waiting for more players..') for p in _.values(@players)

    sendChat: (id, text) =>
        for p in _.values(@players)
            continue if p.id is id
            p.chatReceived(id, text)
    
    numPlayers: =>
        return _.keys(@players).length

    toJSON: =>
        id: @id
        name: @name
        map: @map
        num_players: this.numPlayers()
        max_players: @max_players

class CustomLobbyManager
    constructor: ->
        @custom_lobbies = {}
        @custom_order = []
        @lobbies_by_player_id = {}

    createLobby: (name, map, max_players) =>
        lobby = new CustomLobby(name, map, max_players)
        @custom_lobbies[lobby.id] = lobby
        @custom_order.unshift(lobby.id)
        return lobby.id

    isFull: (lobby_id) =>
        return @custom_lobbies[lobby_id].isFull()

    addPlayer: (player, lobby_id) =>
        lobby = @custom_lobbies[lobby_id]
        players = lobby.addPlayer(player)
        @lobbies_by_player_id[player.id] = lobby
        if lobby.isFull()
            @custom_order = _.without(@custom_order, lobby.id)

    removePlayer: (player_id) =>
        lobby = @lobbies_by_player_id[player_id]
        if lobby.isFull()
            @custom_order.unshift(lobby.id)
        lobby.removePlayer(player_id)
        delete @lobbies_by_player_id[player_id]
        if lobby.numPlayers() is 0
            delete @custom_lobbies[lobby.id]
            @custom_order = _.without(@custom_order, lobby.id)

    getLobbies: =>
        return _.map(@custom_order, (id) => return @custom_lobbies[id])

    sendChat: (player_id, text) =>
        @lobbies_by_player_id[player_id].sendChat(player_id, text)

    numPlayers: =>
        return _.keys(@lobbies_by_player_id).length

    numQueued: =>
        return this.numPlayers()

class OVOLobbyManager
    constructor: ->
        @pending_players = []
        @lobbies_by_player_id = {}

    addPlayer: (player) =>
        @pending_players.push(player)
        players = {}
        players[player.id] = player
        player.lobbyJoined(players)
        player.sendMsg('Searching for an opponent..')

    removePlayer: (player_id) =>
        if player_id of @lobbies_by_player_id
            lobby = @lobbies_by_player_id[player_id]
            other_player = lobby.removePlayer(player_id)
            @pending_players.push(other_player)
            other_player.sendMsg('Searching for an opponent..')
            delete @lobbies_by_player_id[other_player.id]
            delete @lobbies_by_player_id[player_id]
        else
            @pending_players = _.reject(@pending_players,
                (p) -> p.id is player_id)

    matchmake: =>
        new_pending = []
        while @pending_players.length > 0
            player = @pending_players.shift()
            continue if player.id of @lobbies_by_player_id
            matched = false
            for other_player in @pending_players
                match = player.matches(other_player)
                if match
                    lobby = new Lobby(player, other_player, match)
                    @lobbies_by_player_id[player.id] = lobby
                    @lobbies_by_player_id[other_player.id] = lobby
                    matched = true
                    break
            new_pending.push(player) if not matched
        @pending_players = new_pending

    sendChat: (player_id, text) =>
        # players by themselves have no lobby
        if player_id of @lobbies_by_player_id
            @lobbies_by_player_id[player_id].sendChat(player_id, text)

    numPlayers: =>
        return _.keys(@lobbies_by_player_id).length + this.numQueued()

    numQueued: =>
        return @pending_players.length

class GlobalLobbyManager
    constructor: ->
        @players = {}
        @anons = {}

    addPlayer: (player) =>
        delete @anons[player.id]
        p.playerJoined(player) for p in _.values(@players)
        a.emit('playerJoined', player) for a in _.values(@anons)
        @players[player.id] = player
        player.globalLobbyJoined(@players)
    
    addAnon: (socket) =>
        @anons[socket.id] = socket
        socket.emit('globalLobbyJoined', @players)
    
    sendChat: (player_id, text) =>
        for p in _.values(@players) when p.id isnt player_id
            p.chatReceived(player_id, text)
        a.emit('chatReceived', {id: player_id, text: text}) for a in _.values(@anons)

    removePlayer: (id) =>
        was_player = id of @players
        delete @players[id]
        delete @anons[id]
        if was_player
            p.playerLeft(id) for p in _.values(@players)
            a.emit('playerLeft', id) for a in _.values(@anons)

    numPlayers: =>
        return _.keys(@players).length

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
        if not profile_url.match(/\/sc2\/\w+\/profile\/\d+\/\d+\//)
            return cb(error)
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
        @custom_managers = {}
        @ovo_managers = {}
        @global_managers = {}
        @managers_by_id = {}

    start: ->
        @io = socketio.listen(443)
        @io.set('log level', 1)
        @io.sockets.on('connection', (socket) =>
            fns = _.functions(this)
            fns = _.reject(fns, (fn) -> fn is 'start' or fn[0] is '_')
            socket.on(fn, this._event(this[fn], socket)) for fn in fns
        )
        
    joinGlobalLobby: (socket, player_info) =>
        if player_info is null
            manager = this._globalManager('AM')
            @managers_by_id[socket.id] = manager
            manager.addAnon(socket)
        else
            @profiles.get(player_info.profile_url, (err, profile) =>
                return if err
                player_info = _.extend(player_info, profile)
                player = new Player(socket, player_info)
                this._removePlayer(player.id)
                manager = this._globalManager(player.region)
                @managers_by_id[player.id] = manager
                manager.addPlayer(player)
            )

    getUserProfile: (socket, profile_url, cb) =>
        @profiles.get(profile_url, cb)

    createLobby: (socket, player_info, lobby_opts) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            player_info = _.extend(player_info, profile)
            player = new Player(socket, player_info, lobby_opts)
            this._removePlayer(player.id)
            manager = this._ovoManager(player.region)
            @managers_by_id[player.id] = manager
            manager.addPlayer(player)
        )

    sendChat: (socket, text) =>
        @managers_by_id[socket.id].sendChat(socket.id, text)

    hostCustom: (socket, player_info, name, map, max_players) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            _.extend(player_info, profile)
            player = new Player(socket, player_info)
            manager = this._customManager(player.region)
            lobby_id = manager.createLobby(name, map, max_players)
            this._removePlayer(player.id)
            @managers_by_id[player.id] = manager
            manager.addPlayer(player, lobby_id)
        )

    refreshCustoms: (socket, player_info, cb) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            cb(this._customManager(profile.region).getLobbies())
        )

    joinCustom: (socket, lobby_id, player_info) =>
        @profiles.get(player_info.profile_url, (err, profile) =>
            return if err
            player_info = _.extend(player_info, profile)
            player = new Player(socket, player_info)
            manager = this._customManager(player.region)
            if manager.isFull(lobby_id)
                player.joinCustomFailed('Game is full, try another.')
            else
                this._removePlayer(player.id)
                manager.addPlayer(player, lobby_id)
                @managers_by_id[player.id] = manager
        )

    getUserStats: (socket, region) =>
        num_players = this._globalManager(region).numPlayers()
        num_players += this._ovoManager(region).numPlayers()
        num_players += this._customManager(region).numPlayers()
        num_queued = this._ovoManager(region).numQueued()
        num_queued += this._customManager(region).numQueued()
        socket.emit('userStats',
            num_players: num_players
            num_queued: num_queued
        )

    disconnect: (socket) =>
        this._removePlayer(socket.id)

    _removePlayer: (id) =>
        if id of @managers_by_id
            @managers_by_id[id].removePlayer(id)

    _globalManager: (region) =>
        if not @global_managers[region]
            @global_managers[region] = new GlobalLobbyManager()
        return @global_managers[region]
    
    _ovoManager: (region) =>
        if not @ovo_managers[region]
            @ovo_managers[region] = new OVOLobbyManager()
            setInterval(@ovo_managers[region].matchmake, 5000)
        return @ovo_managers[region]

    _customManager: (region) =>
        if not @custom_managers[region]
            @custom_managers[region] = new CustomLobbyManager()
        return @custom_managers[region]

    _event: (fn, socket) ->
        return ->
            args = _.toArray(arguments)
            args.unshift(socket)
            try
                return fn.apply(this, args)
            catch err
                logError(err)

new GameServer().start() if require.main is module
