io = require('socket.io-client')
sqlite3 = require('sqlite3').verbose()
util = require('util')
_ = require('underscore')

RACES = ['r', 't', 'z', 'p']

runClient = (id) ->
    console.log(id)
    options = {}
    options['force new connection'] = true
    socket = io.connect('http://aeacus.moregg.sc:8080', options)
    data =
        s: socket
        id: id
        race: RACES[Math.floor(Math.random()*RACES.length)]
    socket.on('connect', createProfile(data))

createProfile = (data) ->
    return ->
        #util.debug('createProfile ' + data.id)
        data.s.emit('getUserProfile', data.id, (err, profile) ->
            if err
                util.debug(err)
                process.exit()
            _.extend(data, profile)
            profileReady(data)
        )

profileReady = (data) ->
    #util.debug('profileReady ' + data.id)
    request =
        char_code: '123'
        profile_url: data.id
        race: data.race
    data.s.emit('joinGlobalLobby', request, (players) ->
        setTimeout(createLobby, 5000, data)
    )

createLobby = (data) ->
    player =
        char_code: '123'
        profile_url: data.id
        race: data.race
    lobby_opts =
        opp_races: RACES
        opp_leagues: ['n', 'b', 's', 'g', 'p', 'd', 'm', 'gm']
        maps: ['blz_ap', 'blz_as', 'blz_ev', 'blz_me', 'blz_sp', 'blz_tdale', 'blz_st', 'blz_xnc']
        series: ['bo1']
        blocked_users: {}
    data.s.emit('createLobby', player, lobby_opts, (players) ->
        lobbyCreated(data)
    )

lobbyCreated = (data) ->
    #util.debug('lobbyCreated ' + data.id)
    data.s.on('lobbyFinished', lobbyFinished(data))

lobbyFinished = (data) ->
    return ->
        data.s.removeAllListeners('lobbyFinished')
        #util.debug('lobbyFinished ' + data.id)
        num_chats = Math.ceil(Math.random()*10)
        sendChat(data, 0, num_chats)

sendChat = (data, idx, max) ->
    #util.debug('sendChat ' + data.id + ' ' + (idx+1) + '/' + max)
    data.s.emit('sendChat', 'test chat ' + idx)
    idx += 1
    if idx < max
        setTimeout(sendChat, 1000, data, idx, max)
    else
        data.s.emit('exitLobby')
        profileReady(data)

for id in [0..100]
    setTimeout(runClient, 250*id, id)
