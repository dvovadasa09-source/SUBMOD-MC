function ENT:ThinkMove()
  local thinkMoveProfCall = MelonCommander.Utility.Profiling.Begin("Unit:ThinkMove")

  local physObject = self:GetPhysicsObject()

  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local target = self:GetUnitTarget()
  local selfPos = self:GetPos()

  if self:IsAirUnit() then
    local locomotorTemplate = self:GetLocomotorTemplate()
    if locomotorTemplate == nil then return end

    unitState.isDiving = false

    self:DoAirFriction()

    local targetZ = nil

    if unitState.CurrentRallyPoint ~= nil and locomotorTemplate.AlterHeight then
      targetZ = unitState.CurrentRallyPoint.z + locomotorTemplate.Height
    end

    self:MaintainFlight(targetZ)
    self:KeepUprightAir()
  
    if unitState.CurrentRallyPoint == nil and locomotorTemplate.FlyCircleAround then
      self:PhysicsWake()
      self:CircleInAir()
    end
  else
    self:Unstuck()
  end

  if unitState.CurrentRallyPoint == nil then
    if #unitState.RallyPoints > 0 then 
      local rallyPoint = unitState.RallyPoints[1]
      self:SetRallyPoint(rallyPoint)

      unitState.CurrentRallyPoint = rallyPoint

      table.remove(unitState.RallyPoints, 1)
      self:ReplicateRallyPoints()
    end
  end

  if not self:IsAirUnit() then
    self:HoldPosition()
  end

  if unitState.CurrentRallyPoint ~= nil then
    self:PhysicsWake()
    local didArrive = self:MoveTowardsPoint(unitState.CurrentRallyPoint)
    if didArrive then
      self:SetRallyPoint(nil)
      self:FullStopHorizontal()
    end
  end

  local weaponTemplate = self:GetWeaponTemplate()
  local shouldMoveToTarget = unitState.IsTargetForced
  if weaponTemplate ~= nil then
    shouldMoveToTarget = shouldMoveToTarget
  end

  if unitState.CurrentRallyPoint == nil then
    if IsValid(target) and shouldMoveToTarget then
      self:PhysicsWake()
      self:MoveCloseEnoughToAttack(target)
    end
  end

  MelonCommander.Utility.Profiling.End("Unit:ThinkMove", thinkMoveProfCall)
end

function ENT:PhysicsWake()
  local physObj = self:GetPhysicsObject()
  if IsValid(physObj) and physObj:IsAsleep() then
    physObj:EnableMotion(true)
    physObj:Wake()
  end
end

function ENT:HoldPosition()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local physObj = self:GetPhysicsObject()

  local isMoving = (unitState.CurrentRallyPoint ~= nil) or physObj:GetVelocity():Length() > 100.0
  if isMoving then
    if not physObj:IsMotionEnabled() then
      physObj:EnableMotion(true)
    end
  
    return
  end

  if physObj:IsMotionEnabled() then
    physObj:EnableMotion(false)
  end
end

function ENT:KeepUprightAir()
  local physObject = self:GetPhysicsObject()
  if not IsValid(physObject) then return end

  local angles = self:GetAngles()
  if math.abs(angles.z) < 0.1 and math.abs(angles.x) < 0.1 then return end

  angles.x = 0.0
  angles.z = 0.0

  local velocity = physObject:GetVelocity()
  self:SetAngles(angles)
  physObject:SetVelocity(velocity)
end

function ENT:MoveCloseEnoughToAttack(target)
  if not MelonCommander.IsEntityUnit(target) then return end

  local targetPos = target:GetPos()
  
  local locomotorTemplate = self:GetLocomotorTemplate()
  if locomotorTemplate == nil then
    self:SetRallyPoint(targetPos)
    return
  end

  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end

  local range = weaponTemplate.MaxRange
  range = range * 0.96

  local selfPos = self:GetPos()
  local distance = selfPos:Distance(targetPos)

  if distance <= range then return end

  local shouldMoveIntoUnit = self:IsAirUnit() and not target:IsAirUnit()
  shouldMoveIntoUnit = shouldMoveIntoUnit or range < 100.0

  local moveTarget
  if shouldMoveIntoUnit then
    moveTarget = targetPos
  else
    local direction = targetPos - selfPos
    direction:Normalize()

    local moveOffset = direction * range
    moveTarget = targetPos - moveOffset
  end

  moveTarget = MelonCommander.Utility.Space.GetGroundPos(moveTarget)
  self:SetRallyPoint(moveTarget)
end

function ENT:IsAirUnit()
  local locomotorTemplate = self:GetLocomotorTemplate()
  if locomotorTemplate == nil then return end

  return locomotorTemplate.MoveType == MelonCommander.LocomotorMoveType.Air
end

function ENT:Unstuck()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local locomotorTemplate = self:GetLocomotorTemplate()
  if locomotorTemplate == nil then return end

  local curTime = CurTime()

  local maxPushAttempts = 3
  if locomotorTemplate.MoveType == MelonCommander.LocomotorMoveType.Air then
    maxPushAttempts = 0
  end

  if unitState.CurrentRallyPoint == nil then
    unitState.lastCheckStuckTime = curTime
    unitState.lastCheckStuckPosition = self:GetPos()

    unitState.pushAttempts = maxPushAttempts
    return
  end

  if unitState.lastCheckStuckTime == nil then
    unitState.lastCheckStuckTime = curTime
    unitState.lastCheckStuckPosition = self:GetPos()

    unitState.pushAttempts = maxPushAttempts
    return
  end

  -- This should be greater than a second
  local checkStuckInterval = 1.2
  if curTime - unitState.lastCheckStuckTime < checkStuckInterval then
    return
  end

  if self:GetPos():Distance(unitState.lastCheckStuckPosition) < locomotorTemplate.Speed then
    if unitState.pushAttempts <= 0 then
      self:SetRallyPoint(nil)
      unitState.pushAttempts = maxPushAttempts
    else
      local physObject = self:GetPhysicsObject()
      if not physObject:IsValid() then return end

      local pushForce = Vector(0, 0, 6.5) * physObject:GetMass() * 39.37
      physObject:ApplyForceCenter(pushForce)

      unitState.pushAttempts = unitState.pushAttempts - 1
    end
  end

  unitState.lastCheckStuckTime = curTime
  unitState.lastCheckStuckPosition = self:GetPos()
end

function ENT:MaintainFlight(targetZ)
  local locomotorTemplate = self:GetLocomotorTemplate()
  if locomotorTemplate == nil then return end

  if locomotorTemplate.MoveType ~= MelonCommander.LocomotorMoveType.Air then return end

  local physObject = self:GetPhysicsObject()
  if not physObject:IsValid() then return end

  physObject:EnableGravity(false)
  physObject:AddAngleVelocity(-physObject:GetAngleVelocity())

  if targetZ == nil then
    local groundPos = self:GetGroundPos()
    targetZ = groundPos.z + locomotorTemplate.Height
  end

  local selfPos = self:GetPos()
  local targetPos = Vector(selfPos.x, selfPos.y, targetZ)

  if math.abs(selfPos.z - targetZ) <= 10.0 then
    self:FullStopVertical()
    return
  end

  local direction = targetPos - selfPos
  direction.x = 0
  direction.y = 0

  local zDelta = math.abs(direction.z)
  local speed = math.Clamp(zDelta * 0.5, 0.1, 1)

  direction:Normalize()

  local mass = physObject:GetMass()

  local force = mass * (direction * speed) * 39.37 
  local deltaTime = self.deltaThink

  physObject:ApplyForceCenter(force * deltaTime)
end

function ENT:GetGroundPos()
  return MelonCommander.Utility.Space.GetGroundPos(self:GetPos())
end

function ENT:DoAirFriction()
  local locomotorTemplate = self:GetLocomotorTemplate()
  if locomotorTemplate == nil then return end

  if locomotorTemplate.MoveType ~= MelonCommander.LocomotorMoveType.Air then return end

  local physObject = self:GetPhysicsObject()
  if not physObject:IsValid() then return end

  local mass = physObject:GetMass()
  local deltaTime = self.deltaThink

  local horizontalVelocity = physObject:GetVelocity()
  horizontalVelocity.z = 0

  horizontalVelocity:Mul(-(mass * 0.5))

  physObject:ApplyForceCenter(horizontalVelocity * 4.25 * deltaTime)
end

function ENT:CircleInAir()
  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate == nil then return end

  local locomotorTemplate = self:GetLocomotorTemplate()
  if locomotorTemplate == nil then return end

  if locomotorTemplate.MoveType ~= MelonCommander.LocomotorMoveType.Air then return end

  if not locomotorTemplate.FlyCircleAround then return end

  local physObject = self:GetPhysicsObject()
  if not physObject:IsValid() then return end

  local angle = self:GetAngles()
  angle:RotateAroundAxis(angle:Up(), -unitTemplate.SpawnRotation)

  local right = angle:Right()
  local forward = angle:Forward()

  local radius = 30.0

  local target = self:GetPos() + (forward * radius) + (right * (radius / 10.0))

  local speedMultiplier
  if locomotorTemplate.Speed >= 15 then
    speedMultiplier = 0.3
  end

  self:MoveTowardsPoint(target, speedMultiplier)
end

function ENT:MoveTowardsPoint(point, speedMultiplier)
  speedMultiplier = speedMultiplier or 1.0

  local selfPos = self:GetPos()

  local locomotorTemplate = self:GetLocomotorTemplate()
  if locomotorTemplate == nil then return false end

  local unitTemplate = self:GetUnitTemplate()
  if unitTemplate == nil then return end

  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local physObject = self:GetPhysicsObject()
  if not physObject:IsValid() then return false end

  local distance = selfPos:Distance2D(point)
  local modelRadius = self:BoundingRadius() or 40
  local stopDistance = modelRadius * 0.85

  if distance <= stopDistance then
    return true
  end

  local deltaTime = self.deltaThink

  local direction = point - selfPos
  local faceDirection = Vector(direction)

  direction.z = 0
  direction:Normalize()

  if unitTemplate.ShouldFaceMoveTarget then
    if not unitState.isDiving then
      faceDirection.z = 0
    end

    faceDirection:Normalize()

    local targetAngle = faceDirection:Angle()
    targetAngle:RotateAroundAxis(targetAngle:Up(), unitTemplate.SpawnRotation)

    -- The engine resets entity velocity when you change the angles for some reason...
    local velocity = physObject:GetVelocity()

    self:SetAngles(targetAngle)

    physObject:SetVelocity(velocity)
  end

  local speed
  if unitState.forceSpeed ~= nil then
    speed = unitState.forceSpeed
  else
    speed = locomotorTemplate.Speed * speedMultiplier
  end
  
  local moveDirection = Vector(direction)
  if self:IsOnSlope() then
    local projectedDirection = self:ProjectOnGroundPlane(moveDirection)
    if projectedDirection:LengthSqr() > 0.0001 then
      projectedDirection:Normalize()
      moveDirection = projectedDirection
    end
  end

  local groundForce = physObject:GetMass() * (moveDirection * speed) * 39.37 
  physObject:ApplyForceCenter(groundForce * deltaTime)

  if self:IsOnSlope() and moveDirection.z > 0 then
    local slopeAssistDirection = Vector(moveDirection)
    slopeAssistDirection.z = slopeAssistDirection.z * 0.15

    if slopeAssistDirection:LengthSqr() > 0.0001 then
      slopeAssistDirection:Normalize()

      local slopeAssistMultiplier = math.Clamp(4 / math.max(speed, 0.1), 0.5, 1.6)
      local slopeForce = physObject:GetMass() * (slopeAssistDirection * speed * slopeAssistMultiplier) * 39.37 
      physObject:ApplyForceCenter(slopeForce * deltaTime)
    end
  end

  return false
end

function ENT:FullStopVertical()
  local physObject = self:GetPhysicsObject()
  if physObject == nil then return end

  local mass = physObject:GetMass()

  local stoppingForce = self:GetVelocity()
  local speed = stoppingForce:Length()

  stoppingForce:Mul(-(mass * 0.5))
	stoppingForce.x = 0
	stoppingForce.y = 0

  physObject:ApplyForceCenter(stoppingForce)
end

function ENT:FullStopHorizontal()
  local physObject = self:GetPhysicsObject()
  if physObject == nil then return end

  local mass = physObject:GetMass()

  local stoppingForce = self:GetVelocity()
  local speed = stoppingForce:Length()

  stoppingForce:Mul(-(mass * 0.5))
	stoppingForce.z = 0

  physObject:ApplyForceCenter(stoppingForce)
end

function ENT:AddRallyPoint(point)
  if point == nil then return end
  
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  table.insert(unitState.RallyPoints, point)
end

function ENT:ClearRallyPoints()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  unitState.RallyPoints = {}

  self:SetRallyPoint(nil)
end

function ENT:HasLocomotor()
  local locomotorTemplate = self:GetLocomotorTemplate()

  return locomotorTemplate ~= nil
end

function ENT:SetRallyPoint(point)
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  unitState.CurrentRallyPoint = point

  if point == nil then
    point = Vector(0, 0, 0)
  end

  self:SetUnitGoal(point)
end

function ENT:GetRallyPoint()
  local unitState = self:GetUnitState()
  if unitState == nil then return nil end

  return unitState.CurrentRallyPoint
end

function ENT:GetGroundNormal()
  local pos = self:GetPos()

  local trace = util.TraceLine({
    start = pos,
    endpos = pos - Vector(0, 0, self:BoundingRadius()),
    mask = MASK_SOLID_BRUSHONLY,
    collisiongroup = COLLISION_GROUP_WORLD
  })
  
  if trace.Hit then
    return trace.HitNormal, trace.HitPos
  end
  
  return Vector(0, 0, 1), pos
end

function ENT:GetSurfaceAngle()
  local groundNormal, groundPos = self:GetGroundNormal()
  local up = Vector(0, 0, 1)

  local surfaceAngle = math.deg(math.acos(math.Clamp(groundNormal:Dot(up), -1, 1)))
  return surfaceAngle
end

function ENT:IsOnSlope()
  local surfaceAngle = self:GetSurfaceAngle()
  return surfaceAngle > 8
end

function ENT:ProjectOnGroundPlane(point)
  local groundNormal, groundPos = self:GetGroundNormal()

  local normal = groundNormal:GetNormalized()
  local distance = point:Dot(normal)
  return point - normal * distance
end

function ENT:ReplicateRallyPoints()
  local unitState = self:GetUnitState()
  if unitState == nil then return end

  net.Start(MelonCommander.Net.ReplicateRallyPointsMessage)
  net.WriteEntity(self)
  net.WriteTable(unitState.RallyPoints, true)
  net.Broadcast()
end
