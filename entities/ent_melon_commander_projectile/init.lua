AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:PlayImpactFX()
  local effect = self.weaponTemplate.ImpactEffect
  if effect == nil then return end
  
  local effectData = EffectData()
  effectData:SetStart(self:GetPos())

  util.Effect(effect, effectData)
end

function ENT:Initialize()
  local collisionRadius = self.weaponTemplate.ProjectileCollisionRadius
  if collisionRadius == nil then
    collisionRadius = 50.0 * self.weaponTemplate.ProjectileScale
  end

  self:PhysicsInitSphere(collisionRadius, SOLID_VPHYSICS)

  local physObject = self:GetPhysicsObject()
  if physObject:IsValid() then
    physObject:Wake()
  end

  physObject:EnableDrag(false)
  
  if self.weaponTemplate.Homing then
    physObject:EnableGravity(false)
  end

  physObject:SetDamping(0.0, 0.0)

  if self.weaponTemplate.QuickNoCollide then
    physObject:EnableCollisions(false)
    timer.Simple(0.5, function()
      if IsValid(physObject) then
        physObject:EnableCollisions(true)
      end
    end)
  end

  self:SetModelScale(self.weaponTemplate.ProjectileScale)
  
  self.ownerPlayerId = self:GetOwner():GetUnitOwner()

  if self.weaponTemplate.ProjectileTrail ~= "" then
    self.trailEntity = util.SpriteTrail(self, 0, color_white, false, 7, 4, 1, 1, self.weaponTemplate.ProjectileTrail)
  end
end

function ENT:Think()
  if self.removed then
    if IsValid(self) then
      self:Remove()
    end

    return
  end
  
  local target = self.target

  local isHoming = self.weaponTemplate.Homing
  if isHoming and not IsValid(target) then
    self:Explode()
    return
  end

  if isHoming then
    self:MoveTowardsTarget()
  else
    self:LookTowardsVelocity()
  end

  if not IsValid(target) then return end

  local targetCenter = self.target:WorldSpaceCenter()
  local distanceToTarget = self:GetPos():Distance(targetCenter)
  if distanceToTarget <= (self.weaponTemplate.Radius * 0.5) then
    self:Explode()
    return
  end
end

function ENT:PhysicsCollide(data, collider)
  if self.removed then return end

  local touchedEnt = data.HitEntity
  if touchedEnt == self then return end

  if touchedEnt:IsWorld() then
    self:Explode()
    return
  end

  if not MelonCommander.IsEntityUnit(touchedEnt) then return end
  if touchedEnt == self.ownerUnit then return end

  if IsValid(self.ownerUnit) then
    if touchedEnt:IsAlly(self.ownerUnit) then return end
  end

  self:Explode()
end

function ENT:Explode()
  local selfPos = self:GetPos()
  local radius = self.weaponTemplate.Radius
  local entsAroundProjectile = ents.FindInSphere(selfPos, radius)

  local originalDamage = self.weaponTemplate.Damage
  
  for k, v in ipairs(entsAroundProjectile) do
    if v == self then continue end
    if not MelonCommander.IsEntityUnit(v) then continue end
    if v:IsAlly(self.ownerUnit) then continue end

    if self.ownerPlayerId == v:GetUnitOwner() then continue end

    local distanceToEpicenter = v:WorldSpaceCenter():Distance(selfPos)
    local damageRatio = 1 - (distanceToEpicenter / radius)
    damageRatio = math.Clamp(damageRatio, 0.5, 1.0)

    local newDamage = originalDamage * damageRatio
    local damageDelta = originalDamage - newDamage
    damageDelta = damageDelta * self.weaponTemplate.RadiusFalloffFactor

    local totalDamage = originalDamage - damageDelta
    v:TakeUnitDamage(totalDamage, self.ownerUnit)
  end

  local entToCreate = self.weaponTemplate.CreateEntityAtImpact
  if entToCreate ~= nil then
    local childEnt = ents.Create(entToCreate)
    if IsValid(childEnt) then
      childEnt:SetPos(selfPos)
      
      childEnt:SetOwner(self.ownerUnit)
      childEnt.ownerUnit = self.ownerUnit

      childEnt:Spawn()
    end
  end

  local trailEntity = self.trailEntity

  if IsValid(trailEntity) then
    trailEntity:SetParent()
    trailEntity:SetPos(self:GetPos())
    timer.Simple(5.0, function()
      if not IsValid(trailEntity) then return end
      trailEntity:Remove()
    end)
  end

  self:PlayImpactFX()
  self:MarkRemoved()
end

function ENT:MarkRemoved()
  self.removed = true

  self:SetNoDraw(true)

  local physObj = self:GetPhysicsObject()
  if not IsValid(physObj) then return end

  physObj:Sleep(true)
  physObj:EnableMotion(false)
end

function ENT:LookTowardsVelocity()
  local physObject = self:GetPhysicsObject()
  if not IsValid(physObject) then return end

  local vel = physObject:GetVelocity()
  self:SetAngles(vel:GetNormalized():Angle())
  physObject:SetVelocity(vel)
end

function ENT:MoveTowardsTarget()
  local physObject = self:GetPhysicsObject()
  if not IsValid(physObject) then return end

  local speed = self.weaponTemplate.ProjectileSpeed

  local targetCenter = self.target:WorldSpaceCenter()
  local direction = targetCenter - self:GetPos()
  direction:Normalize()

  local force = direction * physObject:GetMass() * 39.37
  local vel = force * speed

  physObject:ApplyForceCenter(vel)

  local backupVelocity = self:GetVelocity()
  self:SetAngles(direction:Angle())
  self:SetVelocity(backupVelocity)
end