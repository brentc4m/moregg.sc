[MoreGG](http://moregg.sc/) - Starcraft 2 Custom Game Finder
============================================================

Here you'll find the full source to [MoreGG.sc](http://moregg.sc). Feel free
to make changes and send pull requests and I'll do my best to get them live if
it looks good.

Getting Started
---------------

Follow these steps to get started on a base Ubuntu 11.10 install.

### Server

    sudo apt-get install build-essential libssl-dev sqlite3 libsqlite3-dev
    wget http://nodejs.org/dist/v0.6.11/node-v0.6.11.tar.gz
    tar xzf node-v0.6.11.tar.gz
    cd node-v0.6.11
    ./configure && make
    sudo make install
    sudo npm install -g coffee-script
    cd moregg.sc/gameserver
    npm install
    sqlite3 -init schema.sql profiles.db < /dev/null
    sudo coffee gameserver.coffee

### WebUI

    sudo apt-get install ruby rubygems
    sudo gem install stasis coffee-script haml sass
    sudo sed -i 's/ 00:00:00.000000000Z//' /var/lib/gems/1.8/specifications/*
    cd moregg.sc/webui
    ./run_dev_server

You should now be able to access the WebUI from your browser at
[http://localhost:4000](http://localhost:4000). By default it will try to
connect to the production game server. To change this you'll need to set the
LocalStorage value `gameserver.url` to `http://localhost:443`. You can modify
LocalStorage values in Chrome by opening the developer tools (Ctrl-Shift-I)
and clicking the Resources tab. You'll see Local Storage on the left.

Main Files
----------

To make changes to the server you'll want to edit
`gameserver/gameserver.coffee`. The server uses socket.io to talk to clients.
There are a number of classes for handling the different kinds of lobbies
(global, 1v1, custom).

To make changes to the UI see:

 - `webui/src/games/index.html.haml`
 - `webui/src/js/app.js.coffee`
 - `webui/src/js/views/main.js.coffee`
 - `webui/src/js/views/lobbies.js.coffee`

The UI uses [Backbone.js](http://documentcloud.github.com/backbone/) for
organization and [Underscore.js](http://documentcloud.github.com/underscore/)
for templating.
