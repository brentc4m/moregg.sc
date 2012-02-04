# Not sure why but Backbone.Events can't be extended
class window.Events
Events.prototype extends Backbone.Events

class window.UserConfig
    defaults:
        char_code: null
        race: null
        opp_races: ['r', 't', 'z', 'p']
        opp_leagues: []
        maps: ['blz_ap', 'blz_as', 'blz_ev', 'blz_me', 'blz_sp', 'blz_tdale',
            'blz_st', 'blz_xnc']
        series: ['bo1']
        blocked_users: {}

    constructor: (profile_url) ->
        @key = 'userconfig.' + profile_url
        @data = if @key of localStorage then JSON.parse(localStorage[@key]) else {}
        @data = _.defaults(@data, @defaults)

    get: (key) =>
        return @data[key]
    
    getSet: (keys) =>
        ret = {}
        ret[k] = @data[k] for k in keys
        return ret
    
    set: (key, val) =>
        @data[key] = val
        localStorage[@key] = JSON.stringify(@data)

class window.GameServer extends Events
    connect: ->
        if 'gameserver.url' of localStorage
            address = localStorage['gameserver.url']
        else
            address = 'http://aeacus.moregg.sc:8080'
        window.WEB_SOCKET_SWF_LOCATION = '/swf/WebSocketMainInsecure.swf'
        this.trigger('connecting')
        @socket = io.connect(address)
        @socket.on('connect', =>
            this.trigger('connect')
        )
        @socket.on('lobbyJoined', (players) =>
            this.trigger('lobbyJoined', players)
        )
        @socket.on('globalLobbyJoined', (players) =>
            this.trigger('globalLobbyJoined', players)
        )
        @socket.on('playerJoined', (player_info) =>
            this.trigger('playerJoined', player_info)
        )
        @socket.on('playerLeft', (id) =>
            this.trigger('playerLeft', id)
        )
        @socket.on('chatReceived', (msg_info) =>
            this.trigger('chatReceived', msg_info)
        )
        @socket.on('lobbyFinished', (game_info) =>
            this.trigger('lobbyFinished', game_info)
        )
        @socket.on('joinCustomFailed', (msg) =>
            this.trigger('joinCustomFailed', msg)
        )
        @socket.on('lobbyMessages', (msgs) =>
            this.trigger('lobbyMessages', msgs)
        )

    getUserProfile: (profile_url, cb) =>
        @socket.emit('getUserProfile', profile_url, cb)

    joinGlobalLobby: (player) =>
        @socket.emit('joinGlobalLobby', player)

    createLobby: (player, lobby_opts) =>
        @socket.emit('createLobby', player, lobby_opts)

    sendChat: (msg) =>
        @socket.emit('sendChat', msg)

    hostCustom: (player, name, map, max_players) =>
        @socket.emit('hostCustom', player, name, map, max_players)

    refreshCustoms: (player) =>
        @socket.emit('refreshCustoms', player, (lobbies) =>
            this.trigger('customLobbyList', lobbies)
        )

    joinCustom: (id, player) =>
        @socket.emit('joinCustom', id, player)

    getID: =>
        return @socket.socket.sessionid

class window.View extends Backbone.View
    container_id: 'cgf-content'

    constructor: (app) ->
        @app = app
        super()

    show: =>
        this.render()
        $('#' + @container_id + ' > *').detach()
        $('#' + @container_id).append(@el)

    alert: (type, msg) =>
        this.$('.alert').remove()
        $(@el).prepend(this._render('alert', {type: type, msg: msg}))

    _getTemplate: _.memoize((id) ->
        return _.template($('#' + id + '-tmpl').html())
    )

    _render: (id, data) ->
        tmpl = this._getTemplate(id)
        return tmpl(data)

window.LEAGUE_OPTS = [
    {val: 'n', label: 'Unranked'}
    {val: 'b', label: 'Bronze'},
    {val: 's', label: 'Silver'},
    {val: 'g', label: 'Gold'},
    {val: 'p', label: 'Platinum'},
    {val: 'd', label: 'Diamond'},
    {val: 'm', label: 'Master'},
    {val: 'gm', label: 'Grandmaster'}
]

window.RACE_OPTS = [
    {val: 'r', label: 'Random'},
    {val: 't', label: 'Terran'},
    {val: 'z', label: 'Zerg'},
    {val: 'p', label: 'Protoss'}
]
