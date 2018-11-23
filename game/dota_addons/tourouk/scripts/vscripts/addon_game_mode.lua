-- This is the entry-point to your game mode and should be used primarily to precache models/particles/sounds/etc

require('internal/util')
require('gamemode')

function Precache( context )
	LinkLuaModifier("modifier_fountain_silence", "modifiers/modifier_fountain_silence.lua", LUA_MODIFIER_MOTION_NONE )
end

-- Create the game mode when we activate
function Activate()
	GameRules.GameMode = GameMode()
	GameRules.GameMode:_InitGameMode()
end