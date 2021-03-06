# Not sure why but Backbone.Events can't be extended
class window.Events
Events.prototype extends Backbone.Events

class window.UserConfig
    defaults:
        race: null
        opp_races: ['r', 't', 'z', 'p']
        opp_leagues: []
        maps: ['blz_as', 'blz_ckle', 'blz_ev', 'blz_kcle', 'blz_me', 'blz_sp',
            'blz_tdale', 'blz_st']
        series: ['bo1']
        blocked_users: {}

    constructor: (profile_url) ->
        @key = 'userconfig.' + profile_url
        stor_data = localStorage.getItem(@key)
        @data = if stor_data? then JSON.parse(stor_data) else {}
        @data = _.defaults(@data, @defaults)
        
        last_map_update = this.get('last_map_update')
        if not last_map_update? or last_map_update isnt 's6'
            this.set('maps', @defaults.maps)
            this.set('last_map_update', 's6')

    get: (key) =>
        return @data[key]
    
    getSet: (keys) =>
        ret = {}
        ret[k] = @data[k] for k in keys
        return ret
    
    set: (key, val) =>
        @data[key] = val
        localStorage.setItem(@key, JSON.stringify(@data))

class window.GameServer extends Events
    connect: ->
        address = localStorage.getItem('gameserver.url')
        if not address?
            if window.location.host is 'moregg.sc'
                address = 'http://aeacus.moregg.sc:443'
            else
                address = 'http://localhost:443'
        @socket = io.connect(address)
        @socket.on('connect_failed', =>
            this.trigger('connect_failed')
        )
        @socket.on('connecting', (transport) =>
            this.trigger('connecting', transport)
        )
        @socket.on('connect', =>
            this.trigger('connect')
        )
        @socket.on('error', (msg) =>
            this.trigger('error', msg)
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
        @socket.on('userStats', (user_stats) =>
            this.trigger('userStats', user_stats)
        )

    getUserProfile: (profile_url, cb) =>
        @socket.emit('getUserProfile', profile_url, cb)

    refreshProfile: (profile_url, cb) =>
        @socket.emit('refreshProfile', profile_url, cb)

    joinGlobalLobby: (player) =>
        @socket.emit('joinGlobalLobby', player)

    queue: (player, lobby_opts) =>
        @socket.emit('queue', player, lobby_opts)

    unqueue: =>
        @socket.emit('unqueue')

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

    getUserStats: (region) =>
        @socket.emit('getUserStats', region)

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

    alert: (type, msg, heading) =>
        this.$('.alert').remove()
        $(@el).prepend(this._render('alert',
            {type: type, msg: msg, heading: heading}))

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
