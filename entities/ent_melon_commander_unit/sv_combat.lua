function ENT:ThinkCombat()
  local thinkCombatProfCall = MelonCommander.Utility.Profiling.Begin("Unit:ThinkCombat")

  local unitState = self:GetUnitState()
  if unitState == nil then return end

  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end

  if not self:HasAmmo() then
    self:ReloadWeapon()
  end

  local curTime = CurTime()

  local weaponState = self:GetWeaponState()

  local weaponIdleReloadDelay = 15.0

  local timeSinceLastAttack = curTime - weaponState.NextAttack
  if not self:IsFullAmmo() and timeSinceLastAttack > weaponIdleReloadDelay then
    self:ReloadWeapon()
  end

  -- Standby target search delay
  local targetSearchDelay = 1.5

  -- Switch target search delay
  local targetSwitchDelay = 0.5

  local target = self:GetUnitTarget()
  local oldTarget = target

  if IsValid(target) then
    if not unitState.IsTargetForced and not self:CanAttackTarget(target) then 
      target = NULL
    end
  elseif curTime > weaponState.NextTargetSearch then
    target = self:SearchForTargetUnit()

    if IsValid(target) and weaponTemplate.AggressiveMove then
      unitState.IsTargetForced = true
    else
      unitState.IsTargetForced = false
    end

    if not IsValid(target) then
      weaponState.NextTargetSearch = curTime + targetSearchDelay
    else
      weaponState.NextTargetSearch = curTime + targetSwitchDelay
    end
  end

  if target ~= oldTarget then
    self:SetUnitTarget(target)
  end

  if IsValid(target) and self:CanAttackNow() then
    self:AttackTarget()
  end

  MelonCommander.Utility.Profiling.End("Unit:ThinkCombat", thinkCombatProfCall)
end

function ENT:CanReachTarget(target, start, rangeOverride)
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return false end

  local targetPos = target:GetPos()

  start = start or self:GetPos()
  local distance = targetPos:Distance(start)

  local targetMins, targetMaxs = target:WorldSpaceAABB()
  local targetHorizontalSize = targetMins:Distance2D(targetMaxs)

  distance = distance - targetHorizontalSize

  local range = weaponTemplate.MaxRange
  if rangeOverride ~= nil then
    range = rangeOverride
  end

  if distance > range then return false end

  return true
end

function ENT:CanAttackTarget(target, start, rangeOverride)
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return false end

  if not MelonCommander.IsEntityUnit(target) then return false end

  if self:IsAlly(target) then return false end

  if not target:IsInGame() then return false end

  if not target:IsTargetableByAI() then return false end
  if not target:HasOneOfFlags(weaponTemplate.TargetFlags) then return false end

  local targetPos = target:GetPos()

  local doVisiblityCheck = true
  if start ~= nil then
    doVisiblityCheck = false
  end

  if not self:CanReachTarget(target, start, rangeOverride) then return false end

  local targetTemplate = target:GetUnitTemplate()
  if not targetTemplate.Targetable then return false end

  if doVisiblityCheck then
    local worldOnly = not weaponTemplate.NeedsLineOfSight
    local targetCenter = target:WorldSpaceCenter()

    local canSeeCenter = self:CanSee(targetCenter, target, worldOnly)
    if canSeeCenter then return true end

    local canSeePos = self:CanSee(targetPos, target, worldOnly)
    if canSeePos then return true end

    return false 
  end

  return true
end

function ENT:ShouldLeap(position)
  local weaponState = self:GetWeaponState()
  if weaponState == nil then return end

  if CurTime() < weaponState.NextLeap then return false end

  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return false end

  if not weaponTemplate.LeapAtTarget then return false end

  local distance = self:GetPos():Distance2D(position)
  local leapRange = weaponTemplate.MaxRange * 3.5

  if distance < leapRange then
    return true
  end

  return false
end

function ENT:LeapTowards(position)
  local weaponState = self:GetWeaponState()
  if weaponState == nil then return end

  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end

  local direction = position - self:GetPos()
  direction:Normalize()
  direction.z = 0.3

  local physObject = self:GetPhysicsObject()
  if not IsValid(physObject) then return end

  local force = weaponTemplate.LeapSpeed * 39.7 * physObject:GetMass()
  local vel = direction * force

  physObject:ApplyForceCenter(vel)

  weaponState.NextLeap = CurTime() + weaponTemplate.FireDelay * 1.5

  local leapSound = weaponTemplate.LeapSound
  if leapSound ~= nil and leapSound ~= "" then
    sound.Play(leapSound, self:GetPos(), 70, 100, 0.8)
  end
end

function ENT:SearchForTargetUnit()
  local searchProfCall = MelonCommander.Utility.Profiling.Begin("Unit:SearchForTargetUnit")

  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return nil end

  local selfPos = self:GetPos()

  local aggroRange = weaponTemplate.AggroRange
  if aggroRange == nil then
    aggroRange = weaponTemplate.MaxRange
  end

  local bestTarget = NULL
  local bestDistance = aggroRange

  local nearbyEntities = ents.FindInSphere(selfPos, aggroRange)
  for k, v in ipairs(nearbyEntities) do
    if v == self then continue end

    if not self:CanAttackTarget(v, selfPos, aggroRange) then continue end

    local distance = v:GetPos():Distance(selfPos)
    if distance < bestDistance then
      bestDistance = distance
      bestTarget = v
    end
  end

  MelonCommander.Utility.Profiling.End("Unit:SearchForTargetUnit", searchProfCall)
  return bestTarget
end

function ENT:HasWeapon() 
  local weaponTemplate = self:GetWeaponTemplate()

  return weaponTemplate ~= nil
end

function ENT:CanAttackNow()
  if not self:HasWeapon() then return false end
  if not self:HasAmmo() then return false end

  local weaponState = self:GetWeaponState()

  if weaponState.NextAttack > CurTime() then return false end

  return true
end

function ENT:HasAmmo()
  if not self:HasWeapon() then return false end

  local weaponState = self:GetWeaponState()

  if weaponState.Clip == MelonCommander.InfiniteClip then return true end

  return weaponState.Clip > 0
end

function ENT:IsFullAmmo()
  if not self:HasWeapon() then return true end

  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return true end

  local weaponState = self:GetWeaponState()

  if weaponState.Clip == MelonCommander.InfiniteClip then return true end

  return weaponState.Clip == weaponTemplate.ClipSize
end

function ENT:CanReloadWeapon()
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return false end

  if weaponTemplate.ReloadOnlyWithinOutpost then
    return self:IsNearAlliedOutpost()
  end

  return true
end

function ENT:ReloadWeapon()
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end

  if not self:CanReloadWeapon() then return end

  local weaponState = self:GetWeaponState()

  weaponState.NextAttack = CurTime() + weaponTemplate.ClipReloadTime
  weaponState.Clip = weaponTemplate.ClipSize

  self:PlayWeaponReloadFX()
end

function ENT:PlayWeaponTracerEffect(shootPos)
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end
  
  local tracerEffect = weaponTemplate.TracerEffect
  if tracerEffect == nil or tracerEffect == "" then return end

  local start = self:GetPos()
  local target = shootPos

  local dir = (target - start):GetNormalized()

  local effectData = EffectData()
  effectData:SetStart(start + dir * self:GetModelRadius() * 5)
  effectData:SetOrigin(target)

  util.Effect(tracerEffect, effectData)
end

function ENT:PlayWeaponImpactEffect(shootPos)
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end
  
  local impactEffect = weaponTemplate.ImpactEffect
  if impactEffect == nil or impactEffect == "" then return end

  local target = shootPos

  local effectData = EffectData()
  effectData:SetStart(target)

  util.Effect(impactEffect, effectData)
end

function ENT:PlayWeaponShootFX()
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end

  local fireSound = MelonCommander.Utility.Table.Random(weaponTemplate.FireSounds)
  if fireSound ~= nil and fireSound ~= "" then
    local pitchShift = math.random(-5, 5)
    sound.Play(fireSound, self:GetPos(), 80, 100 + pitchShift, 0.6)
  end
  
  local shootEffect = weaponTemplate.ShootEffect

  if shootEffect == nil or shootEffect == "" then return end

  local start = self:GetPos()

  local effectData = EffectData()
  effectData:SetStart(start)

  util.Effect(shootEffect, effectData)
end

function ENT:PlayWeaponReloadFX()
  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end

  sound.Play(weaponTemplate.ClipReloadSound, self:GetPos())
end

function ENT:AttackTarget()
  if not self:CanAttackNow() then return end

  local weaponTemplate = self:GetWeaponTemplate()
  if weaponTemplate == nil then return end

  local weaponState = self:GetWeaponState()

  local target = self:GetUnitTarget()
  if not MelonCommander.IsEntityUnit(target) then return end

  local targetPos = target:GetPos()
  if self:ShouldLeap(targetPos) then
    self:LeapTowards(targetPos)
  end

  if not self:CanAttackTarget(target) then return end

  weaponState.NextAttack = CurTime() + weaponTemplate.FireDelay

  if weaponState.Clip ~= MelonCommander.InfiniteClip then
    weaponState.Clip = weaponState.Clip - 1
  end

  self:CallComponents("OnUseWeapon", { target })
  
  if not IsValid(target) then
    self:PlayWeaponTracerEffect(self:GetPos())
  else
    if weaponTemplate.RotateTowardsTarget then
      local direction = target:GetPos() - self:GetPos()
      direction:Normalize()

      self:SetAngles(direction:Angle())
    end

    self:PlayWeaponShootFX()

    if weaponTemplate.Type == MelonCommander.WeaponType.HitScan then
      self:AttackHitScan(target, weaponTemplate)
    elseif weaponTemplate.Type == MelonCommander.WeaponType.Projectile then
      self:AttackProjectile(target, weaponTemplate)
    end
  end

  if weaponTemplate.IsSuicide then
    self:CallComponents("Die")
  end
end

function ENT:AttackHitScan(target, weaponTemplate)
  local victims = {
    target
  }

  local radius = weaponTemplate.Radius

  if radius > 0 then
    local targetCenter = target:WorldSpaceCenter()
    local nearbyVictims = ents.FindInSphere(targetCenter, radius)
    for k, v in ipairs(nearbyVictims) do
      if v == self then continue end
      if v == target then continue end

      if not self:CanAttackTarget(v, targetCenter, radius) then continue end

      table.insert(victims, v)
    end
  end

  for k, v in ipairs(victims) do
    v:TakeUnitDamage(weaponTemplate.Damage, self)
    self:PlayWeaponImpactEffect(v:WorldSpaceCenter())
  end

  local tracerTarget = Vector()
  tracerTarget:Random(-5, 5)

  self:PlayWeaponTracerEffect(target:WorldSpaceCenter() + tracerTarget)
end

function ENT:AttackProjectile(target, weaponTemplate)
  local selfPos = self:GetPos()

  local projectile = MelonCommander.CreateProjectile(weaponTemplate.ProjectileModel, weaponTemplate, self)
  projectile.target = target

  local targetPos = target:GetPos()

  local direction = targetPos - selfPos
  direction:Normalize()

  local radius = self:BoundingRadius()
  local offset = (direction * radius)
  local projectilePos = selfPos + offset

  constraint.NoCollide(projectile, self, 0, 0)

  projectile:SetPos(projectilePos)
  projectile:SetAngles(direction:Angle())
  projectile:SetColor(self:GetColor())
  projectile:SetOwner(self)
  projectile:Spawn()

  local physObj = projectile:GetPhysicsObject()
  if not IsValid(physObj) then return end

  if weaponTemplate.DoLob then
    self:LobProjectile(targetPos, direction, 5, weaponTemplate.LaunchForce, physObj)
  else
    self:ShootProjectile(targetPos, direction, weaponTemplate.LaunchForce, weaponTemplate.Homing, physObj)
  end
end

function ENT:ShootProjectile(targetPos, direction, launchForce, homing, physObj)
  if homing then return end
  
  local selfPos = self:GetPos()

  local force = launchForce

  local delta = targetPos - selfPos
  local horizontalDelta = Vector(delta.x, delta.y, 0)
  local horizontalDistance = horizontalDelta:Length()
  local heightDifference = delta.z

  local eta = horizontalDistance / force

  local gravity = physenv.GetGravity():Length()
  local verticalVelocity = (heightDifference / eta) + (0.5 * gravity * eta)

  local direction = horizontalDelta:GetNormalized()
  direction = direction * force
  direction.z = verticalVelocity

  physObj:SetVelocity(direction)
end

function ENT:LobProjectile(targetPos, direction, randomness, launchForce, physObj)
  local selfPos = self:GetPos()
  local environmentGravity = physenv.GetGravity()
  local fallbackAngle = -45

  local x = targetPos:Distance2D(selfPos)
  local y = targetPos.z - selfPos.z

  local v = launchForce
  local g = math.abs(environmentGravity.z)

  local a = math.pow(v, 4)
  local b = g * (g * math.pow(x, 2) + 2 * y * math.pow(v, 2))

  local ang = direction:Angle()
  ang.y = ang.y + math.random(-randomness, randomness)
  ang.p = ang.p + math.random(-randomness, randomness)

  direction = ang:Forward()

  local square = a - b
  if square < 0 then
    local ang = direction:Angle()
    ang.p = fallbackAngle

    direction = ang:Forward()
  else
    square = math.sqrt(square)

    local pitchRad = math.atan((math.pow(v, 2) + square) / (g * x))
    local pitchDeg = math.deg(pitchRad)

    local ang = direction:Angle()
    ang.p = -pitchDeg

    direction = ang:Forward()
  end

  local vel = direction * v
  physObj:SetVelocity(vel)
end

function ENT:TakeUnitDamage(amount, attacker)
  self:CallComponents("OnTookDamage", { amount, attacker })

  if IsValid(attacker) then
    attacker:CallComponents("OnDealtDamage", { amount, self })
  end
end

function ENT:SetForceTarget(target)
  local unitState = self:GetUnitState()
  self:SetUnitTarget(target)
  unitState.IsTargetForced = true
end

function ENT:AddTargetableCheck(callback)
  if type(callback) ~= "function" then
    error("didn't pass a function to AddTargetableCheck")
    return 
  end

  table.insert(self.targetableChecks, callback)
end

function ENT:IsTargetableByAI()
  for k, v in ipairs(self.targetableChecks) do
    if not v() then return false end
  end

  return true
end