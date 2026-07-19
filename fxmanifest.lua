fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bsrp-pdm'
author 'BS Race'
description 'BSRP PDM vehicle shop — MySQL purchase log + garage SQL'
version '2.0.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependency 'oxmysql'
