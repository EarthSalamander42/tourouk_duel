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

	if newState == DOTA_GAMERULES_STATE_STRATEGY_TIME then
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

		AddFOWViewer(2, Vector(0, 0, 0), 3000, 99999, false)
		AddFOWViewer(3, Vector(0, 0, 0), 3000, 99999, false)
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

			if npc:GetTeamNumber() == 2 then
				RADIANT_HEROES_COUNT = RADIANT_HEROES_COUNT + 1
				RADIANT_HEROES[RADIANT_HEROES_COUNT] = npc
			elseif npc:GetTeamNumber() == 3 then
				DIRE_HEROES_COUNT = DIRE_HEROES_COUNT + 1
				DIRE_HEROES[DIRE_HEROES_COUNT] = npc
			end

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
	if self:TeamHasAliveHeroes(killedUnit:GetTeamNumber()) then
		GameMode:SpawnNextAvailableHero(killedUnit:GetTeamNumber(), 3.0)
	else
		-- TODO: set everyone invulnerable to prevent draw
		if killedUnit:GetTeamNumber() == 2 then
			CustomNetTables:SetTableValue("game_options", "update_score", {
				radiant = CustomNetTables:GetTableValue("game_options", "update_score").radiant,
				dire = CustomNetTables:GetTableValue("game_options", "update_score").dire + 1,
			})
	
			if CustomNetTables:GetTableValue("game_options", "update_score").dire >= 5 then
				GameRules:SetGameWinner(3)
				return
			end
		elseif killedUnit:GetTeamNumber() == 3 then
			CustomNetTables:SetTableValue("game_options", "update_score", {
				radiant = CustomNetTables:GetTableValue("game_options", "update_score").radiant + 1,
				dire = CustomNetTables:GetTableValue("game_options", "update_score").dire,
			})

			if CustomNetTables:GetTableValue("game_options", "update_score").radiant >= 5 then
				GameRules:SetGameWinner(2)
				return
			end
		end

		self:AwardWinner(killedUnit:GetOpposingTeamNumber())
		self:RefreshPlayers()

		self:StartDuel(30.0)
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

			GameMode:SpawnNextAvailableHero(2)
			GameMode:SpawnNextAvailableHero(3)
			Notifications:TopToAll({text = "DUEL!", duration = 3.0, style = {["font-size"] = "50px", color = "Red"} })

			return nil
		end)
	else
		GameMode:SpawnNextAvailableHero(2)
		GameMode:SpawnNextAvailableHero(3)
		Notifications:TopToAll({text = "DUEL!", duration = 3.0, style = {["font-size"] = "50px", color = "Red"} })
	end
end

function GameMode:SpawnNextAvailableHero(team, iDelay)
	local hero_table = RADIANT_HEROES
	local spawn_point = "radiant_duel_spawnpoint"

	if team == 3 then
		hero_table = DIRE_HEROES
		spawn_point = "dire_duel_spawnpoint"
	end

	for i = 1, PlayerResource:GetPlayerCountForTeam(team) do
		if hero_table[i]:IsAlive() then
			if iDelay then
				Notifications:BottomToAll({hero = hero_table[i]:GetUnitName(), duration = iDelay})
				Notifications:BottomToAll({text = PlayerResource:GetPlayerName(hero_table[i]:GetPlayerID()).." ", duration = iDelay, continue = true})
				Notifications:BottomToAll({text = "#next_hero_in_duel", duration = iDelay, style = {color = "DodgerBlue"}, continue = true})

				GameMode:TeleportHero(hero_table[i], spawn_point, iDelay)
			else
				GameMode:TeleportHero(hero_table[i], spawn_point)
			end

			return
		end
	end

	return false
end

function GameMode:TeleportHero(hero, pos, iDelay)
	if iDelay == nil then iDelay = 0 end

	Timers:CreateTimer(iDelay, function()
		FindClearSpaceForUnit(hero, Entities:FindByName(nil, pos):GetAbsOrigin(), true)
		PlayerResource:SetCameraTarget(hero:GetPlayerID(), hero)
		Timers:CreateTimer(0.1, function()
			PlayerResource:SetCameraTarget(hero:GetPlayerID(), nil)
		end)
	end)
end

function GameMode:TeamHasAliveHeroes(team)
	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if hero:GetTeamNumber() == team then
			if hero:IsAlive() then
				return true
			end
		end
	end

	return false
end

function GameMode:AwardWinner(team)
	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if hero:GetTeamNumber() == team then
			hero:ModifyGold(2000, true, 0)
			hero:AddExperience(1500, DOTA_ModifyXP_CreepKill, false, true)
		else
			hero:ModifyGold(1750, true, 0)
			hero:AddExperience(1000, DOTA_ModifyXP_CreepKill, false, true)
		end
	end
end

function GameMode:RefreshPlayers()
	Timers:CreateTimer(0.1, function()
		for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
			if PlayerResource:HasSelectedHero( nPlayerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
				if hero:IsAlive() then
					hero:SetHealth( hero:GetMaxHealth() )
					hero:SetMana( hero:GetMaxMana() )
					if hero:GetTeamNumber() == 2 then
						GameMode:TeleportHero(hero, "radiant_base")
					elseif hero:GetTeamNumber() == 3 then
						GameMode:TeleportHero(hero, "dire_base")
					end
				else
					hero:RespawnHero(false, false)
				end

				ProjectileManager:ProjectileDodge(hero)
				hero:Purge(false, true, false, true, true)
			end
		end
	end)
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