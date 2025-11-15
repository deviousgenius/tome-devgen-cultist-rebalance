local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

T_REALITY_FRACTURE = Talents.talents_def.T_REALITY_FRACTURE
T_QUANTUM_TUNNELLING = Talents.talents_def.T_QUANTUM_TUNNELLING

-- Reality Fracture

T_REALITY_FRACTURE.no_energy = true

T_REALITY_FRACTURE.callbackOnTalentPost = function(self, t, ab)
		if not rng.percent(50) then return end
		if not ab.type[1]:find("^demented/") then return end
		if ab.mode == "sustained" then return end
		t.create_rift(self, t)
	end

T_REALITY_FRACTURE.info = function(self, t)
		local dur = t.getDuration(self,t)
		local damage = t.getDamage(self,t)/2
		local nb = t.getNb(self,t)
		return ([[The sheer power of your entropy tears holes through spacetime, opening this world to the void.
On casting a Demented spell you have a 50%% chance of creating a void rift lasting %d turns in a nearby tile, which will launch void blasts each turn at a random enemy in range 7, dealing %0.2f darkness and %0.2f temporal damage.

You may activate this talent to forcibly destabilize spacetime, spawning %d void rifts around you.]]):
		tformat(dur, damDesc(self, DamageType.DARKNESS, damage), damDesc(self, DamageType.TEMPORAL, damage), nb)
end

-- Quantum Tunnelling

T_QUANTUM_TUNNELLING.no_energy = true
T_QUANTUM_TUNNELLING.action = function(self, t)
	local tg = self:getTalentTarget(t)
	local x, y = self:getTarget(tg)

	if not x or not y then return nil end
	if not self:hasLOS(x, y) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then
		game.logPlayer(self, "You do not have line of sight.")
		return nil
	end
	
	local target = game.level.map(x, y, engine.Map.TRAP)
	local _ _, x, y = self:canProject(tg, x, y)
	
	game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
	if not self:teleportRandom(x, y, 0) then
		game.logSeen(self, "%s's space-time folding fizzles!", self:getName():capitalize())
	else
		game.logSeen(self, "%s emerges from a space-time rift!", self:getName():capitalize())
		local absorb = self:spellCrit(t.getPower(self,t))

		self:setEffect(self.EFF_DAMAGE_SHIELD, t.getDuration(self, t), {color={0xe1/255, 0xcb/255, 0x3f/255}, image="quantum_tunelling_shield", power=absorb})
		
        --[[
		if target and target.void_rift then
			local trap = game.level.map(target.x, target.y, engine.Map.TRAP)
			if trap and trap.particles then game.level.map:removeParticleEmitter(trap.particles) end
			game.level.map:remove(target.x, target.y, engine.Map.TRAP)
			game.level:removeEntity(target, true)
		else
			local rift_t = self:getTalentFromId(self.T_REALITY_FRACTURE)
            rift_t.create_rift(self, rift_t)
            end
		end
            ]]
		
		game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
	end
	
	game:playSoundNear(self, "talents/teleport")
	return true
end

