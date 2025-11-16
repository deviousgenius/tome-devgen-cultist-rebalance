local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc
local Trap = require "mod.class.Trap"

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

T_REALITY_FRACTURE.create_rift = function(self, t, targetX, targetY)
		if not self.in_combat then return end

		local rift = rng.range(1,3)

		local x, y 

		if( targetX and targetY ) then
			x, y = targetX, targetY
		else
			x, y = self.x, self.y
			local range = t.getSpawnRadius(self, t)
			local poss = {}
			
			for i = x - range, x + range do
				for j = y - range, y + range do
					if game.level.map:isBound(i, j) and
						core.fov.distance(x, y, i, j) <= range and
						--core.fov.distance(x, y, i, j) >= range/2 and
						self:canMove(i, j) and 
						self:hasLOS(i, j) and not game.level.map(i, j, engine.Map.TRAP) then
						poss[#poss+1] = {i,j}
					end
				end
			end
			if #poss == 0 then return x, y  end
			local pos = poss[rng.range(1, #poss)]
			x, y = pos[1], pos[2]
		end
		
		game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "rift_alert", {tx=x-self.x, ty=y-self.y}, {time_factor=0.1, type="lightning"})
		if self:knowTalent(self.T_PIERCE_THE_VEIL) and rng.percent(self:callTalent(self.T_PIERCE_THE_VEIL, "getChance")) and rift then
			local t2 = self:getTalentFromId(self.T_PIERCE_THE_VEIL)
			if rift == 1 then
				t2.nether_breach(self, t2, x, y)
			elseif rift == 2 then 
				t2.temporal_vortex(self, t2, x, y)
			elseif rift == 3 then 
				t2.dimensional_gateway(self, t2, x, y)
			end
		else
			local e = Trap.new{
				triggered = function(self, x, y, who) return true, true end,
				disarmable = false,
				energy = {value=0},
				canTrigger = function() return false end,
				type = "rift", name = _t"void rift",
				name = _t"void rift", image = "terrain/entropic/void_rift.png",
				add_mos = {image = "terrain/entropic/void_rift.png"},
				display = '&', color=colors.LIGHT_RED, back_color=colors.RED,
				always_remember = true,
				temporary = t.getDuration(self, t),
				x = x, y = y,
				canAct = false,
				void_rift = true,
				all_know = true,
				dam = self:spellCrit(t.getDamage(self, t)),
				mult = t.getMult(self,t)/100,
				empower = false,
				act = function(self)
					local tgts = {}
					local grids = core.fov.circle_grids(self.x, self.y, 10, true)
					for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
						local a = game.level.map(x, y, engine.Map.ACTOR)
						if a and self.summoner:reactionToward(a) < 0 then tgts[#tgts+1] = a end
					end end
	        
					-- Randomly take targets
					if self.empower then
						local tg = {type="ball", speed=5, range=10, radius=1, x=self.x, y=self.y, talent=self.summoner:getTalentFromId(self.summoner.T_REALITY_FRACTURE), friendlyblock=false, friendlyfire=false, display={particle="bolt_void"}}
						if #tgts >= 0 then
							local a, id = rng.table(tgts)
							table.remove(tgts, id)
							if a then
								self.summoner:projectile(tg, a.x, a.y, engine.DamageType.VOID, self.dam + (self.dam * self.mult), {type="voidblast"})
								game:playSoundNear(self, "talents/fire")
							end 
						end
					else
						local tg = {type="bolt", speed=5, range=10, x=self.x, y=self.y, talent=self.summoner:getTalentFromId(self.summoner.T_REALITY_FRACTURE), friendlyblock=false, friendlyfire=false, display={particle="bolt_void"}}
						if #tgts >= 0 then
							local a, id = rng.table(tgts)
							table.remove(tgts, id)
							if a then
								self.summoner:projectile(tg, a.x, a.y, engine.DamageType.VOID, self.dam, {type="voidblast"})
								game:playSoundNear(self, "talents/fire")
							end 
						end
					end
					self:useEnergy()
					self.temporary = self.temporary - 1
					if self.temporary < 0 then
						if game.level.map(self.x, self.y, engine.Map.TRAP) == self then game.level.map:remove(self.x, self.y, engine.Map.TRAP) end
						game.level:removeEntity(self)
					end
				end,
				summoner_gain_exp = true,
				summoner = self,
			}

			e:identify(true)
			e:resolve() e:resolve(nil, true)
			e:setKnown(self, true)

			game.level:addEntity(e)
			game.level.map(x, y, Map.TRAP, e)
		end
		game:playSoundNear(self, "talents/fire")
		return true
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
		
		if target and target.void_rift then
			local trap = game.level.map(target.x, target.y, engine.Map.TRAP)
			if trap and trap.particles then game.level.map:removeParticleEmitter(trap.particles) end
			game.level.map:remove(target.x, target.y, engine.Map.TRAP)
			game.level:removeEntity(target, true)

			local rift_t = self:getTalentFromId(self.T_REALITY_FRACTURE)

			rift_t.create_rift(self, rift_t)
			rift_t.create_rift(self, rift_t)
			rift_t.create_rift(self, rift_t)
		else
			local rift_t = self:getTalentFromId(self.T_REALITY_FRACTURE)
            rift_t.create_rift(self, rift_t, self.x, self.y)
		end
		
		game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
	end
	
	game:playSoundNear(self, "talents/teleport")
	return true
end

T_QUANTUM_TUNNELLING.info = function(self, t)
		local range = self:getTalentRange(t)
		local duration = self:getShieldDuration(t.getDuration(self, t))
		local power = self:getShieldAmount(t.getPower(self, t))
		return ([[You briefly open a tunnel through spacetime, teleporting in range %d and granting you a shield for %d turns absorbing %d damage.

If you teleport into a void rift, it is destroyed and three new void rifts are created near your original location.

If you teleport without entering a void rift, a new void rift is created at your original location.

The damage absorbed will scale with your Spellpower.]]):
		tformat(range, duration, power)
	end
