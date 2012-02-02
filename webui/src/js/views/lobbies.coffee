window.SERIES_OPTS = [
    {val: 'bo1', label: 'Best of 1'},
    {val: 'bo3', label: 'Best of 3'},
    {val: 'bo5', label: 'Best of 5'}
]

window.MAPS = [
    {name: 'ladder', label: 'Ladder', maps: [
        {val: 'blz_ap', label: "Arid Plateau"},
        {val: 'blz_as', label: "Antiga Shipyard"},
        {val: 'blz_ev', label: "Entombed Valley"},
        {val: 'blz_me', label: "Metalopolis"},
        {val: 'blz_sp', label: "Shakuras Plateau"},
        {val: 'blz_tdale', label: "Tal'Darim Altar LE"},
        {val: 'blz_st', label: "The Shattered Temple"},
        {val: 'blz_xnc', label: "Xel'Naga Caverns"}
    ]},
    {name: 'mlg', label: 'MLG', maps: [
        {val: 'mlg_as', label: "MLG Antiga Shipyard"},
        {val: 'mlg_db', label: "MLG Daybreak"},
        {val: 'mlg_ds', label: "MLG Dual Sight"},
        {val: 'mlg_me', label: "MLG Metalopolis"},
        {val: 'mlg_sp', label: "MLG Shakuras Plateau"},
        {val: 'mlg_st', label: "MLG Shattered Temple"},
        {val: 'mlg_tdale', label: "MLG Tal'Darim Altar"},
        {val: 'mlg_te', label: "MLG Terminus"},
        {val: 'mlg_tb', label: "MLG Testbug"},
        {val: 'mlg_tp', label: "MLG Typhon Peaks"},
        {val: 'mlg_xnc', label: "MLG Xel'Naga Caverns"}
    ]},
    {name: 'gsl', label: 'GSL', maps: [
        {val: 'gsl_bsb', label: "GSL Bel'Shir Beach (Official)"},
        {val: 'gsl_bsbw', label: "GSL Bel'Shir Beach (Winter)"},
        {val: 'gsl_cbts', label: "GSL Calm Before The Storm"},
        {val: 'gsl_cfse', label: "GSL Crossfire SE (Official)"},
        {val: 'gsl_cr', label: "GSL Crevasse (Official)"},
        {val: 'gsl_db', label: "GSL Daybreak"},
        {val: 'gsl_ds', label: "GSL Dual Sight"},
        {val: 'gsl_mt', label: "GSL Metropolis"},
        {val: 'gsl_tre', label: "GSL Terminus RE"},
        {val: 'gsl_tse', label: "GSL Terminus SE (v1.1)"},
        {val: 'gsl_xnf', label: "GSL Xel'Naga Fortress (Official)"}
    ]},
    {name: 'blizzard', label: 'Blizzard', maps: [
        {val: 'blz_av', label: "Agria Valley"},
        {val: 'blz_ab', label: "Abyss"},
        {val: 'blz_ac', label: "Abyssal Caverns"},
        {val: 'blz_bwg', label: "Backwater Gulch"},
        {val: 'blz_bs', label: "Blistering Sands"},
        {val: 'blz_bg', label: "Burial Grounds"},
        {val: 'blz_cf', label: "Crossfire"},
        {val: 'blz_df', label: "Debris Field"},
        {val: 'blz_dq', label: "Delta Quadrant"},
        {val: 'blz_do', label: "Desert Oasis"},
        {val: 'blz_el', label: "Elysium"},
        {val: 'blz_fp', label: "Forbidden Planet"},
        {val: 'blz_iz', label: "Incineration Zone"},
        {val: 'blz_jb', label: "Jungle Basin"},
        {val: 'blz_jy', label: "Junk Yard"},
        {val: 'blz_kr', label: "Kulas Ravine"},
        {val: 'blz_lt', label: "Lost Temple"},
        {val: 'blz_nc', label: "Nerazim Crypt"},
        {val: 'blz_ss', label: "Scrap Station"},
        {val: 'blz_sc', label: "Searing Crater"},
        {val: 'blz_slp', label: "Slag Pits"},
        {val: 'blz_sow', label: "Steps of War"},
        {val: 'blz_tr', label: "Tectonic Rift"},
        {val: 'blz_ter', label: "Terminus"},
        {val: 'blz_tp', label: "Typhon Peaks"},
        {val: 'blz_ws', label: "Worldship"}
    ]}
]

window.MAP_LABELS = {}
for map in _.flatten(_.pluck(MAPS, 'maps'))
    MAP_LABELS[map.val] = map.label

class window.CreateLobbyView extends View
    id: 'create-lobby-view'

    events:
        'click #create-lobby-btn': 'createLobby'
        'click #close-create-lobby-btn': 'close'
        'click #map-tabs li a': 'changeMapsTab'
        'change input[name="opp-races"]': 'changeOppRaces'
        'change input[name="opp-leagues"]': 'changeOppLeagues'
        'change input[name="maps"]': 'changeMaps'
        'change input[name="series"]': 'changeSeries'

    render: =>
        config = @app.getConfig()
        fields = this._render('split-checkbox-group',
            name: 'opp-leagues'
            label: "Opponent's league"
            checked: config.get('opp_leagues')
            opts: LEAGUE_OPTS
        )
        fields += this._render('checkbox-group',
            name: 'opp-races'
            label: "Opponent's race"
            checked: config.get('opp_races')
            opts: RACE_OPTS
        )
        fields += this._render('checkbox-group',
            name: 'series'
            label: 'Series type'
            checked: config.get('series')
            opts: SERIES_OPTS
        )
        fields += this._render('map-field',
            sections: MAPS
            checked: config.get('maps')
        )
        $(@el).html(this._render('create-lobby', {fields: fields}))

    close: =>
        @app.showLobby()

    validate: (vals, id) =>
        if vals.length is 0
            this.$('#' + id + '-cg').addClass('error')
            return false
        return true

    validateOptions: =>
        this.$('.control-group').removeClass('error')
        this.$('.help-inline').remove()
        config = @app.getConfig()
        opts_valid = true
        opts_valid &= this.validate(config.get('opp_races'), 'opp-races')
        opts_valid &= this.validate(config.get('opp_leagues'), 'opp-leagues')
        opts_valid &= this.validate(config.get('series'), 'series')
        opts_valid &= this.validate(config.get('maps'), 'maps')
        return opts_valid

    createLobby: =>
        @app.createLobby() if this.validateOptions()

    changeOppRaces: =>
        checked = this.$('input[name="opp-races"]:checked')
        races = (c.value for c in checked)
        @app.getConfig().set('opp_races', races)

    changeOppLeagues: =>
        checked = this.$('input[name="opp-leagues"]:checked')
        leagues = (c.value for c in checked)
        @app.getConfig().set('opp_leagues', leagues)

    changeMaps: =>
        checked = this.$('input[name="maps"]:checked')
        maps = (c.value for c in checked)
        @app.getConfig().set('maps', maps)

    changeSeries: =>
        checked = this.$('input[name="series"]:checked')
        series = (c.value for c in checked)
        @app.getConfig().set('series', series)

    changeMapsTab: (e) =>
        e.preventDefault()
        this.$('#map-tabs li.active').removeClass('active')
        $(e.target).parent('li').addClass('active')
        this.$('.tab-content div.active').removeClass('active')
        this.$(e.target.hash).addClass('active')

class window.LobbyView extends View
    id: 'lobby-view'

    events:
        'keypress #msg-box': 'sendChatOnEnter'
        'click a.block-player': 'blockPlayer'
        'click #exit-lobby-btn': 'exitLobby'

    initialize: =>
        @in_game = false
        @players = {}
        @last_chat_times = []
        @chat_blocked = false
        $(@el).html(this._render('lobby'))
        this.renderPlayers()

        server = @app.getServer()
        server.bind('connecting', this.connecting)
        server.bind('lobbyJoined', this.lobbyJoined)
        server.bind('globalLobbyJoined', this.globalLobbyJoined)
        server.bind('playerJoined', this.playerJoined)
        server.bind('playerLeft', this.playerLeft)
        server.bind('chatReceived', this.chatReceived)
        server.bind('lobbyFinished', this.lobbyFinished)

    renderPlayers: =>
        this.$('#user-list').html(this._render('lobby-players',
            players: _.values(@players)
            player_link: (player_info) =>
                return this._render('player-link', player_info)
        ))

    show: =>
        super()
        this.$('#msg-box').focus()

    connecting: =>
        this.addMsg('Connecting to server..')

    lobbyJoined: (players) =>
        @in_game = true
        this._updatePlayers(players)
        this.addMsg('Private lobby joined')
        this.addMsg('Searching for players..')

    globalLobbyJoined: (players) =>
        @in_game = false
        this._updatePlayers(players)
        this.addMsg('Global ' + @app.getRegion() + ' lobby joined')

    playerJoined: (player_info) =>
        @players[player_info.id] = player_info
        this.renderPlayers()
        this.addMsg(this.playerLink(player_info.id) + ' has joined the lobby')

    playerLeft: (id) =>
        this.addMsg(this.playerLink(id) + ' has left the lobby')
        delete @players[id]
        this.renderPlayers()
        if @in_game
            this.addMsg('Searching for players..')

    chatReceived: (msg_info) =>
        text = $('<div/>').text(msg_info.text).html()
        this.addMsg(this.playerLink(msg_info.id) + ': ' + text)

    lobbyFinished: (game_info) =>
        series = _.filter(SERIES_OPTS, (s) -> s.val in game_info.series)
        series = _.pluck(series, 'label')
        series = series.join(', ')
        maps = (MAP_LABELS[m] for m in game_info.maps).join(', ')
        this.addMsg('Lobby complete!')
        this.addMsg('Series type: ' + series)
        this.addMsg('Maps: ' + maps)
        this.addMsg('First map: ' + MAP_LABELS[game_info.random_map])

    exitLobby: =>
        @app.exitLobby()

    sendChat: =>
        msg_box = this.$('#msg-box')
        msg = msg_box.val()
        return if not msg
        msg_box.val('')
        if not @app.isLoggedIn()
            this.addMsg('You are not logged in. Login to chat!')
        else if this.rateOk()
            this.chatReceived({id: @app.getServer().getID(), text: msg})
            @app.getServer().sendChat(msg)

    sendChatOnEnter: (e) =>
        this.sendChat() if e.keyCode is 13

    blockPlayer: (e) =>
        e.preventDefault()
        this.$('.alert-message').remove()
        player = e.target.hash.slice(1)
        @app.addToBlocklist(player)
        $(@el).prepend(this._render('alert-message', {type: 'success', msg: player + ' successfully blocked. You will no longer see games with this player.'}))

    addMsg: (msg) =>
        timestamp = new Date().toString('HH:mm:ss')
        this.$('#msg-list').append(this._render('chat-msg',
            timestamp: timestamp
            msg: msg
        ))
        box = this.$('#chat-box')
        box.scrollTop(box[0].scrollHeight)

    rateOk: =>
        now = new Date().getTime()
        if @chat_blocked
            if now > @chat_blocked
                @last_chat_times = [now]
                @chat_blocked = false
                return true
            else
                return false
        else
            if @last_chat_times.length < 4
                @last_chat_times.push(now)
                return true
            else if now - @last_chat_times[0] < 2000
                @chat_blocked = now + 5000
                this.addMsg('You are spamming the chat. Wait 5 seconds.')
                return false
            else
                @last_chat_times.push(now)
                @last_chat_times.shift()
                return true

    playerLink: (id) =>
        player_info = @players[id]
        return this._render('player-link', {player: player_info})
    
    _updatePlayers: (players) =>
        if @app.isLoggedIn()
            players[@app.getServer().getID()].this_player = true
        @players = players
        this.renderPlayers()
