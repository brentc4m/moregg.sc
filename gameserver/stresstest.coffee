io = require('socket.io-client')
sqlite3 = require('sqlite3').verbose()
util = require('util')

LEAGUES = ['n', 'b', 's', 'g', 'p', 'd', 'm', 'gm']
RACES = ['r', 't', 'z', 'p']

# Generate profile
# createLobby
# at lobbyFinished, sendChat 5 times 1s apart
# exitLobby
# repeat createLobby

profile_db = new sqlite3.Database('profiles.db')

runClient = ->
    #util.debug('runClient')
    options = {}
    options['force new connection'] = true
    socket = io.connect('http://localhost:5000', options)
    data =
        s: socket
        league: LEAGUES[Math.floor(Math.random()*LEAGUES.length)]
        race: RACES[Math.floor(Math.random()*RACES.length)]
    socket.on('connect', createProfile(data))

createProfile = (data) ->
    return ->
        data.id = data.s.socket.sessionid
        #util.debug('createProfile ' + data.id)
        profile_db.run(
            'INSERT INTO profiles (url, region, name, league) VALUES ($1, $2, $3, $4)',
            [data.id, 'AM', data.id, data.league],
            (err) =>
                if err
                    util.debug(err)
                    process.exit()
                profileReady(data)
        )

profileReady = (data) ->
    #util.debug('profileReady ' + data.id)
    request =
        name: data.id
        char_code: '123'
        profile_url: data.id
        region: 'AM'
        race: data.race
        params:
            opp_races: RACES
            opp_leagues: [data.league]
            maps: ['blz_ap', 'blz_as', 'blz_ev', 'blz_me', 'blz_sp', 'blz_tdale', 'blz_st', 'blz_xnc']
            series: ['bo1']
            blocked_users: {}
    data.s.emit('createLobby', request, lobbyCreated(data))

lobbyCreated = (data) ->
    return ->
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

setInterval(runClient, 20)
