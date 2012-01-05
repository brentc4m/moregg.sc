window.SERIES_OPTS = [
    {val: 'bo1', label: 'Best of 1'},
    {val: 'bo3', label: 'Best of 3'},
    {val: 'bo5', label: 'Best of 5'}
]

class window.CreateLobbyView extends Backbone.View
    id: 'create-lobby-view'

    events:
        'click #create-lobby-btn': 'createLobby'
        'change input[name="opp-races"]': 'changeOppRaces'
        'change input[name="opp-leagues"]': 'changeOppLeagues'
        'change input[name="series"]': 'changeSeries'

    show: =>
        fields = render('checkbox-group',
            name: 'opp-leagues'
            label: "Opponent's league"
            checked: LobbyOptions.opts.opp_leagues
            opts: LEAGUE_OPTS
        )
        fields += render('checkbox-group',
            name: 'opp-races'
            label: "Opponent's race"
            checked: LobbyOptions.opts.opp_races
            opts: RACE_OPTS
        )
        fields += render('checkbox-group',
            name: 'series'
            label: 'Series type'
            checked: LobbyOptions.opts.series
            opts: SERIES_OPTS
        )
        $(@el).html(render('create-lobby', {fields: fields}))
        $('#cgf-content').append(@el)

    hide: =>
        $(@el).detach()

    validate: (vals, id, msg) =>
        if vals.length is 0
            this.$('#' + id + '-cf').addClass('error')
            this.$('#' + id + '-cf .input').append(
                render('form-error', {msg: msg}))
            return false
        return true

    createLobby: =>
        this.$('.clearfix').removeClass('error')
        this.$('.help-inline').remove()
        opts_valid = true
        opts_valid &= this.validate(LobbyOptions.opts.opp_races, 'opp-races',
            'Choose at least one race')
        opts_valid &= this.validate(LobbyOptions.opts.opp_leagues, 'opp-leagues',
            'Choose at least one league')
        opts_valid &= this.validate(LobbyOptions.opts.series, 'series',
            'Choose at least one series type')
        this.options.app.createLobby() if opts_valid

    changeOppRaces: =>
        checked = this.$('input[name="opp-races"]:checked')
        races = (c.value for c in checked)
        LobbyOptions.opts.opp_races = races
        LobbyOptions.save()

    changeOppLeagues: =>
        checked = this.$('input[name="opp-leagues"]:checked')
        leagues = (c.value for c in checked)
        LobbyOptions.opts.opp_leagues = leagues
        LobbyOptions.save()

    changeSeries: =>
        checked = this.$('input[name="series"]:checked')
        series = (c.value for c in checked)
        LobbyOptions.opts.series = series
        LobbyOptions.save()

class window.LobbyView extends Backbone.View
    id: 'lobby-view'

    events:
        'keypress #msg-box': 'sendChatOnEnter'
        'click #exit-lobby-btn': 'exitLobby'

    initialize: =>
        GameServer.bind('lobbyCreated', this.lobbyCreated)
        GameServer.bind('playerJoined', this.playerJoined)
        GameServer.bind('playerLeft', this.playerLeft)
        GameServer.bind('chatReceived', this.chatReceived)
    
    render: =>
        $(@el).html(render('lobby'))

    renderPlayers: =>
        this.$('#user-list').html(render('lobby-players',
            players: @players
            player_link: (player_info) ->
                return render('player-link', player_info)
        ))

    show: =>
        @players = []
        @lobby_id = null

        this.render()
        $('#cgf-content').append(@el)
        this.$('#msg-box').focus()
        this.addMsg('Creating lobby..')

    hide: =>
        $(@el).detach()

    sendChat: =>
        msg_box = this.$('#msg-box')
        msg = msg_box.val()
        return if not msg
        msg_box.val('')
        this.chatReceived({id: @lobby_id, text: msg})
        GameServer.sendChat(msg)

    sendChatOnEnter: (e) =>
        this.sendChat() if e.keyCode is 13

    addMsg: (msg) =>
        timestamp = new Date().toString('HH:mm:ss')
        this.$('#msg-list').append(render('chat-msg',
            timestamp: timestamp
            msg: msg
        ))
        box = $('#chat-box')
        box.scrollTop(box[0].scrollHeight)

    lobbyCreated: =>
        @lobby_id = GameServer.socket.id
        this.addMsg('Lobby created')
        curr_player = CurrentUser.toJSON()
        curr_player.id = @lobby_id
        this.playerJoined(curr_player)

    playerLink: (id) =>
        player_info = _.find(@players, (p) -> p.id is id)
        return render('player-link', {player: player_info})

    playerJoined: (player_info) =>
        @players.push(player_info)
        this.renderPlayers()
        this.addMsg(this.playerLink(player_info.id) + ' has joined the lobby')

    playerLeft: (id) =>
        this.addMsg(this.playerLink(id) + ' has left the lobby')
        @players = _.reject(@players, (p) -> p.id is id)
        this.renderPlayers()

    chatReceived: (msg_info) =>
        this.addMsg(this.playerLink(msg_info.id) + ': ' + msg_info.text)

    exitLobby: =>
        this.options.app.exitLobby()
