local class = require"engine.class"
local ActorTalents = require "engine.interface.ActorTalents"
local ActorTemporaryEffects = require "engine.interface.ActorTemporaryEffects"
local ActorInventory = require "engine.interface.ActorInventory"
local Birther = require "engine.Birther"
local DamageType = require "engine.DamageType"
local Zone = require "engine.Zone"


class:bindHook("ToME:load", function(self, data)
    ActorTalents:loadDefinition('/data-devgen-cultist-rebalance/talents.lua')
end)