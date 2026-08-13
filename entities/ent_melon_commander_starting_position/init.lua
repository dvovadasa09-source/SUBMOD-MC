AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

MelonCommander.StartingPositionNameIndex = MelonCommander.StartingPositionNameIndex or 0

function ENT:Initialize()
  self:SetMaterial("phoenix_storms/stripes")
  self:SetModel("models/props_combine/combine_mine01.mdl")

  self:PhysicsInitSphere(9, "solidmetal")
  -- #TODO: set solid to SOLID_NONE when match starts so starting position won't obstruct unit movement
  self:SetSolid(SOLID_VPHYSICS)
  self:SetMoveType(MOVETYPE_NONE)

  local physObject = self:GetPhysicsObject()
  if physObject:IsValid() then
    physObject:Wake()
  end

  self:DrawShadow(false)

  self:SetPos(self:GetPos() - Vector(0, 0, 5))

  local name = self:UpdateName()
  if name == nil then
    self:Remove()
    return
  end
  
  MelonCommander.StartingPositionEntities[name] = self
end

function ENT:OnRemove()
  local name = self:GetStartingPositionName()
  MelonCommander.StartingPositionEntities[name] = nil

  for k, v in pairs(MelonCommander.Players) do
    if v.StartingPosition == name then
      v.StartingPosition = MelonCommander.RandomStartingPosition
    end
  end

  MelonCommander.ReplicatePlayers()

  MelonCommander.StartingPositionNameIndex = MelonCommander.StartingPositionNameIndex - 1
end

function ENT:UpdateName()
  MelonCommander.StartingPositionNameIndex = MelonCommander.StartingPositionNameIndex + 1

  local index = MelonCommander.StartingPositionNameIndex
  if index > #self.AvailableNamesList then return nil end

  local name = self.AvailableNamesList[index]

  self:SetStartingPositionName(name)
  return name
end
