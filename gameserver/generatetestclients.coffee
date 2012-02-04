sqlite3 = require('sqlite3')

NUM_CLIENTS = 500

LEAGUES = ['n', 'b', 's', 'g', 'p', 'd', 'm', 'gm']

db = new sqlite3.Database('profiles.db')
for num in [0..NUM_CLIENTS-1]
    league = LEAGUES[Math.floor(Math.random()*LEAGUES.length)]
    @db.run(
        'INSERT INTO profiles (url, region, name, league) VALUES ($1, $2, $3, $4)',
        [num, 'AM', 'client-' + num, league],
        (err) =>
            if err
                console.log(err)
                process.exit()
    )
