-- credits to yahnich for the following
function CDOTA_BaseNPC:IsFakeHero()
	if self:IsIllusion() or (self:HasModifier("modifier_monkey_king_fur_army_soldier") or self:HasModifier("modifier_monkey_king_fur_army_soldier_hidden")) or self:IsTempestDouble() or self:IsClone() then
		return true
	else return false end
end

function CDOTA_BaseNPC:IsRealHero()
	if not self:IsNull() then
		return self:IsHero() and not ( self:IsIllusion() or self:IsClone() ) and not self:IsFakeHero()
	end
end

function CDOTA_BaseNPC:Blink(position, bTeamOnlyParticle, bPlaySound)
	if self:IsNull() then return end
	local blink_effect = "particles/items_fx/blink_dagger_start.vpcf"
	local blink_end_effect = "particles/items_fx/blink_dagger_end.vpcf"
	if self.blink_effect or self:GetPlayerOwner().blink_effect then blink_effect = self.blink_effect end
	if self.blink_end_effect or self:GetPlayerOwner().blink_end_effect then blink_end_effect = self.blink_end_effect end
	if bPlaySound == true then EmitSoundOn("DOTA_Item.BlinkDagger.Activate", self) end
	if bTeamOnlyParticle == true then
		local blink_pfx = ParticleManager:CreateParticleForTeam(blink_effect, PATTACH_ABSORIGIN, companion, companion:GetTeamNumber())
		ParticleManager:ReleaseParticleIndex(blink_pfx)
	else
		ParticleManager:FireParticle(blink_effect, PATTACH_ABSORIGIN, self, {[0] = self:GetAbsOrigin()})
	end
	FindClearSpaceForUnit(self, position, true)
	ProjectileManager:ProjectileDodge( self )
	if bTeamOnlyParticle == true then
		local blink_end_pfx = ParticleManager:CreateParticleForTeam(blink_end_effect, PATTACH_ABSORIGIN, companion, companion:GetTeamNumber())
		ParticleManager:ReleaseParticleIndex(blink_end_pfx)
	else
		ParticleManager:FireParticle(blink_end_effect, PATTACH_ABSORIGIN, self, {[0] = self:GetAbsOrigin()})
	end
	if bPlaySound == true then EmitSoundOn("DOTA_Item.BlinkDagger.NailedIt", self) end
end
