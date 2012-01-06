class window.CGFView extends Backbone.View
    BNET_REGIONS:
        'www.battlenet.com.cn': 'CN'
        'sea.battle.net': 'SEA'
        'us.battle.net': 'AM'
        'eu.battle.net': 'EU'
        'kr.battle.net': 'KR'

    initialize: =>
        @login_view = new LoginView({app: this})
        @user_details_view = new UserDetailsView({app: this})
        @create_lobby_view = new CreateLobbyView({app: this})
        @lobby_view = new LobbyView({app: this})

    render: =>
        @user_details_view.show()
        @create_lobby_view.show()
        if not CurrentUser.logged_in
            @login_view.show()

    login: (profile_url, char_code, league, race) =>
        login_valid = true
        uri = new Uri(profile_url)
        region = @BNET_REGIONS[uri.host()]
        if not region?
            login_valid = false
            @login_view.error('profile-url', 'Bad URL')
        else
            name = _(uri.path().split('/')).chain()
                .without('')
                .last()
                .value()
            if not name?
                login_valid = false
                @login_view.error('profile-url', 'Bad URL')
        if not char_code or /\D/.test(char_code)
            login_valid = false
            @login_view.error('char-code',
                'Character code must contain only 3 digits')
        if login_valid
            CurrentUser.login(profile_url, region, name, char_code, league, race)
            @create_lobby_view.render()
            @login_view.hide()

    createLobby: =>
        @user_details_view.preventChanges()
        @create_lobby_view.hide()
        @lobby_view.show()
        GameServer.createLobby()

    exitLobby: =>
        GameServer.exitLobby()
        @lobby_view.hide()
        @create_lobby_view.show()
        @user_details_view.allowChanges()

class window.LoginView extends Backbone.View
    id: 'login-view'

    events:
        'keypress input': 'loginOnEnter'
        'click #login-btn': 'login'

    show: =>
        $(@el).html(render('login-form',
            leagues: LEAGUE_OPTS
            races: RACE_OPTS
        ))
        $('body').append(@el)

    hide: =>
        $(@el).detach()

    login: =>
        this.$('.clearfix').removeClass('error')
        this.$('input').removeClass('error')
        this.$('.help-inline').remove()
        profile_url = this.$('#login-profile-url').val()
        char_code = this.$('#login-char-code').val()
        league = this.$('#login-league option:selected').val()
        race = this.$('#login-race option:selected').val()
        @options.app.login(profile_url, char_code, league, race)

    loginOnEnter: (e) =>
        this.login() if e.keyCode is 13

    error: (field, msg) =>
        this.$('#login-' + field + '-cf').addClass('error')
        input = this.$('#login-' + field)
        input.addClass('error')
        input.after(render('form-error', {msg: msg}))

class window.UserDetailsView extends Backbone.View
    id: 'user-details-view'

    events:
        'click #logout-btn': 'logout'
        'change #race-select': 'changeRace'
        'change #league-select': 'changeLeague'

    initialize: =>
        CurrentUser.bind('change', @render)

    render: =>
        selects = ''
        if CurrentUser.logged_in
            selects += render('user-select',
                id: 'league'
                label: 'League'
                selected: CurrentUser.league
                opts: LEAGUE_OPTS
            )
            selects += render('user-select',
                id: 'race'
                label: 'Race'
                selected: CurrentUser.race
                opts: RACE_OPTS
            )
        $(@el).html(render('user-details',
            user: CurrentUser
            selects: selects
        ))

    show: =>
        this.render()
        $('#cgf-sidebar').append(@el)

    logout: =>
        CurrentUser.logout()
        window.location.reload()

    changeRace: =>
        race = this.$('#race-select option:selected').val()
        CurrentUser.changeRace(race)

    changeLeague: =>
        league = this.$('#league-select option:selected').val()
        CurrentUser.changeLeague(league)

    preventChanges: =>
        this.$('select').attr('disabled', 'disabled')

    allowChanges: =>
        this.$('select').removeAttr('disabled')
