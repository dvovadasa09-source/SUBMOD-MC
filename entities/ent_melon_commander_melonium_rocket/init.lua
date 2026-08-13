AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
  self:SetModel("models/props_phx/rocket1.mdl")
  self:SetMaterial("models/debug/debugwhite")

  self:PhysicsInit(SOLID_VPHYSICS)
  self:SetMoveType(MOVETYPE_NOCLIP)
  self:SetSolid(SOLID_VPHYSICS)

  local physObject = self:GetPhysicsObject()
  if physObject:IsValid() then
    physObject:Wake()
  end

  self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

  local height = 10000.0
  local skyOffset = Vector(0, 0, height)
  local impactOffset = Vector(0, 0, self:BoundingRadius() * 2)

  self.waypoints = util.Stack()
  self.waypoints:Push(self.target + impactOffset)
  self.waypoints:Push(self.target + skyOffset)
  self.waypoints:Push(self:GetPos() + skyOffset)

  self.removed = false
  self.imploded = false

  self.trailEntity = util.SpriteTrail(self, 0, color_white, false, 100, 30, 5, 1, "trails/smoke")
end

function ENT:Think()
  if self.removed then
    if IsValid(self) then
      self:Remove()
    end
    
    return
  end

  if self.dissolved and not self.playedDissolveSound then
    sound.Play("ambient/energy/whiteflash.wav", self:GetPos(), 110, 70, 1)
    self.playedDissolveSound = true
  end

  if self.imploded then return end

  if not MelonCommander.IsPlaying() then return end
  
  if self.currentTarget == nil and self.waypoints:Size() > 0 then
    self.currentTarget = self.waypoints:Pop()
  end
  
  if self.currentTarget == nil then 
    self:Implode(self.radius)
    return 
  end

  local didArrive = self:MoveTowards(self.currentTarget, self.speed)
  if didArrive then 
    self.currentTarget = nil
  end

  self:NextThink(CurTime() + 0.001)
end

function ENT:Implode(radius)
  self:PlayExplosionFX()

  self.imploded = true
  self:SetNoDraw(true)
  self:DetachTrail()

  local impactPos = self:GetPos()
  
  timer.Simple(2.3, function()
    if not IsValid(self) then return end
    self:Explode(impactPos, radius)
  end)
end

function ENT:Explode(pos, radius)
  local entsAround = ents.FindInSphere(pos, radius)
  
  for k, v in ipairs(entsAround) do
    if v == self then continue end
    if not MelonCommander.IsEntityUnit(v) then continue end

    v:TakeUnitDamage(self.damage, self.ownerUnit)
  end

  self.removed = true
end

function ENT:DetachTrail()
  local trailEntity = self.trailEntity
  if IsValid(trailEntity) then
    trailEntity:SetParent()
    trailEntity:SetPos(self:GetPos())
    timer.Simple(5.0, function()
      if not IsValid(trailEntity) then return end
      trailEntity:Remove()
    end)
  end
end

function ENT:PlayExplosionFX()
  local pos = self:GetPos()

  local explosionEffectName = MelonCommander.Utility.String.Decorate("explosion_nuke")
  local implosionEffectName = MelonCommander.Utility.String.Decorate("implode_nuke")

  local implosionEffectData = EffectData()
  implosionEffectData:SetStart(pos + Vector(0, 0, 300))

  util.Effect(implosionEffectName, implosionEffectData)

  timer.Simple(2.15, function()
    local explosionEffectData = EffectData()
    explosionEffectData:SetStart(pos)

    util.Effect(explosionEffectName, explosionEffectData)
  end)
end

function ENT:MoveTowards(position, speed)
  local selfPos = self:GetPos()
  
  local direction = position - selfPos
  direction:Normalize()

  local deltaTime = engine.TickInterval()

  local ang = direction:Angle()
  ang:RotateAroundAxis(ang:Right(), 270.0)
  
  local deltaTime = engine.TickInterval()
  ang = LerpAngle(15 * deltaTime, self:GetAngles(), ang)

  local forceDir = ang:Up()
  local speedMultiplier = 1 - (forceDir:Distance(direction))
  speedMultiplier = math.Clamp(speedMultiplier, 0.1, 1.0)

  local vel = forceDir * (speed * 5 * speedMultiplier) + (self:GetVelocity():GetNegated() * 0.2)

  self:SetVelocity(vel)
  self:SetAngles(ang)

  local distance = selfPos:Distance(position)
  return distance <= self:BoundingRadius()
end
