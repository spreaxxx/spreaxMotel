fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Spreax'
description 'A simple motel script'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

