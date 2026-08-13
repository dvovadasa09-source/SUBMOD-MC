AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
  self:SetNoDraw(true)

  local selfPos = self:GetPos()

  local dieDelay = self.dieDelay or 6.0
  
  local gasEffectName = MelonCommander.Utility.String.Decorate("gas_cloud")

  local gasEffectData = EffectData()
  gasEffectData:SetStart(selfPos)
  gasEffectData:SetScale(dieDelay)

  util.Effect(gasEffectName, gasEffectData)

  self.removeTime = CurTime() + dieDelay
  self.gasSoundID = self:StartLoopingSound("ambient/gas/steam2.wav")
end

function ENT:OnRemove()
  self:StopLoopingSound(self.gasSoundID)
end

function ENT:Think()
  if CurTime() >= self.removeTime then
    self:Remove()
    return
  end

  self:DamageUnitsAround()
  self:NextThink(CurTime() + 0.9)
end

function ENT:DamageUnitsAround()
  local radius = self.radius or 100.0
  local damage = self.damage or 5.0

  local entsAround = ents.FindInSphere(self:GetPos(), radius)
  for k, v in ipairs(entsAround) do
    if not MelonCommander.IsEntityUnit(v) then continue end
    if not v:IsInGame() then continue end

    if MelonCommander.IsEntityUnit(self.ownerUnit) and v:GetUnitOwner() == self.ownerUnit:GetUnitOwner() then continue end

    if v:HasOneOfFlags({
      MelonCommander.UnitFlags.Prop,
      MelonCommander.UnitFlags.Building,
    }) then continue end

    v:TakeUnitDamage(damage, self.ownerUnit)
  end
end