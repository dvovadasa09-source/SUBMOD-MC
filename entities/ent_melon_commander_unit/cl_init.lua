include("shared.lua")

function ENT:OnRemove()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  if unitState.isSelected then
    MelonCommander.RemoveUnitFromSelection(self)
    MelonCommander.ReplicateSelection()
  end

  if unitState.controlGroupName ~= nil then
    MelonCommander.ResetUnitControlGroup(self)
  end
end

function ENT:Initialize()
  self:ClientUnitInitialize()
end

function ENT:ClientUnitInitialize()
  local unitIdentifier = self:GetUnitIdentifier()
  if unitIdentifier == nil or unitIdentifier == "" then return end

  local unitState = MelonCommander.CreateUnitState(unitIdentifier)
  self.MelonCommanderUnitState = unitState
  
  self:SetDrawGoalFor(0.0)

  local selfPos = self:GetPos()

  unitState.lastOutpostRingUpdate = 0
  unitState.lastOutpostRingPosition = Vector(0, 0, 0)

  self:CallComponents("SharedInitialize")
  self:CallComponents("ClientInitialize")
end

function ENT:Draw()
  self:CallComponents("Draw")
end

function ENT:DrawWorldSpaceHints()
  self:DrawSelectionHolo()

  if not self:IsFinishedBuilding() then
    self:DrawBuildTimer()
  else
    self:DrawOutpostRing()
  end

  if self:ShouldDrawGoal() then
    self:DrawGoal()
  end

  if self:ShouldDrawRallyPoints() then
    self:DrawRallyPoints()
  end

  if self:ShouldDrawHeightLine() then
    self:DrawHeightLine()
  end
end

function ENT:DrawSelectionHolo()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  if not unitState.isSelected then return end

  local pos = self:GetPos()

  local renderSize = self:GetModelRadius()
  renderSize = renderSize * 1.3 * self:GetModelScale()

  local color = self:GetColor()
  color.a = 100
  color:AddBrightness(0.3)

  MelonCommander.Utility.Render.DeferDrawCall(function()
    render.SetColorMaterial()
    render.DrawSphere(
      pos,
      renderSize,
      15,
      15,
      color
    )
  end)
end

function ENT:CheckOutpostRing()
  local unitState = self:GetUnitState()

  local curTime = CurTime()
  local selfPos = self:GetPos()

  if curTime - unitState.lastOutpostRingUpdate > 3 then
    if selfPos:Distance(unitState.lastOutpostRingPosition) > 5 then
      self:UpdateOutpostRing()

      unitState.lastOutpostRingPosition = selfPos
      unitState.lastOutpostRingUpdate = curTime
    end
  end
end

function ENT:UpdateOutpostRing()
  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate == nil then return end

  if unitTemplate.OutpostRadius <= 0 then return end

  local center = self:GetPos()

  self.outpostRingCircle = {}
  MelonCommander.Utility.Render.DefineCircle(self.outpostRingCircle, center.x, center.y, unitTemplate.OutpostRadius, 64)

  local buildHeight = MelonCommander.GameRules.BuildHeight

  self.outpostRingCircleZ = {}
  for i = 2, #self.outpostRingCircle do
    local segment = self.outpostRingCircle[i]
    local tr = util.TraceLine({
      start = Vector(segment.x, segment.y, center.z + buildHeight),
      endpos = Vector(segment.x, segment.y, center.z - buildHeight),
      collisiongroup = COLLISION_GROUP_WORLD
    })

    self.outpostRingCircleZ[i] = tr.HitPos.z + 3
  end
end

function ENT:DrawOutpostRing()
  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate == nil then return end

  if unitTemplate.OutpostRadius <= 0 then return end
  if self.outpostRingCircle == nil then return end

  MelonCommander.Utility.Render.DeferDrawCall(function()
    MelonCommander.Utility.Render.DrawDefinedWorldCircle(
      self.outpostRingCircle,
      self.outpostRingCircleZ,
      self:GetColor()
    )
  end)
end

function ENT:DrawBuildTimer()
  local remainingTime = self:GetUnitBuildFinishesAt() - CurTime()
  if remainingTime <= 0.0 then return end

  local _, maxs = self:WorldSpaceAABB()
  local selfPos = self:GetPos()
  local pos = Vector(selfPos.x, selfPos.y, maxs.z + 8)
  
  local text = string.format("%.1f", remainingTime)

  MelonCommander.Utility.Render.DeferDrawCall(function()
    MelonCommander.Utility.Render.DrawWorldText(pos, text, 0.30)
  end)
end

function ENT:DrawGoal()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local start = self:GetPos()

  local goal = self:GetUnitGoal()
  if goal:Length() <= 1.0 then return end

  local currentDuration = CurTime() - unitState.drawGoalStartTime 
  local totalDuration = unitState.drawGoalEndTime - unitState.drawGoalStartTime

  local ratio = 1.0 - (currentDuration / totalDuration)
  ratio = math.Clamp(ratio, 0.0, 1.0)

  local color = Color(160, 160, 160)
  color.a = ratio * 200

  MelonCommander.Utility.Render.DeferDrawCall(function()
    render.SetColorMaterial()
    render.DrawLine(start, goal, color)
    render.DrawSphere(goal, 6, 5, 5, color)
  end)
end

function ENT:ShouldDrawRallyPoints()
  local unitState = self:GetUnitState()
  if unitState == nil then return false end

  if not unitState.isSelected then return false end

  return true
end

function ENT:DrawRallyPoints()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local currentDuration = CurTime() - unitState.drawGoalStartTime 
  local totalDuration = unitState.drawGoalEndTime - unitState.drawGoalStartTime

  local color = Color(100, 180, 100, 140)

  local points = {}

  local goal = self:GetUnitGoal()
  if goal:Length() > 1.0 then
    table.insert(points, goal)
  end

  table.Add(points, unitState.RallyPoints)

  MelonCommander.Utility.Render.DeferDrawCall(function()
    render.SetColorMaterial()

    local prevPos = self:GetPos()
    for k, v in ipairs(points) do
      render.DrawLine(prevPos, v, color)
      render.DrawSphere(v, 6, 5, 5, color)

      prevPos = v
    end
  end)
end

function ENT:ShouldDrawHeightLine()
  if not MelonCommander.IsUnitSuitableForSelection(self) then return false end
  if not input.IsKeyDown(KEY_LALT) then return false end

  return true
end

function ENT:DrawHeightLine()
  local startPos = self:GetPos()
  local endPos = startPos - Vector(0, 0, 30000)

  local col = self:GetColor()

  MelonCommander.Utility.Render.DeferDrawCall(function()
    render.DrawLine(startPos, endPos, col, true)
  end)
end

function ENT:Think()
  local unitState = self:GetUnitState()
  if unitState == nil then
    local unitIdentifier = self:GetUnitIdentifier()
    if unitIdentifier == nil or unitIdentifier == "" then return end

    self:ClientUnitInitialize()
    unitState = self:GetUnitState()
  end 

  if unitState == nil then return end

  self:CheckOutpostRing()

  self:DrawWorldSpaceHints()
  
  self:CallComponents("SharedThink")
  self:CallComponents("ClientThink")
end

function ENT:OnRemove()
  self:CallComponents("SharedRemove")
  self:CallComponents("ClientRemove")
end

function ENT:ShouldDrawGoal()
  if not MelonCommander.IsUnitSuitableForSelection(self) then return false end
  
  local unitState = self:GetUnitState()
  if unitState == nil then return false end

  local localPlyIdentifier = MelonCommander.GetPlayerIdentifierFromEngine(LocalPlayer())
  local unitOwner = self:GetUnitOwner()

  if localPlyIdentifier ~= unitOwner then return false end

  local goal = self:GetUnitGoal()
  if goal:Length() <= 1.0 then 
    return false 
  end

  if input.IsKeyDown(KEY_LALT) then
    self:SetDrawGoalFor(1.0)
  end

  return CurTime() < unitState.drawGoalEndTime
end

function ENT:SetDrawGoalFor(seconds)
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  unitState.drawGoalStartTime = CurTime()
  unitState.drawGoalEndTime = unitState.drawGoalStartTime + seconds
end