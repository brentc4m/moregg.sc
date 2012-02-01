class window.App
    constructor: ->
        @server = new GameServer()

        @login_view = new LoginView(this)
        @user_settings_view = new UserSettingsView(this)
        @blocklist_view = new BlocklistView(this)
        @create_lobby_view = new CreateLobbyView(this)
        @lobby_view = new LobbyView(this)

        @session = {}
        @config = null
        if 'session.profile_url' of localStorage
            this._initSession(localStorage['session.profile_url'])

    start: =>
        @lobby_view.show()
        @server.bind('connect', this._connected)
        @server.connect()

    isLoggedIn: =>
        return @config isnt null

    login: (profile_url, char_code, race) =>
        login_valid = true
        if not char_code or char_code.length isnt 3 or /\D/.test(char_code)
            login_valid = false
            @login_view.error('char-code',
                'Character code must contain only 3 digits')
        if login_valid
            @login_view.loggingIn()
            @server.getUserProfile(profile_url, (err, profile) =>
                return @login_view.error('profile-url', err) if err
                this._initSession(profile_url)
                this._initProfile(profile)
                @config.set('char_code', char_code)
                @config.set('race', race)
                @config.set('opp_leagues', [profile.league])
                @user_settings_view.show()
                this._joinGlobalLobby()
            )

    logout: =>
        delete localStorage['session.profile_url']
        window.location.reload()

    showCreateLobby: =>
        @create_lobby_view.show()
    
    showLobby: =>
        @lobby_view.show()

    createLobby: =>
        @server.createLobby(this._getPlayerForServer(), this._getLobbyOpts())
        @lobby_view.show()

    exitLobby: =>
        @server.exitLobby()
        this._joinGlobalLobby()

    showBlocklist: =>
        @blocklist_view.show()

    getPlayer: =>
        player = _.clone(@session)
        _.extend(player, @config.getSet(['char_code', 'race']))
        return player

    getServer: =>
        return @server

    getConfig: =>
        return @config

    addToBlocklist: (player) =>
        blocked = @config.get('blocked_users')
        blocked[player] = true
        @config.set('blocked_users', blocked)

    removeFromBlocklist: (players) =>
        blocked = @config.get('blocked_users')
        delete blocked[p] for p in players
        @config.set('blocked_users', blocked)
    
    _connected: =>
        if this.isLoggedIn()
            @server.getUserProfile(@session['profile_url'], (err, profile) =>
                return if err
                this._initProfile(profile)
                @user_settings_view.show()
                this._joinGlobalLobby()
            )
        else
            @login_view.show()
            this._joinGlobalLobby()

    _initSession: (profile_url) =>
        localStorage['session.profile_url'] = profile_url
        @session = {profile_url: profile_url}
        @config = new UserConfig(@session['profile_url'])

    _initProfile: (profile) =>
        _.extend(@session, profile)

    _joinGlobalLobby: =>
        @server.joinGlobalLobby(this._getPlayerForServer())

    _getPlayerForServer: =>
        return null unless this.isLoggedIn()
        return {
            profile_url: @session['profile_url']
            char_code: @config.get('char_code')
            race: @config.get('race')
        }

    _getLobbyOpts: =>
        return @config.getSet(['opp_races', 'opp_leagues', 'maps', 'series',
            'blocked_users'])

class window.LoginView extends View
    id: 'login-view'

    container_id: 'cgf-sidebar'

    events:
        'keypress input': 'loginOnEnter'
        'click #login-btn': 'login'

    render: =>
        $(@el).html(this._render('login-form', races: RACE_OPTS))

    login: =>
        this.$('input').removeClass('error')
        this.$('.help-inline').remove()
        profile_url = this.$('#login-profile-url').val()
        char_code = this.$('#login-char-code').val()
        race = this.$('#login-race option:selected').val()
        @app.login(profile_url, char_code, race)

    loginOnEnter: (e) =>
        this.login() if e.keyCode is 13

    error: (field, msg) =>
        input = this.$('#login-' + field)
        input.addClass('error')
        this.$('form').after(this._render('form-error', {msg: msg}))
        this.$('#login-msg').remove()
        this.$('#login-btn').removeClass('disabled')

    loggingIn: =>
        this.$('form').after(this._render('login-msg',
            {msg: 'Gathering profile data, please wait..'}))
        this.$('#login-btn').addClass('disabled')

class window.UserSettingsView extends View
    id: 'user-settings-view'

    container_id: 'cgf-sidebar'

    events:
        'click #find-game-btn': 'findGame'
        'click #exit-lobby-btn': 'exitLobby'
        'click #open-blocklist-btn': 'openBlocklist'
        'click #logout-btn': 'logout'
        'change #race-select': 'changeRace'

    initialize: =>
        @in_game = false
        @app.getServer().bind('lobbyJoined', this.lobbyJoined)

    render: =>
        race_select = this._render('user-select',
            id: 'race'
            label: 'Race'
            selected: @app.getConfig().get('race')
            opts: RACE_OPTS
            disabled: @in_game
        )
        $(@el).html(this._render('user-settings',
            user: @app.getPlayer()
            race_select: race_select
            in_game: @in_game
        ))

    logout: =>
        @app.logout()

    changeRace: =>
        race = this.$('#race-select option:selected').val()
        @app.getConfig().set('race', race)

    lobbyJoined: (global, players) =>
        if @app.isLoggedIn()
            @in_game = not global
            this.render()

    findGame: =>
        @app.showCreateLobby()

    exitLobby: =>
        @app.exitLobby()

    openBlocklist: =>
        @app.showBlocklist()

class window.BlocklistView extends View
    id: 'blocklist-view'

    events:
        'keypress input': 'addOnEnter'
        'click #blocklist-add-btn':  'add'
        'click #blocklist-remove-btn': 'remove'
        'click #blocklist-close-btn': 'close'

    render: =>
        $(@el).html(this._render('blocklist-editor',
            {blocklist: _.keys(@app.getConfig().get('blocked_users'))}))

    close: =>
        @app.showLobby()

    addOnEnter: (e) =>
        this.add() if e.keyCode is 13

    add: =>
        this.$('.help-inline').remove()
        name = this.$('#blocklist-add-name').val()
        char_code = this.$('#blocklist-add-code').val()
        if name.length is 0
            return this.error('add-name', 'Enter a name')
        if not char_code or char_code.length isnt 3 or /\D/.test(char_code)
            return this.error('add-code', 'Code must be exactly 3 digits')
        @app.addToBlocklist(name + '.' + char_code)
        this.render()

    remove: =>
        selected = this.$('#blocklist-remove-select option:selected')
        users = (o.value for o in selected)
        if users.length isnt 0
            @app.removeFromBlocklist(users)
            this.render()

    error: (field, msg) =>
        this.$('#blocklist-add-btn').after(this._render('form-error', {msg: msg}))
