AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

include("sv_combat.lua")
include("sv_move.lua")

MelonCommander.SeeThroughUnits = MelonCommander.SeeThroughUnits or {}

function ENT:OnRemove()
  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate.OutpostRadius > 0 then
    MelonCommander.Outposts[self:EntIndex()] = nil
  end

  if self.removeCallbacks ~= nil then
    for k, v in ipairs(self.removeCallbacks) do
      v()
    end
  end

  self:CallComponents("SharedRemove")
  self:CallComponents("ServerRemove")
  
  if self.loopingSound ~= nil then
    self:StopLoopingSound(self.loopingSound)
  end

  self:UnmarkAsSeeThrough()
end

function ENT:Initialize()
  self:ServerUnitInitialize()
end

function ENT:ServerUnitInitialize()
  local curTime = CurTime()

  self.removeCallbacks = {}
  self.activeChecks = {}
  self.targetableChecks = {}

  self.lastThink = curTime

  local unitState = self:GetUnitState()
  if unitState == nil then
    print("Tried to create a MelonCommander unit entity without providing a unit state. Removing.")
    self:Remove()

    return
  end

  unitState.originalColor = self:GetColor()

  self:SetUnitIdentifier(unitState.UnitIdentifier)
  local unitIdentifier = self:GetUnitIdentifier()

  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate.OutpostRadius > 0 then
    MelonCommander.Outposts[self:EntIndex()] = self
  end

  self:SetUnitCreatedAt(curTime)
  self:SetUnitNextUse(curTime)

  unitState.buildFinishesAt = curTime
  unitState.buildTakesTime = false

  unitState.originalCollisionGroup = self:GetCollisionGroup()

  self:SetRallyPoint(nil)

  local additionalBuildDelay = unitState.queueBuildDelay or 0
  local buildTime = unitTemplate.BuildTime + additionalBuildDelay
  if unitState.instantBuild then
    buildTime = 0.0
  end

  if buildTime > 0 then
    unitState.buildFinishesAt = unitState.buildFinishesAt + buildTime
    unitState.buildTakesTime = true

    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
  end

  self:PutIntoGame()

  self:SetUnitBuildFinishesAt(unitState.buildFinishesAt)
  self:SetRenderMode(RENDERMODE_TRANSCOLOR)

  if unitTemplate.LoopSound ~= nil then
    self.loopingSound = self:StartLoopingSound(unitTemplate.LoopSound)
  end

  if self:HasFlag(MelonCommander.UnitFlags.Building) then
    self:SetNoCollideWithAllies(true)
  else
    self:SetNoCollideWithAllies(false)
  end

  self:SetCustomCollisionCheck(true)

  self:CallComponents("SharedInitialize")
  self:CallComponents("ServerInitialize")

  local physObj = self:GetPhysicsObject()
  if unitState.buildTakesTime then
    self:EnterBuildingState()
  end
end

function ENT:UpdateTransmitState()
  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate == nil then return TRANSMIT_PVS end

  if unitTemplate.NeverDormant then
    return TRANSMIT_ALWAYS
  end

  return TRANSMIT_PVS
end

function ENT:Use(activator, caller, useType, value)
  if not IsValid(activator) then return end
  if not activator:IsPlayer() then return end

  if not self:IsFinishedBuilding() then return end

  local curTime = CurTime()
  if curTime < self:GetUnitNextUse() then return end

  local unitOwner = self:GetUnitOwner()
  local userIdentifier = MelonCommander.GetPlayerIdentifierFromEngine(activator)

  if unitOwner ~= userIdentifier then return end

  self:CallComponents("SharedUse", { activator })
  self:CallComponents("ServerUse", { activator })
end

function ENT:Think()
  local thinkProfCall = MelonCommander.Utility.Profiling.Begin("Unit:Think")

  local curTime = CurTime()
  
  self.deltaThink = curTime - self.lastThink
  self.lastThink = curTime

  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate == nil then return end

  local physObj = self:GetPhysicsObject()

  local isInGame = self:IsInGame()
  if isInGame and self:GetNoDraw() then
    self:SetNoDraw(true)
  elseif not isInGame and not self:GetNoDraw() then
    self:SetNoDraw(false)
  end

  if not MelonCommander.IsPlaying() then
    if IsValid(physObj) and not physObj:IsAsleep() then
      physObj:EnableMotion(false)
      physObj:Sleep()
    end

    return 
  end

  if not self:IsFinishedBuilding() then
    return
  end

  if self:IsInBuildingState() then
    self:LeaveBuildingState()
  end

  if self:GetCollisionGroup() ~= unitState.originalCollisionGroup then
    self:SetCollisionGroup(unitState.originalCollisionGroup)
  end

  local thinkDelay = 1

  if self:HasWeapon() then
    thinkDelay = 0.3

    self:ThinkCombat()
  end

  if self:HasLocomotor() and not self:GetUnitIsTurret() then
    thinkDelay = 0.3
    
    self:ThinkMove()
  end

  if unitTemplate.ThinkDelay ~= nil then
    thinkDelay = unitTemplate.ThinkDelay
  end

  self:CallComponents("SharedThink")
  self:CallComponents("ServerThink")

  self:NextThink(curTime + thinkDelay)

  MelonCommander.Utility.Profiling.End("Unit:Think", thinkProfCall)
  return true
end

function ENT:IsInBuildingState()
  local unitState = self:GetUnitState()
  if unitState == nil then return false end

  return unitState.inBuildingState
end

function ENT:EnterBuildingState()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  unitState.inBuildingState = true

  self:MarkAsSeeThrough()

  local physObj = self:GetPhysicsObject()
  if not physObj:IsAsleep() then
    physObj:EnableMotion(false)
    physObj:Sleep()
  end
end

function ENT:LeaveBuildingState()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  unitState.inBuildingState = false

  self:UnmarkAsSeeThrough()

  local physObj = self:GetPhysicsObject()
  if physObj:IsAsleep() then
    physObj:EnableMotion(true)
    physObj:Wake()
  end
end

function ENT:MarkAsSeeThrough()
  MelonCommander.SeeThroughUnits[self:EntIndex()] = self
end

function ENT:UnmarkAsSeeThrough()
  MelonCommander.SeeThroughUnits[self:EntIndex()] = nil
end

function ENT:SetNoCollideWithAllies(shouldNoCollide)
  self.noCollideWithAllies = shouldNoCollide
end

function ENT:GetNoCollideWithAllies()
  return self.noCollideWithAllies
end

function ENT:UpdateOwnerColor()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate == nil then return end

  local owner = self:GetUnitOwner()
  local ownerPlayer = MelonCommander.Players[owner]

  local color
  if ownerPlayer == nil then
    color = color_white:Copy()
  else
    color = ownerPlayer.Color:Copy()
  end

  local additionalBrightness = unitTemplate.AdditionalBrightness or 0
  additionalBrightness = additionalBrightness + 1

  color = MelonCommander.Utility.Color.Brighten(color, 0.75)
  color = MelonCommander.Utility.Color.Brighten(color, additionalBrightness)
  
  self:SetColor(color)
  unitState.originalColor = color
end

function ENT:CanSee(position, optionalEntity, worldOnly)
  local filter = {
    self
  }

  table.Add(filter, MelonCommander.SeeThroughUnits)

  local start = self:GetPos()
  start = start + Vector(0, 0, self:BoundingRadius())

  local mask = nil
  if worldOnly then
    mask = MASK_PLAYERSOLID_BRUSHONLY
  end

  local tr = util.TraceLine({
    start = start,
    endpos = position,
    filter = filter,
    mask = mask
  })

  local hitEntity = tr.Entity

  if IsValid(hitEntity) then
    if hitEntity == game.GetWorld() then
      return false
    end

    if not worldOnly and IsValid(optionalEntity) then 
      return hitEntity == optionalEntity
    end
  end

  return tr.Fraction >= 0.98
end

function ENT:IsActive()
  local result = true

  for k, v in ipairs(self.activeChecks) do
    local checkResult = v()
    if not checkResult then 
      result = false 
      break 
    end
  end

  return result
end

function ENT:TakeOutOfGame()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  unitState.isInGame = false

  local physObj = self:GetPhysicsObject()
  if IsValid(physObj) and not physObj:IsAsleep() then
    physObj:EnableMotion(false)
    physObj:Sleep()
  end

  self:SetNoDraw(true)
end

function ENT:PutIntoGame()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  unitState.isInGame = true

  local physObj = self:GetPhysicsObject()
  if IsValid(physObj) and physObj:IsAsleep() then
    physObj:EnableMotion(true)
    physObj:Wake()
  end

  self:SetNoDraw(false)
end

function ENT:IsInGame()
  local unitState = self:GetUnitState()
  if unitState == nil then return false end

  return unitState.isInGame
end

function ENT:IsNearAlliedOutpost()
  local selfPos = self:GetPos()

  for k, v in pairs(MelonCommander.Outposts) do
    if not MelonCommander.IsEntityUnit(v) then continue end
    if not self:IsAlly(v) then continue end

    local vTemplate = v:GetUnitTemplate()
    if vTemplate == nil then continue end

    local distance = selfPos:Distance2D(v:GetPos())
    if distance < vTemplate.OutpostRadius then 
      return true 
    end
  end

  return false
end

function ENT:AddRemoveCallback(callback)
  if type(callback) ~= "function" then
    error("didn't pass a function to AddRemoveCallback")
    return 
  end

  table.insert(self.removeCallbacks, callback)
end

function ENT:AddActiveCheck(callback)
  if type(callback) ~= "function" then
    error("didn't pass a function to AddActiveCheck")
    return 
  end

  table.insert(self.activeChecks, callback)
end