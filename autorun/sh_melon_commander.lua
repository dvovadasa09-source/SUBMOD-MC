AddCSLuaFile("melon_commander/shared.lua")
AddCSLuaFile("melon_commander/client.lua")

AddCSLuaFile("melon_commander/shared/resources.lua")
AddCSLuaFile("melon_commander/shared/core.lua")
AddCSLuaFile("melon_commander/shared/utility.lua")

AddCSLuaFile("melon_commander/shared/net.lua")

include("melon_commander/shared/resources.lua")
include("melon_commander/shared/core.lua")
include("melon_commander/shared/utility.lua")
include("melon_commander/shared/net.lua")

if SERVER then
  include("melon_commander/server/net.lua")
end

hook.Add("Initialize", "melon_commander_initialize", function()
  include("melon_commander/shared.lua")

  if SERVER then
    include("melon_commander/server.lua")
  else
    include("melon_commander/client.lua")
  end
end)
