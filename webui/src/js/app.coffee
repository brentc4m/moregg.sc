# Not sure why but Backbone.Events can't be extended
class window.Events
Events.prototype extends Backbone.Events

class LobbyOptionsGlobal
    defaults:
        opp_races: ['r', 't', 'z', 'p']
        opp_leagues: []
        maps: ['blz_ap', 'blz_as', 'blz_ev', 'blz_me', 'blz_sp', 'blz_tdale',
            'blz_st', 'blz_xnc']
        series: ['bo1']
        blocked_users: {}

    constructor: ->
        if 'cgf.lobby_options' of localStorage
            @opts = JSON.parse(localStorage['cgf.lobby_options'])
        else
            @opts = {}
        @opts = _.defaults(@opts, @defaults)
        this.save()

    save: =>
        localStorage['cgf.lobby_options'] = JSON.stringify(@opts)

    clear: =>
        delete localStorage['cgf.lobby_options']
window.LobbyOptions = new LobbyOptionsGlobal()

class CurrentUserGlobal
    attrs: ['name', 'char_code', 'profile_url', 'region', 'race', 'league']

    constructor: ->
        if localStorage['cgf.logged_in']
            for attr in @attrs
                this[attr] = localStorage['cgf.' + attr]
            @logged_in = true
        else
            @logged_in = false

    toJSON: =>
        name: @name
        char_code: @char_code
        profile_url: @profile_url
        region: @region
        league: @league
        race: @race

    logout: =>
        for attr in @attrs
            delete localStorage['cgf.' + attr]
            delete this[attr]
        delete localStorage['cgf.logged_in']
        @logged_in = false
        LobbyOptions.clear()

    saveAttrs: =>
        for attr in @attrs
            localStorage['cgf.' + attr] = this[attr]

    login: (profile_url, region, name, char_code, league, race) =>
        @name = name
        @char_code = char_code
        @profile_url = profile_url
        @region = region
        @race = race
        @league = league
        this.saveAttrs()
        LobbyOptions.opts.opp_leagues = [league]
        LobbyOptions.save()
        localStorage['cgf.logged_in'] = 'true'
        @logged_in = true

    changeRace: (race) =>
        @race = race
        this.saveAttrs()
window.CurrentUser = new CurrentUserGlobal()

class GameServerGlobal extends Events
    connect: ->
        this.trigger('connecting')
        @socket = io.connect('http://localhost:5000')
        @socket.on('connect', =>
            this.trigger('connect')
        )
        @socket.on('lobbyJoined', (global, players) =>
            this.trigger('lobbyJoined', global, players)
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

    getUserProfile: (profile_url, cb) =>
        @socket.emit('getUserProfile', profile_url, cb)

    joinGlobalLobby: =>
        player = if CurrentUser.logged_in then CurrentUser.toJSON() else null
        @socket.emit('joinGlobalLobby', player, (players) =>
            this.trigger('lobbyJoined', true, players)
        )

    _getLobbyRequest: =>
        request = CurrentUser.toJSON()
        delete request.league # server determines league
        request.params = LobbyOptions.opts
        return request

    createLobby: =>
        request = this._getLobbyRequest()
        @socket.emit('createLobby', request, (players) =>
            this.trigger('lobbyJoined', false, players)
        )

    sendChat: (msg) =>
        @socket.emit('sendChat', msg)

    exitLobby: =>
        @socket.emit('exitLobby')

    getID: =>
        return @socket.socket.sessionid
window.GameServer = new GameServerGlobal()

window.getTemplate = _.memoize((id) ->
    return _.template($('#' + id + '-tmpl').html())
)

window.render = (id, data) ->
    tmpl = getTemplate(id)
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
