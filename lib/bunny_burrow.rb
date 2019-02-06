require 'bunny_burrow/version'
require 'bunny_burrow/client'
require 'bunny_burrow/server'

MessagePack::DefaultFactory.register_type(0x00, Symbol)

module BunnyBurrow
end
