AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
  self.MelonCommanderUnitState = MelonCommander.CreateUnitState(MelonCommander.Expansions.Base.Unit.WaterTower)
  self:ServerUnitInitialize()
end