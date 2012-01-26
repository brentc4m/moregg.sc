class window.CGFView extends Backbone.View
    BNET_REGIONS:
        'www.battlenet.com.cn': 'CN'
        'sea.battle.net': 'SEA'
        'us.battle.net': 'AM'
        'eu.battle.net': 'EU'
        'kr.battle.net': 'KR'

    initialize: =>
        @login_view = new LoginView({app: this})
        @user_settings_view = new UserSettingsView({app: this})
        @blocklist_view = new BlocklistView({app: this})
        @create_lobby_view = new CreateLobbyView({app: this})
        @lobby_view = new LobbyView({app: this})
        GameServer.bind('connect', this.connected)
        GameServer.connect()

    render: =>
        @lobby_view.show()
        if CurrentUser.logged_in
            @user_settings_view.show()
        else
            @login_view.show()

    connected: =>
        GameServer.joinGlobalLobby()

    login: (profile_url, char_code, race) =>
        login_valid = true
        if not char_code or char_code.length isnt 3 or /\D/.test(char_code)
            login_valid = false
            @login_view.error('char-code',
                'Character code must contain only 3 digits')
        if login_valid
            @login_view.loggingIn()
            GameServer.getUserProfile(profile_url, (err, profile) =>
                return @login_view.error('profile-url', err) if err
                CurrentUser.login(profile_url, profile.region, profile.name,
                    char_code, profile.league, race)
                @login_view.hide()
                @user_settings_view.show()
                GameServer.joinGlobalLobby()
            )

    showCreateLobby: =>
        @create_lobby_view.show()
    
    showLobby: =>
        @lobby_view.show()

    createLobby: =>
        GameServer.createLobby()
        @lobby_view.show()

    exitLobby: =>
        GameServer.exitLobby()
        GameServer.joinGlobalLobby()

    showBlocklist: =>
        @blocklist_view.show()

    addBlocklist: (user) =>
        LobbyOptions.opts.blocked_users[user] = true
        LobbyOptions.save()

    removeBlocklist: (users) =>
        for user in users
            delete LobbyOptions.opts.blocked_users[user]
        LobbyOptions.save()

class window.LoginView extends Backbone.View
    id: 'login-view'

    events:
        'keypress input': 'loginOnEnter'
        'click #login-btn': 'login'

    show: =>
        $(@el).html(render('login-form', races: RACE_OPTS))
        $('#cgf-sidebar').append(@el)

    hide: =>
        $(@el).detach()

    login: =>
        this.$('input').removeClass('error')
        this.$('.help-inline').remove()
        profile_url = this.$('#login-profile-url').val()
        char_code = this.$('#login-char-code').val()
        race = this.$('#login-race option:selected').val()
        @options.app.login(profile_url, char_code, race)

    loginOnEnter: (e) =>
        this.login() if e.keyCode is 13

    error: (field, msg) =>
        input = this.$('#login-' + field)
        input.addClass('error')
        this.$('form').after(render('form-error', {msg: msg}))
        this.$('#login-msg').remove()
        this.$('#login-btn').removeClass('disabled')

    loggingIn: =>
        this.$('form').after(render('login-msg', {msg: 'Gathering profile data, please wait..'}))
        this.$('#login-btn').addClass('disabled')

class window.UserSettingsView extends Backbone.View
    id: 'user-settings-view'

    events:
        'click #find-game-btn': 'findGame'
        'click #exit-lobby-btn': 'exitLobby'
        'click #open-blocklist-btn': 'openBlocklist'
        'click #logout-btn': 'logout'
        'change #race-select': 'changeRace'

    initialize: =>
        @in_game = false
        GameServer.bind('lobbyJoined', this.lobbyJoined)

    render: =>
        race_select = render('user-select',
            id: 'race'
            label: 'Race'
            selected: CurrentUser.race
            opts: RACE_OPTS
            disabled: @in_game
        )
        $(@el).html(render('user-settings',
            user: CurrentUser
            race_select: race_select
            in_game: @in_game
        ))

    show: =>
        this.render()
        $('#cgf-sidebar').append(@el)

    hide: =>
        $(@el).detach()

    logout: =>
        CurrentUser.logout()
        window.location.reload()

    changeRace: =>
        race = this.$('#race-select option:selected').val()
        CurrentUser.changeRace(race)

    lobbyJoined: (global, players) =>
        @in_game = not global
        this.render()

    findGame: =>
        this.options.app.showCreateLobby()

    exitLobby: =>
        this.options.app.exitLobby()

    openBlocklist: =>
        this.options.app.showBlocklist()

class window.BlocklistView extends Backbone.View
    id: 'blocklist-view'

    events:
        'keypress input': 'addOnEnter'
        'click #blocklist-add-btn':  'add'
        'click #blocklist-remove-btn': 'remove'
        'click #blocklist-close-btn': 'close'

    render: =>
        $(@el).html(render('blocklist-editor',
            {blocklist: _.keys(LobbyOptions.opts.blocked_users)}))

    show: =>
        this.render()
        $('#cgf-content > *').detach()
        $('#cgf-content').append(@el)

    close: =>
        this.options.app.showLobby()

    addOnEnter: (e) =>
        this.add() if e.keyCode is 13

    add: =>
        this.$('.help-inline').remove()
        name = this.$('#blocklist-add-name').val()
        char_code = this.$('#blocklist-add-code').val()
        valid = true
        if name.length is 0
            this.error('add-name', 'Enter a name')
            valid = false
        if not char_code or char_code.length isnt 3 or /\D/.test(char_code)
            this.error('add-code', 'Code must be exactly 3 digits')
            valid = false
        if valid
            this.options.app.addBlocklist(name + '.' + char_code)
            this.render()

    remove: =>
        selected = this.$('#blocklist-remove-select option:selected')
        users = (o.value for o in selected)
        this.options.app.removeBlocklist(users) if users.length isnt 0
        this.render()

    error: (field, msg) =>
        this.$('#blocklist-add-btn').after(render('form-error', {msg: msg}))
