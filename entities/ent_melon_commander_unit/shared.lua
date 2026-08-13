ENT.PrintName = "Melon unit"
ENT.Category = "Melon Commander"
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Author = "toph"
ENT.Contact = "STEAM_0:1:410285675"

ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:SetupDataTables()
  self:NetworkVar("Bool", "UnitIsTurret")
  
  self:NetworkVar("String", "UnitIdentifier")
  self:NetworkVar("String", "UnitOwner")

  self:NetworkVar("Vector", "UnitGoal")

  self:NetworkVar("Entity", "UnitTarget")

  self:NetworkVar("Float", "UnitCreatedAt")
  self:NetworkVar("Float", "UnitBuildFinishesAt")
  self:NetworkVar("Float", "UnitNextUse")

  -- Define component netvars
  for k, v in pairs(MelonCommander.Components) do
    if v.Netvars == nil then continue end

    for i, n in ipairs(v.Netvars) do
      self:NetworkVar(n.Type, n.Name)
    end
  end

  if SERVER then
    self:NetworkVarNotify("UnitOwner", function(ent, name, old, new)
      self:CallComponents("OnOwnerChanged", { old, new })
    end)
  end
end

function ENT:GetUnitState()
  return self.MelonCommanderUnitState
end

function ENT:GetUnitTemplate()
  local unitState = self:GetUnitState()
  if unitState == nil then return nil end

  return unitState.UnitTemplate
end

function ENT:GetWeaponTemplate()
  local unitState = self:GetUnitState()
  if unitState == nil then return nil end

  return unitState.WeaponTemplate
end

function ENT:GetLocomotorTemplate()
  local unitState = self:GetUnitState()
  if unitState == nil then return nil end

  return unitState.LocomotorTemplate
end

function ENT:GetWeaponState()
  local unitState = self:GetUnitState()
  if unitState == nil then return nil end

  return unitState.WeaponState
end

function ENT:GetComponentState(componentIdentifier)
  local unitState = self:GetUnitState()
  if unitState == nil then return end
  
  local unitTemplate = self:GetUnitTemplate()
  
  for k, v in ipairs(unitTemplate.Components) do
    local componentState = unitState.ComponentStates[k]
    if componentState == nil then
      error("component "..k.." has no initialized state")
      return
    end

    if v.Identifier ~= componentIdentifier then
      continue
    end

    return componentState
  end
end

function ENT:CallComponents(methodName, args)
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local unitTemplate = self:GetUnitTemplate()

  local profSectionName
  local componentProfCall
  if MelonCommander.Utility.Profiling.Enabled then
    profSectionName = "Unit:Components:"..methodName
    componentProfCall = MelonCommander.Utility.Profiling.Begin(profSectionName)
  end

  for k, v in ipairs(unitTemplate.Components) do
    local componentState = unitState.ComponentStates[k]
    if componentState == nil then
      error("component "..k.." has no initialized state")
      return
    end

    local componentMethod = v.Instance[methodName]
    if componentMethod == nil then
      continue
    end

    componentMethod(self, componentState, unpack(args or {}))
  end

  MelonCommander.Utility.Profiling.End(profSectionName, componentProfCall)
end

function ENT:IsFinishedBuilding()
  return CurTime() >= self:GetUnitBuildFinishesAt()
end

function ENT:GetBelongingAlliance()
  local unitOwner = self:GetUnitOwner()
  if unitOwner == "" then return MelonCommander.NoAlliance end

  local playerOwner = MelonCommander.Players[unitOwner]
  if playerOwner == nil then return MelonCommander.NoAlliance end

  return playerOwner.Alliance
end

function ENT:IsAlly(otherUnit)
  if not MelonCommander.IsEntityUnit(otherUnit) then return false end
  if otherUnit:GetUnitOwner() == self:GetUnitOwner() then return true end

  return MelonCommander.IsSameAlliance(self:GetBelongingAlliance(), otherUnit:GetBelongingAlliance())
end

function ENT:HasFlag(flag)
  local unitState = self:GetUnitState()
  if unitState == nil then return false end

  local flagState = unitState.FlagCache[flag]
  if flagState then return true end

  return false
end

function ENT:HasOneOfFlags(flags)
  for k, v in ipairs(flags) do
    if self:HasFlag(v) then
      return true
    end
  end

  return false
end

function ENT:SetFlag(flag, value)
  local unitState = self:GetUnitState()
  if unitState == nil then return false end

  if value then
    unitState.FlagCache[flag] = true
  else
    unitState.FlagCache[flag] = nil
  end

  return false
end
