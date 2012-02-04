io = require('socket.io-client')
sqlite3 = require('sqlite3').verbose()
util = require('util')

NUM_CLIENTS = 500
RACES = ['r', 't', 'z', 'p']

runClient = ->
    options = {}
    options['force new connection'] = true
    socket = io.connect('http://aeacus.moregg.sc:8080', options)
    data =
        s: socket
        id: Math.floor(Math.random()*NUM_CLIENTS)
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
    request =
        char_code: '123'
        profile_url: data.id
        race: data.race
        params:
            opp_races: RACES
            opp_leagues: [data.league]
            maps: ['blz_ap', 'blz_as', 'blz_ev', 'blz_me', 'blz_sp', 'blz_tdale', 'blz_st', 'blz_xnc']
            series: ['bo1']
            blocked_users: {}
    data.s.emit('createLobby', request, (players) ->
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

setInterval(runClient, 500)
