-- This file contains all barebones-registered events and has already set up the passed-in parameters for your use.

-- Cleanup a player when they leave
function GameMode:OnDisconnect(keys)
	local name = keys.name
	local networkid = keys.networkid
	local reason = keys.reason
	local userid = keys.userid
end

-- The overall game state has changed
function GameMode:OnGameRulesStateChange(keys)
	local newState = GameRules:State_Get()

	if newState == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		self:SetupFountains()
	elseif newState == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		for i = 0, PlayerResource:GetPlayerCount() - 1 do
			if PlayerResource:IsValidPlayer(i) and not PlayerResource:HasSelectedHero(i) and PlayerResource:GetConnectionState(i) == DOTA_CONNECTION_STATE_CONNECTED then
				PlayerResource:GetPlayer(i):MakeRandomHeroSelection()
				PlayerResource:SetCanRepick(i, false)
			end
		end
	elseif newState == DOTA_GAMERULES_STATE_PRE_GAME then
		if BOTS_ENABLED == true then
			SendToServerConsole('sm_gmode 1')
			SendToServerConsole('dota_bot_populate')
		end

		AddFOWViewer(2, Vector(0, 0, 0), 1800, 99999, false)
		AddFOWViewer(3, Vector(0, 0, 0), 1800, 99999, false)
	elseif newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:StartDuel()
	end
end

-- An NPC has spawned somewhere in game.  This includes heroes
function GameMode:OnNPCSpawned(keys)
	local npc = EntIndexToHScript(keys.entindex)

	if npc:IsRealHero() then
		if not npc.first_spawn then
			npc.first_spawn = true
			npc.is_in_arena = false
			npc:SetRespawnsDisabled(true)
		end
	end
end

-- An entity died
function GameMode:OnEntityKilled( keys )
	-- The Unit that was Killed
	local killedUnit = EntIndexToHScript( keys.entindex_killed )

	if IGNORE_DEATH[killedUnit:GetUnitName()] or not killedUnit:IsRealHero() then
		return
	end

	-- The Killing entity
	local killerEntity = nil

	if keys.entindex_attacker ~= nil then
		killerEntity = EntIndexToHScript( keys.entindex_attacker )
	end

	-- The ability/item used to kill, or nil if not killed by an item/ability
	local killerAbility = nil

	if keys.entindex_inflictor ~= nil then
		killerAbility = EntIndexToHScript( keys.entindex_inflictor )
	end

	local damagebits = keys.damagebits -- This might always be 0 and therefore useless

	if killedUnit:IsReincarnating() then
		killedUnit:SetRespawnsDisabled(false)
		return
	end

	-- Put code here to handle when an entity gets killed
	if self:TeamHasAliveHeroes(killedUnit:GetTeamNumber()) == "42" then
		-- ignore if a hero is still alive in arena, don't end yet!
	elseif self:TeamHasAliveHeroes(killedUnit:GetTeamNumber()) == true then
		GameMode:SpawnNextAvailableHero(killedUnit:GetTeamNumber(), HERO_LAUNCH_IN_DUEL_DELAY)
	else
		if killedUnit:GetTeamNumber() == 2 then
			CustomNetTables:SetTableValue("game_options", "update_score", {
				radiant = CustomNetTables:GetTableValue("game_options", "update_score").radiant,
				dire = CustomNetTables:GetTableValue("game_options", "update_score").dire + 1,
			})
	
			if CustomNetTables:GetTableValue("game_options", "update_score").dire >= DUELS_TO_WIN then
				GameRules:SetGameWinner(3)
				return
			end
		elseif killedUnit:GetTeamNumber() == 3 then
			CustomNetTables:SetTableValue("game_options", "update_score", {
				radiant = CustomNetTables:GetTableValue("game_options", "update_score").radiant + 1,
				dire = CustomNetTables:GetTableValue("game_options", "update_score").dire,
			})

			if CustomNetTables:GetTableValue("game_options", "update_score").radiant >= DUELS_TO_WIN then
				GameRules:SetGameWinner(2)
				return
			end
		end

		DUEL_COUNT = DUEL_COUNT + 1

		self:RefreshArena()
		self:AwardWinner(killedUnit:GetOpposingTeamNumber())

		Timers:CreateTimer(INVULNERABLE_TIME_DUEL_END, function()
			self:RefreshPlayers()
			self:StartDuel(30.0)
		end)
	end
end

function GameMode:StartDuel(iDelay)
	if iDelay then
		local i = iDelay
		Timers:CreateTimer(function()
			while i >= 1 do
				Notifications:TopToAll({text = "#duel_start_in", duration = 1.0, style = {["font-size"] = "50px", color = "White"} })
				Notifications:TopToAll({text = tostring(i), continue = true, duration = 1.0, style = {["font-size"] = "50px", color = "Red"} })
				i = i - 1
				return 1.0
			end

			self:LaunchDuel()

			return nil
		end)
	else
		self:LaunchDuel()
	end
end

function GameMode:LaunchDuel()
	GameMode:SpawnNextAvailableHero(2, HERO_LAUNCH_IN_DUEL_DELAY, HERO_COUNT_IN_DUEL)
	GameMode:SpawnNextAvailableHero(3, HERO_LAUNCH_IN_DUEL_DELAY, HERO_COUNT_IN_DUEL)
	Notifications:TopToAll({text = "DUEL!", duration = 3.0, style = {["font-size"] = "50px", color = "Red"} })
end

function GameMode:SpawnNextAvailableHero(team, iDelay, count)
	local spawn_point = "radiant_duel_spawnpoint"
	local counter = 0

	if count == nil then
		count = 1
	end

	if team == 3 then
		spawn_point = "dire_duel_spawnpoint"
	end

	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if hero:IsRealHero() then
			if hero:GetTeamNumber() == team and hero:IsAlive() and hero.is_in_arena == false then
				if iDelay and iDelay ~= 0 then
					local color = "green"
					if hero:GetTeamNumber() == 3 then
						color = "red"
					end

					Notifications:BottomToAll({hero = hero:GetUnitName(), duration = iDelay})
					Notifications:BottomToAll({text = PlayerResource:GetPlayerName(hero:GetPlayerID()).." ", duration = iDelay, continue = true})
					Notifications:BottomToAll({text = "#next_hero_in_duel", duration = iDelay, style = {color = color}, continue = true})

					GameMode:TeleportHeroInDuel(hero, spawn_point, iDelay)
				else
					GameMode:TeleportHeroInDuel(hero, spawn_point)
				end

				counter = counter + 1

				if counter >= count then
					return
				end
			end
		end
	end
end

function GameMode:TeleportHeroInDuel(hero, pos, iDelay)
	if iDelay == nil then iDelay = 0 end

	hero.is_in_arena = true

	Timers:CreateTimer(iDelay, function()
		FindClearSpaceForUnit(hero, Entities:FindByName(nil, pos):GetAbsOrigin(), true)
		PlayerResource:SetCameraTarget(hero:GetPlayerID(), hero)
		Timers:CreateTimer(0.1, function()
			PlayerResource:SetCameraTarget(hero:GetPlayerID(), nil)
		end)
	end)
end

function GameMode:TeamHasAliveHeroes(team)
	local alive_hero_in_arena = false

	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if hero:IsRealHero() then
			if hero:GetTeamNumber() == team then
				if hero:IsAlive() then
					if hero.is_in_arena == false then
						return true
					else
						alive_hero_in_arena = true
					end
				end
			end
		end
	end

	if alive_hero_in_arena == true then
		return "42"
	end

	return false
end

function GameMode:AwardWinner(team)
	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if hero:IsRealHero() then
--			if hero:GetTeamNumber() == team then
--				hero:ModifyGold(2000, true, 0)
--				hero:AddExperience(1500, DOTA_ModifyXP_CreepKill, false, true)
--			else
				hero:ModifyGold((DUEL_BONUS_GOLD * DUEL_COUNT) + DUEL_BASE_GOLD, true, 0)
				hero:AddExperience((DUEL_BONUS_XP * DUEL_COUNT) + DUEL_BASE_XP, DOTA_ModifyXP_CreepKill, false, true)
				hero:AddNewModifier(hero, nil, "modifier_command_restricted", {duration=INVULNERABLE_TIME_DUEL_END + 1.0})
--			end
		end
	end
end

function GameMode:RefreshArena()
	local enemies_to_clear = FindUnitsInRadius(2, Vector(0, 0, 0), nil, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD, FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies_to_clear) do
		if not enemy:IsRealHero() then
			if string.find(enemy:GetUnitName(), "trap") or string.find(enemy:GetUnitName(), "fountain") then
				print(enemy:GetUnitName())
			else
				print("killed:", enemy:GetUnitName())
				enemy:ForceKill(false)
			end
		end
	end
end

function GameMode:RefreshPlayers()
	for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:HasSelectedHero( nPlayerID ) then
			local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )

			if hero:IsAlive() then
				hero:SetHealth( hero:GetMaxHealth() )
				hero:SetMana( hero:GetMaxMana() )
				if hero:GetTeamNumber() == 2 then
					GameMode:TeleportHeroInDuel(hero, "radiant_base")
				elseif hero:GetTeamNumber() == 3 then
					GameMode:TeleportHeroInDuel(hero, "dire_base")
				end
			else
				hero:RespawnHero(false, false)
			end

			ProjectileManager:ProjectileDodge(hero)
			hero:Purge(false, true, false, true, true)
			hero:Stop()
			hero.is_in_arena = false
		end
	end
end

-- An item was picked up off the ground
function GameMode:OnItemPickedUp(keys)
	local unitEntity = nil
	if keys.UnitEntitIndex then
		unitEntity = EntIndexToHScript(keys.UnitEntitIndex)
	elseif keys.HeroEntityIndex then
		unitEntity = EntIndexToHScript(keys.HeroEntityIndex)
	end

	local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local itemname = keys.itemname
end

-- A player has reconnected to the game.  This function can be used to repaint Player-based particles or change
-- state as necessary
function GameMode:OnPlayerReconnect(keys)
end

-- An item was purchased by a player
function GameMode:OnItemPurchased( keys )
	-- The playerID of the hero who is buying something
	local plyID = keys.PlayerID
	if not plyID then return end

	-- The name of the item purchased
	local itemName = keys.itemname 
	
	-- The cost of the item purchased
	local itemcost = keys.itemcost
	
end

-- An ability was used by a player
function GameMode:OnAbilityUsed(keys)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local abilityname = keys.abilityname
end

-- A non-player entity (necro-book, chen creep, etc) used an ability
function GameMode:OnNonPlayerUsedAbility(keys)
	local abilityname = keys.abilityname
end

-- A player changed their name
function GameMode:OnPlayerChangedName(keys)
	local newName = keys.newname
	local oldName = keys.oldName
end

-- A player leveled up an ability
function GameMode:OnPlayerLearnedAbility( keys)
	local player = EntIndexToHScript(keys.player)
	local abilityname = keys.abilityname
end

-- A channelled ability finished by either completing or being interrupted
function GameMode:OnAbilityChannelFinished(keys)
	local abilityname = keys.abilityname
	local interrupted = keys.interrupted == 1
end

-- A player leveled up
function GameMode:OnPlayerLevelUp(keys)
	local player = EntIndexToHScript(keys.player)
	local level = keys.level
end

-- A player last hit a creep, a tower, or a hero
function GameMode:OnLastHit(keys)
	local isFirstBlood = keys.FirstBlood == 1
	local isHeroKill = keys.HeroKill == 1
	local isTowerKill = keys.TowerKill == 1
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local killedEnt = EntIndexToHScript(keys.EntKilled)
end

-- A tree was cut down by tango, quelling blade, etc
function GameMode:OnTreeCut(keys)
	local treeX = keys.tree_x
	local treeY = keys.tree_y
end

-- A rune was activated by a player
function GameMode:OnRuneActivated (keys)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local rune = keys.rune

	--[[ Rune Can be one of the following types
	DOTA_RUNE_DOUBLEDAMAGE
	DOTA_RUNE_HASTE
	DOTA_RUNE_HAUNTED
	DOTA_RUNE_ILLUSION
	DOTA_RUNE_INVISIBILITY
	DOTA_RUNE_BOUNTY
	DOTA_RUNE_MYSTERY
	DOTA_RUNE_RAPIER
	DOTA_RUNE_REGENERATION
	DOTA_RUNE_SPOOKY
	DOTA_RUNE_TURBO
	]]
end

-- A player took damage from a tower
function GameMode:OnPlayerTakeTowerDamage(keys)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local damage = keys.damage
end

-- A player picked a hero
function GameMode:OnPlayerPickHero(keys)
	local heroClass = keys.hero
	local heroEntity = EntIndexToHScript(keys.heroindex)
	local player = EntIndexToHScript(keys.player)
end

-- A player killed another player in a multi-team context
function GameMode:OnTeamKillCredit(keys)
	local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
	local victimPlayer = PlayerResource:GetPlayer(keys.victim_userid)
	local numKills = keys.herokills
	local killerTeamNumber = keys.teamnumber
end

-- This function is called 1 to 2 times as the player connects initially but before they 
-- have completely connected
function GameMode:PlayerConnect(keys)
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:OnConnectFull(keys)
	local entIndex = keys.index+1
	-- The Player entity of the joining user
	local ply = EntIndexToHScript(entIndex)
	
	-- The Player ID of the joining player
	local playerID = ply:GetPlayerID()
end

-- This function is called whenever illusions are created and tells you which was/is the original entity
function GameMode:OnIllusionsCreated(keys)
	local originalEntity = EntIndexToHScript(keys.original_entindex)
end

-- This function is called whenever an item is combined to create a new item
function GameMode:OnItemCombined(keys)
	-- The playerID of the hero who is buying something
	local plyID = keys.PlayerID
	if not plyID then return end
	local player = PlayerResource:GetPlayer(plyID)

	-- The name of the item purchased
	local itemName = keys.itemname 
	
	-- The cost of the item purchased
	local itemcost = keys.itemcost
end

-- This function is called whenever an ability begins its PhaseStart phase (but before it is actually cast)
function GameMode:OnAbilityCastBegins(keys)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local abilityName = keys.abilityname
end

-- This function is called whenever a tower is killed
function GameMode:OnTowerKill(keys)
	local gold = keys.gold
	local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
	local team = keys.teamnumber
end

-- This function is called whenever a player changes there custom team selection during Game Setup 
function GameMode:OnPlayerSelectedCustomTeam(keys)
	local player = PlayerResource:GetPlayer(keys.player_id)
	local success = (keys.success == 1)
	local team = keys.team_id
end

-- This function is called whenever an NPC reaches its goal position/target
function GameMode:OnNPCGoalReached(keys)
	local goalEntity = EntIndexToHScript(keys.goal_entindex)
	local nextGoalEntity = EntIndexToHScript(keys.next_goal_entindex)
	local npc = EntIndexToHScript(keys.npc_entindex)
end

-- This function is called whenever any player sends a chat message to team or All
function GameMode:OnPlayerChat(keys)
	local teamonly = keys.teamonly
	local userID = keys.userid
	local playerID = self.vUserIds[userID]:GetPlayerID()

	local text = keys.text
end

-- Set up fountain regen
function GameMode:SetupFountains()
	local fountainEntities = Entities:FindAllByClassname("ent_dota_fountain")

	for _,fountainEnt in pairs( fountainEntities ) do
		fountainEnt:AddNewModifier(fountainEnt, fountainEnt, "modifier_fountain_silence", {})
	end
end
