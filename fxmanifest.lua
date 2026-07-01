fx_version 'adamant'
game 'rdr3'
author 'devchacha'
description 'VORP Farming System'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/bg_farming.jpg'
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'vorp_progressbar'
}
