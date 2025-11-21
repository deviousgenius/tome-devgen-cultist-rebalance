local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

local T_HIDEOUS_VISIONS = Talents.talents_def.T_HIDEOUS_VISIONS
local T_SANITY_WARP = Talents.talents_def.T_SANITY_WARP

-- Hideous Visions

T_HIDEOUS_VISIONS.getChance = function(self, t) return self:combatTalentScale(t, 10, 30) end
T_HIDEOUS_VISIONS.radius = function(self, t) return self:combatTalentScale(t, 1, 2.6) end
T_HIDEOUS_VISIONS.getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 60) end
T_HIDEOUS_VISIONS.getDuration = function(self, t) return self:combatTalentScale(t, 2, 6) end

T_HIDEOUS_VISIONS.hideous_vision = function(self, t, target, from_sanity_warp)
	if not target.dead then

		if target._hallucination and not target._hallucination.dead then
			target._hallucination:die(self, from_sanity_warp)
		end

		local x, y = util.findFreeGrid(target.x, target.y, 1, true, {[Map.ACTOR]=true})
		if not x then
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			name = _t"hallucination",
			display = "h", color=colors.DARK_GREY, image="npc/horror_eldritch_nightmare_horror.png",
			blood_color = colors.BLUE,
			type = "horror", subtype = "eldritch",
			rank = 2,
			size_category = 2,
			body = { INVEN = 10 },
			level_range = {self.level, self.level},
			no_drops = true,
			autolevel = "warriorwill",
			exp_worth = 0,
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=2 },
			stats = { str=15, dex=15, wil=15, con=15, cun=15},
			infravision = 10,
			silent_levelup = true,
			no_breath = 1,
			negative_status_effect_immune = 1,
			infravision = 10,
			resists = {all = 50},
			max_life = resolvers.rngavg(10, 30),
			life_rating = 6,
			combat_armor = 1, combat_def = 10,
			combat = { dam=1, atk=1, apr=1, damtype=DamageType.DARKNESS },

		}
		
		target._hallucination = m
		
		m.faction = self.faction
		m.summoner = self
		m.summoner_gain_exp = true
		m.tg = target
		m.target = target
		m.hallucination = true
		m.from_sanity_warp = from_sanity_warp
		m.on_die = function(self, src, from_sanity_warp)
			local target = self.target
			local DamageType = require "engine.DamageType"

			if target and target._hallucination == self then 
				target._hallucination = nil 
			end

			if target and not target.dead then 
                target:removeEffect(target.EFF_HIDEOUS_VISIONS)
                local t = self.summoner:getTalentFromId(self.summoner.T_HIDEOUS_VISIONS)
                local tg = {type="ball", radius=t.radius(self.summoner, t), range=100, friendlyfire=false, talent=t}
                local damage = self.summoner:spellCrit(t.getDamage(self.summoner, t))
                self.summoner:projectSource(tg, target.x, target.y, DamageType.DARKNESS, damage, nil, t)
                game.level.map:particleEmitter(self.x, self.y, t.radius(self.summoner, t), "generic_ball", {radius=t.radius(self.summoner, t), rm=50, rM=50, gm=50, gM=50, bm=50, bM=50, am=200, aM=255})
                
                -- Apply confusion if this was from Sanity Warp
                if from_sanity_warp or self.from_sanity_warp then
                	local confuse_chance = t.getChance(self.summoner, t)
                	local confuse_tg = {type="ball", radius=t.radius(self.summoner, t), range=100, friendlyfire=false, talent=t}
                	self.summoner:project(confuse_tg, target.x, target.y, DamageType.CONFUSION, {
                		dur=t.getDuration(self.summoner, t) - 1,
                		dam=confuse_chance,
                		power_check=function() return self.summoner:combatSpellpower() end
                	})
                end
                
                if target:hasEffect(target.EFF_CACOPHONY) then
                    local ceff = target:hasEffect(target.EFF_CACOPHONY)
                    local cdam = ceff.power * damage
                    self.summoner:projectSource(tg, target.x, target.y, DamageType.TEMPORAL, cdam, nil, t)
                end
            end
		end
		m.on_act = function(self)
			self.energy.value = 0
		end
		m.summon_time = t.getDuration(self, t)
		m.remove_from_party_on_death = true
		m:resolve() m:resolve(nil, true)
		m:forceLevelup(self.level)			
		local x, y = util.findFreeGrid(x, y, 1, true, {[Map.ACTOR]=true})
		if x then 
			game.zone:addEntity(game.level, m, "actor", x, y)
			target:setEffect(target.EFF_HIDEOUS_VISIONS, t.getDuration(self,t), {src=m, power=t.getDamageReduction(self,t)})
		end
		game.level.map:particleEmitter(x, y, 1, "generic_teleport", {rm=60, rM=130, gm=20, gM=110, bm=90, bM=130, am=70, aM=180})
	end
end

T_HIDEOUS_VISIONS.info = function(self, t)
		local chance = t.getChance(self,t)
		local dur = t.getDuration(self,t)
		local damage = t.getDamageReduction(self,t)
        local sanityWarpDamage = t.getDamage(self,t)
		local radius = self:getTalentRadius(t)
		return ([[Each time an enemy takes damage from Dark Whispers, there is a %d%% chance for one of their visions to manifest in an adjacent tile for %d turns. This vision takes no actions but the victim will deal %d%% reduced damage to all other targets until the vision is slain.
		A target cannot have more than one hallucination at a time.
When a hallucination from Hideous Visions is slain, it unleashes a psychic shriek dealing %0.2f darkness damage to enemies in radius %d.
If hallucinations dying is caused by Sanity Warp, the victim is also confused for %d turns at %d%% power.]]):
		tformat(chance, dur, damage, sanityWarpDamage, radius, dur, chance)
	end

-- Sanity Warp

T_SANITY_WARP.mode = "activated"
T_SANITY_WARP.insanity = 10
T_SANITY_WARP.cooldown = 10
T_SANITY_WARP.requires_target = false
T_SANITY_WARP.no_energy = "fake"
T_SANITY_WARP.on_pre_use = function(self, t, silent)

	-- Must be in a level with entities (Should prevent bug when changing levels)
	if not game.level or not game.level.entities then
		return false
	end

	-- Must know the parent talent
	if not self:getTalentFromId(self.T_HIDEOUS_VISIONS) then
		if not silent then
			game.logPlayer(self, "You must know Hideous Visions to use Sanity Warp.")
		end
		return false
	end

	-- Must have hallucinations
	local found = false
	for uid, target in pairs(game.level.entities) do
		if target and not target.dead and target._hallucination and not target._hallucination.dead then
			if self:reactionToward(target) < 0 then
				found = true
				break
			end
		end
	end

	if not found then
		-- If silent=true, talent use was being *checked* (e.g. AI or hotkey highlight)
		-- and we keep it silent.
		if not silent then
			game.logPlayer(self, "There are no hallucinations to warp.")
		end
		return false
	end

	return true
end



T_SANITY_WARP.getCount = function(self, t) return math.floor(self:combatTalentScale(t, 1, 3)) end

T_SANITY_WARP.action = function(self, t)
	local count = t.getCount(self, t)

	for i = 1, count do
		local targets = {}
		for uid, target in pairs(game.level.entities) do
			if target and not target.dead and target._hallucination and not target._hallucination.dead then
				if self:reactionToward(target) < 0 then
					targets[#targets+1] = target
				end
			end
		end

		-- No need for an error message here anymore — on_pre_use handles it
		for _, target in ipairs(targets) do
			self:getTalentFromId(self.T_HIDEOUS_VISIONS).hideous_vision(
				self,
				self:getTalentFromId(self.T_HIDEOUS_VISIONS),
				target,
				true
			)
		end
	end

	game.logPlayer(self, "Spawned %d wave(s) of hallucinations!", count)
	return true
end


T_SANITY_WARP.info = function(self, t)
	local count = t.getCount(self, t)
	return ([[Spawn up to %d additional hallucinations on enemies who already have one, causing the previous hallucinations to die.]]):
	tformat(count)
end