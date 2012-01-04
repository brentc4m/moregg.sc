$ ->
    # Not sure why but Backbone.Events can't be extended
    class Events
    Events.prototype extends Backbone.Events

    class CurrentUserGlobal extends Events
        constructor: ->
            if localStorage['cgf.logged_in']
                for attr in ['name', 'char_code', 'profile_url', 'region']
                    this[attr] = localStorage['cgf.' + attr]
                @logged_in = true
            else
                @logged_in = false

        toJSON: =>
            name: @name
            char_code: @char_code
            profile_url: @profile_url

        logout: =>
            for attr in ['name', 'char_code', 'profile_url', 'region']
                delete localStorage['cgf.' + attr]
                delete this[attr]
            delete localStorage['cgf.logged_in']
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
    CurrentUser = new CurrentUserGlobal()

    class GameServerGlobal extends Events
        constructor: ->
            @socket = io.connect('http://localhost:5000')

        createLobby: =>
            request =
                name: CurrentUser.name
                char_code: CurrentUser.char_code
                profile_url: CurrentUser.profile_url
                params:
                    region: CurrentUser.region
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
    GameServer = new GameServerGlobal()

    getTemplate = _.memoize((id) ->
        return _.template($('#' + id + '-tmpl').html())
    )

    render = (id, data) ->
        tmpl = getTemplate(id)
        return tmpl(data)

    class UserDetailsView extends Backbone.View
        id: 'user-details-view'

        events:
            'click #logout-btn': 'logout'

        initialize: =>
            CurrentUser.bind('change', @render)

        render: =>
            $(@el).html(render('user-details', {user: CurrentUser}))

        show: =>
            this.render()
            $('#cgf-sidebar').append(@el)

        logout: =>
            CurrentUser.logout()
            window.location.reload()

    class LoginView extends Backbone.View
        id: 'login-view'

        events:
            'keypress #profile-url': 'loginOnEnter'
            'keypress #char-code': 'loginOnEnter'
            'click #login-btn': 'login'

        show: =>
            $(@el).html(render('login-form'))
            $('body').append(@el)

        hide: =>
            $(@el).detach()

        login: =>
            this.$('.clearfix').removeClass('error')
            this.$('input').removeClass('error')
            this.$('.help-inline').remove()
            profile_url = this.$('#profile-url').val()
            char_code = this.$('#char-code').val()
            @options.app.login(profile_url, char_code)

        loginOnEnter: (e) =>
            this.login() if e.keyCode is 13

        error: (field, msg) =>
            this.$('#' + field + '-cf').addClass('error')
            input = this.$('#' + field)
            input.addClass('error')
            input.after(render('form-error', {msg: msg}))

    class CreateLobbyView extends Backbone.View
        id: 'create-lobby-view'

        events:
            'click #create-lobby-btn': 'createLobby'

        show: =>
            $(@el).html(render('create-lobby'))
            $('#cgf-content').append(@el)

        hide: =>
            $(@el).detach()

        createLobby: =>
            this.options.app.createLobby()

    class LobbyView extends Backbone.View
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
        
    class CGFView extends Backbone.View
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

        exitLobby: =>
            GameServer.exitLobby()
            @lobby_view.hide()
            @create_lobby_view.show()

    new CGFView().render()
