$ ->
    # Not sure why but Backbone.Events can't be extended
    class Events
    Events.prototype extends Backbone.Events

    class window.CurrentUserGlobal extends Events
        constructor: ->
            if localStorage['cgf.logged_in']
                @name = localStorage['cgf.name']
                @char_code = localStorage['cgf.char_code']
                @profile_url = localStorage['cgf.profile_url']
                @region = localStorage['cgf.region']
                @logged_in = true
            else
                @logged_in = false

        toJSON: =>
            name: @name
            char_code: @char_code
            profile_url: @profile_url
            region: @region

        logout: =>
            delete localStorage['cgf.logged_in']
            delete localStorage['cgf.name']
            delete localStorage['cgf.char_code']
            delete localStorage['cgf.profile_url']
            delete localStorage['cgf.region']
            delete @name
            delete @char_code
            delete @profile_url
            delete @region
            @logged_in = false
            this.trigger('change')

        login: (profile_url, region, name, char_code) =>
            @name = localStorage['cgf.name'] = name
            @char_code = localStorage['cgf.char_code'] = char_code
            @profile_url = localStorage['cgf.profile_url'] = profile_url
            @region = localStorage['cgf.region'] = region
            localStorage['cgf.logged_in'] = 'true'
            @logged_in = true
            this.trigger('change')
    window.CurrentUser = new CurrentUserGlobal()

    class GameServerGlobal extends Events
        constructor: ->
            @socket = io.connect('http://brentc4m.dyndns.org:8080')

        createLobby: =>
            request =
                name: CurrentUser.name
                char_code: CurrentUser.char_code
                profile_url: CurrentUser.profile_url
                params:
                    region: CurrentUser.region
            @socket.on('lobbyCreated', (d) => this.trigger('lobbyCreated', d))
            @socket.on('playerJoined', (d) => this.trigger('playerJoined', d))
            @socket.on('chatReceived', (d) => this.trigger('chatReceived', d))
            @socket.emit('createLobby', request)

        sendChat: (msg) =>
            @socket.emit('sendChat', msg)

    window.GameServer = new GameServerGlobal()

    class window.UserDetailsView extends Backbone.View
        id: 'user-details-view'

        tmpl: _.template($('#user-details-tmpl').html())

        initialize: =>
            CurrentUser.bind('change', @render)

        render: =>
            $(@el).html(this.tmpl({user: CurrentUser}))

        show: =>
            this.render()
            $('#cgf-sidebar').append(@el)

        hide: =>
            $(@el).detach()

    class window.LoginView extends Backbone.View
        id: 'login-view'

        events:
            'keypress #profile-url': 'loginOnEnter'
            'keypress #char-code': 'loginOnEnter'
            'click #login-btn': 'login'

        formTmpl: _.template($('#login-form-tmpl').html())

        errorTmpl: _.template($('#form-error-tmpl').html())

        render: =>
            $(@el).html(this.formTmpl())

        show: =>
            this.render()
            $('body').append(@el)

        hide: =>
            $(@el).detach()

        login: =>
            this.clearErrors()
            profile_url = this.$('#profile-url').val()
            char_code = this.$('#char-code').val()
            @options.app.login(profile_url, char_code)

        loginOnEnter: (e) =>
            this.login() if e.keyCode is 13

        clearErrors: =>
            this.$('.clearfix').removeClass('error')
            this.$('input').removeClass('error')
            this.$('.help-inline').remove()

        error: (field, msg) =>
            this.$('#' + field + '-cf').addClass('error')
            input = this.$('#' + field)
            input.addClass('error')
            input.after(this.errorTmpl({msg: msg}))

    class window.CreateLobbyView extends Backbone.View
        id: 'create-lobby-view'

        events:
            'click #create-lobby-btn': 'createLobby'

        tmpl: _.template($('#create-lobby-tmpl').html())

        render: =>
            $(@el).html(this.tmpl())

        show: =>
            this.render()
            $('#cgf-content').append(@el)

        hide: =>
            $(@el).detach()

        createLobby: =>
            this.options.app.createLobby()

    class window.LobbyView extends Backbone.View
        id: 'lobby-view'

        events:
            'click #send-chat-btn': 'sendChat'
            'keypress #msg-box': 'sendChatOnEnter'

        tmpl: _.template($('#lobby-tmpl').html())

        playersTmpl: _.template($('#lobby-players-tmpl').html())

        playerLinkTmpl: _.template($('#player-link-tmpl').html())

        msgTmpl: _.template($('#chat-msg-tmpl').html())

        initialize: =>
            @players = []
            @lobby_id = null
            GameServer.bind('lobbyCreated', this.lobbyCreated)
            GameServer.bind('playerJoined', this.playerJoined)
            GameServer.bind('chatReceived', this.chatReceived)

        render: =>
            $(@el).html(this.tmpl())

        renderPlayers: =>
            this.$('#user-list').html(this.playersTmpl(
                players: @players
                player_link: this.playerLinkTmpl
            ))

        show: =>
            this.render()
            $('#cgf-content').append(@el)
            this.$('#msg-box').focus()
            this.addMsg('Creating lobby..')

        hide: =>
            $(@el).detach()

        sendChat: =>
            msg_box = this.$('#msg-box')
            msg = msg_box.val()
            msg_box.val('')
            this.chatReceived({id: @lobby_id, text: msg})
            GameServer.sendChat(msg)

        sendChatOnEnter: (e) =>
            this.sendChat() if e.keyCode is 13

        addMsg: (msg) =>
            timestamp = new Date().toString('HH:mm:ss')
            this.$('#msg-list').append(this.msgTmpl(
                timestamp: timestamp
                msg: msg
            ))

        lobbyCreated: (lobby_info) =>
            @lobby_id = lobby_info.id
            this.addMsg('Lobby #' + lobby_info.id + ' created')
            curr_player = CurrentUser.toJSON()
            curr_player.id = @lobby_id
            this.playerJoined(curr_player)

        playerJoined: (player_info) =>
            @players.push(player_info)
            this.renderPlayers()
            player_link = this.playerLinkTmpl({player: player_info})
            this.addMsg(player_link + ' has joined the lobby')

        chatReceived: (msg_info) =>
            player_info = _.find(@players, (p) -> p.id == msg_info.id)
            player_link = this.playerLinkTmpl({player: player_info})
            this.addMsg(player_link + ': ' + msg_info.text)
        
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

        login: (profile_url, char_code) =>
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
                CurrentUser.login(profile_url, region, name, char_code)
                @login_view.hide()

        createLobby: =>
            @create_lobby_view.hide()
            @lobby_view.show()
            GameServer.createLobby()

    new CGFView().render()
