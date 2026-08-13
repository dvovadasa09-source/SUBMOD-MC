SWEP.Category = "Melon Commander"
SWEP.PrintName = "Melon Controller"
SWEP.Author = "toph"
SWEP.Instructions = "Start matches and control the battlefield"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawCrosshair = true
SWEP.DrawAmmo = false

SWEP.Weight = 0

SWEP.ViewModel = ""
SWEP.WorldModel = ""

SWEP.NextReload = 0

SWEP.UseHands = false

if SERVER then
  util.AddNetworkString(MelonCommander.Net.OpenGUINetMessage)
end

function SWEP:Initialize()
  self:SetHoldType("magic")

  self.nextInteract = CurTime()
end

function SWEP:PrimaryAttack()
  if CLIENT then return end

  self:CallIntentMethod("PerformPrimaryAction")
end

function SWEP:SecondaryAttack()
  if CLIENT then return end

  self:CallIntentMethod("PerformSecondaryAction")
end

function SWEP:ProcessInteract()
  if CurTime() < self.nextInteract then return end

  local useKey = input.LookupBinding("+use")
  if useKey == nil then return end

  local useKeyCode = input.GetKeyCode(useKey)
  if useKeyCode == nil then return end

  if input.IsKeyDown(useKeyCode) then
    MelonCommander.InteractWithSelection()
    self.nextInteract = CurTime() + 0.1
  end
end

function SWEP:CallIntentMethod(name)
  if not MelonCommander.IsPlaying() then return end

  local engineOwner = self:GetOwner()
  local owner, ownerIdentifier = MelonCommander.GetPlayerFromEngine(engineOwner)
  if owner == nil then return end

  if not MelonCommander.IsPlayerActive(owner) then return end

  local intent = MelonCommander.PlayerIntents[ownerIdentifier]
  if intent == nil then return end

  local impl = MelonCommander.PlayerIntentImplementation[intent.Kind]
  if impl == nil then return end

  local method = impl[name]
  if type(method) ~= "function" then return end

  local shouldClear = method(intent, owner, engineOwner)
  if shouldClear then
    MelonCommander.ClearPlayerIntent(engineOwner)
  end
end

function SWEP:Reload()
  if CLIENT then return end

  if self.NextReload > CurTime() then return end

  net.Start(MelonCommander.Net.OpenGUINetMessage)
  net.Send(self:GetOwner())

  self.NextReload = CurTime() + 1.0
end

function SWEP:DoDrawCrosshair(x, y)
  self:DrawCrosshair(x, y)
  return true
end

function SWEP:DrawCrosshair(x, y)
  local size = 8.0

  if IsValid(MelonCommander.GhostUnit) then 
    size = size / 2.0
  end

  MelonCommander.DrawCrosshair(x, y, size, 1)
end

function SWEP:DrawHUD()
  MelonCommander.DrawHUD()

  MelonCommander.ProcessControlGroups()
  MelonCommander.ProcessSelection()

  if MelonCommander.LocalPlayerIntent.Kind == MelonCommander.PlayerIntentKind.None then
    local doesWantToIssueOrders = MelonCommander.Utility.Table.NonSequentialLength(
        MelonCommander.Selection.SelectedUnits
    ) > 0

    if doesWantToIssueOrders then
      MelonCommander.ClearIntent()
      MelonCommander.BeginIssuingOrders(true)
      MelonCommander.ReplicateLocalPlayerIntent()
    end
  end

  MelonCommander.UpdateGhostUnit()

  self:ProcessInteract()

  local impl = MelonCommander.PlayerIntentImplementation[MelonCommander.LocalPlayerIntent.Kind]
  if impl == nil then 
    MelonCommander.DrawHoveredUnit()
    return
  end

  impl.ClientThink(MelonCommander.LocalPlayerIntent)

  local takesCrosshairSpace = impl.DrawHUD(MelonCommander.LocalPlayerIntent)
  if not takesCrosshairSpace then
    MelonCommander.DrawHoveredUnit()
  end
end
