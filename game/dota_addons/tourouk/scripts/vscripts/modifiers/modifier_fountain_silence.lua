LinkLuaModifier("modifier_fountain_silence_debuff", "modifiers/modifier_fountain_silence.lua", LUA_MODIFIER_MOTION_NONE )

modifier_fountain_silence = class({})

function modifier_fountain_silence:IsHidden() return true end
function modifier_fountain_silence:IsAura() return true end

function modifier_fountain_silence:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_fountain_silence:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP + DOTA_UNIT_TARGET_COURIER
end

function modifier_fountain_silence:GetModifierAura()
	return "modifier_fountain_silence_debuff"
end

function modifier_fountain_silence:GetAuraDuration()
	return FrameTime()
end

function modifier_fountain_silence:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_INVULNERABLE
end

function modifier_fountain_silence:GetAuraRadius()
	return 1200
end

modifier_fountain_silence_debuff = class({})

function modifier_fountain_silence_debuff:IsPurgable() return false end
function modifier_fountain_silence_debuff:IsPurgeException() return false end

function modifier_fountain_silence_debuff:GetTexture()
	return "silencer_global_silence"
end

function modifier_fountain_silence_debuff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
		MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE,
	}

	return funcs
end

function modifier_fountain_silence_debuff:GetTexture()
	return "rune_regen"
end

function modifier_fountain_silence_debuff:CheckState()
	local state = {
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_MUTED] = true,
		[MODIFIER_STATE_SILENCED] = true,
	}

	return state
end
