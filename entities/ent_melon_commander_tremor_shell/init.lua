AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

ENT.ExplosionSounds = {
  "melon_commander/tremor_shell_exp_a.wav",
  "melon_commander/tremor_shell_exp_b.wav"
}

function ENT:OnRemove()
  if self.dissolved then return end

  local selfPos = self:GetPos()

  local effectName = MelonCommander.Utility.String.Decorate("earthquake")

  local effectData = EffectData()
  effectData:SetStart(selfPos)

  util.Effect(effectName, effectData)

  local selectedSound = MelonCommander.Utility.Table.Random(self.ExplosionSounds)
  sound.Play(selectedSound, selfPos, 120, 100, 1.0)
end

function ENT:Initialize()
  local owner = self:GetOwner()
  if not IsValid(owner) then 
    self:Remove()
    return 
    end

  local color = owner:GetColor()

  self:SetModel("models/props_phx/ww2bomb.mdl")
  self:SetColor(color)

  self:PhysicsInitSphere(50.0, SOLID_VPHYSICS)

  local physObj = self:GetPhysicsObject()
  if physObj:IsValid() then
    physObj:Wake()
  end

  physObj:EnableDrag(false)
  physObj:EnableCollisions(false)
  physObj:SetDamping(0.0, 0.0)
  
  self.ownerPlayerId = owner:GetUnitOwner()

  self.isBurrowed = false

  if self.targetPos == nil then
    self.targetPos = self:GetPos()
  end

  util.SpriteTrail(self, 0, color, false, 7, 4, 1, 1, "trails/smoke")
end

function ENT:DidArrive()
  local selfPos = self:GetPos()
  local targetPos = Vector(self.targetPos)

  local horizontalDistance = selfPos:Distance2D(targetPos)
  local verticalDifference = selfPos.z - targetPos.z

  return horizontalDistance <= 500.0 and verticalDifference <= 100.0
end

function ENT:Think()
  self:LookTowardsVelocity()

  if not self.isBurrowed and self:DidArrive() then
    local burrowPos = MelonCommander.Utility.Space.GetGroundPos(self.targetPos) + Vector(0, 0, 2)
    self:SetPos(burrowPos)
    self:Burrow()
  end
end

function ENT:Burrow()
  local physObj = self:GetPhysicsObject()
  if IsValid(physObj) then
    physObj:EnableMotion(false)
    physObj:EnableGravity(false)
    physObj:SetVelocity(Vector(0, 0, 0))
  end

  sound.Play("ambient/levels/outland/stalactitehit03.wav", self:GetPos(), 110, 100, 0.8)

  timer.Simple(1.5, function()
    if not IsValid(self) then return end
    if self.dissolved then return end

    sound.Play("ambient/levels/outland/ol09_gungrate_open.wav", self:GetPos(), 110, 100, 0.8)
  end)

  timer.Simple(3.0, function()
    if not IsValid(self) then return end
    if self.dissolved then return end

    local selfPos = self:GetPos()
    
    sound.Play("ambient/explosions/exp2.wav", selfPos, 110, 100, 0.7)
    util.ScreenShake(selfPos, 3000, 40, 0.5, 5000, true)
  end)

  timer.Simple(4.0, function()
    if not IsValid(self) then return end
    if self.dissolved then return end

    local selfPos = self:GetPos()
    util.ScreenShake(selfPos, 3000, 40, 0.5, 5000, true)

    self:Explode()
  end)

  self.isBurrowed = true
end

function ENT:Explode()
  local selfPos = self:GetPos()
  local radius = 400.0
  local entsAroundProjectile = ents.FindInSphere(selfPos, radius)

  local initialDamage = self.baseDamage or 35.0
  local buildingDamageMultiplier = 2.5
  local unitForce = 100

  local ownerUnit = self:GetOwner()
  
  for k, v in ipairs(entsAroundProjectile) do
    if v == self then continue end
    if not MelonCommander.IsEntityUnit(v) then continue end

    if self.ownerPlayerId == v:GetUnitOwner() then continue end
    local owner = self:GetOwner()
    if IsValid(owner) then
      if owner:IsAlly(v) then continue end
    end

    local shouldKnock = true
    local damage = initialDamage

    if v:HasOneOfFlags({
      MelonCommander.UnitFlags.Building,
      MelonCommander.UnitFlags.Prop, 
      MelonCommander.UnitFlags.Air,
      MelonCommander.UnitFlags.Hover
    }) then
      damage = damage * buildingDamageMultiplier
      shouldKnock = false
    end

    v:TakeUnitDamage(damage, ownerUnit)

    if not shouldKnock then continue end

    local physObj = v:GetPhysicsObject()
    if not IsValid(physObj) then continue end

    if not physObj:IsMotionEnabled() then
      physObj:EnableMotion(true)
    end

    local direction = v:WorldSpaceCenter() - self:GetPos()
    direction:Normalize()

    local force = direction * physObj:GetMass() * 39.37
    local vel = force * (unitForce / 4.0)

    vel.z = (unitForce * 6.0)
    physObj:ApplyForceCenter(vel)
  end

  self:Remove()
end

function ENT:LookTowardsVelocity()
  local physObj = self:GetPhysicsObject()
  if not IsValid(physObj) then return end

  local vel = physObj:GetVelocity()
  self:SetAngles(vel:GetNormalized():Angle())
  physObj:SetVelocity(vel)
end
