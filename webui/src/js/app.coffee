# Not sure why but Backbone.Events can't be extended
class window.Events
Events.prototype extends Backbone.Events

class LobbyOptionsGlobal
    defaults:
        opp_races: ['r', 't', 'z', 'p']
        opp_leagues: []

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

class CurrentUserGlobal extends Events
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

    logout: =>
        for attr in @attrs
            delete localStorage['cgf.' + attr]
            delete this[attr]
        delete localStorage['cgf.logged_in']
        @logged_in = false
        LobbyOptions.clear()
        this.trigger('change')

    saveAttrs: =>
        for attr in @attrs
            localStorage['cgf.' + attr] = this[attr]

    login: (profile_url, region, name, char_code) =>
        @name = name
        @char_code = char_code
        @profile_url = profile_url
        @region = region
        @race = 'random'
        @league = 'bronze'
        this.saveAttrs()
        localStorage['cgf.logged_in'] = 'true'
        @logged_in = true
        this.trigger('change')

    changeRace: (race) =>
        @race = race
        this.saveAttrs()

    changeLeague: (league) =>
        @league = league
        this.saveAttrs()
window.CurrentUser = new CurrentUserGlobal()

class GameServerGlobal extends Events
    constructor: ->
        @socket = io.connect('http://localhost:5000')

    createLobby: =>
        params = _.clone(LobbyOptions.opts)
        params.region = CurrentUser.region
        params.race = CurrentUser.race
        params.league = CurrentUser.league
        request =
            name: CurrentUser.name
            char_code: CurrentUser.char_code
            profile_url: CurrentUser.profile_url
            params: params
        @socket.on('playerJoined', (d) => this.trigger('playerJoined', d))
        @socket.on('playerLeft', (d) => this.trigger('playerLeft', d))
        @socket.on('chatReceived', (d) => this.trigger('chatReceived', d))
        @socket.emit('createLobby', request, => this.trigger('lobbyCreated'))

    sendChat: (msg) =>
        @socket.emit('sendChat', msg)

    exitLobby: =>
        @socket.removeAllListeners('lobbyCreated')
        @socket.removeAllListeners('playerJoined')
        @socket.removeAllListeners('playerLeft')
        @socket.removeAllListeners('chatReceived')
        @socket.emit('exitLobby')
window.GameServer = new GameServerGlobal()

window.getTemplate = _.memoize((id) ->
    return _.template($('#' + id + '-tmpl').html())
)

window.render = (id, data) ->
    tmpl = getTemplate(id)
    return tmpl(data)

window.LEAGUE_OPTS = [
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

$ ->
    new CGFView().render()
