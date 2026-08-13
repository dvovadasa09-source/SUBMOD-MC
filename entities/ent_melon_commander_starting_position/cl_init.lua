include("shared.lua")

function ENT:Draw()	
	if not MelonCommander.Match.IsActive then
		self:DrawModel()
		self:DrawName()
	end
end

function ENT:Think()
	if not MelonCommander.Match.IsActive then
		self:DrawSkyLine()
	end
end

function ENT:DrawName()
	local pos = self:GetPos() + self:GetUp() * (self:OBBMaxs().z + 5.0)

	MelonCommander.Utility.Render.DeferDrawCall(function()
		MelonCommander.Utility.Render.DrawWorldText(pos, self:GetStartingPositionName())
	end)
end

function ENT:DrawSkyLine()
	local startPos = self:GetPos()
  local endPos = startPos + Vector(0, 0, 30000)

	local color = color_white
	for k, v in pairs(MelonCommander.Players) do
		if not v.WantObserver and v.StartingPosition == self:GetStartingPositionName() then
			color = v.Color
		end
	end

	MelonCommander.Utility.Render.DeferDrawCall(function()
  	render.DrawLine(startPos, endPos, color, true)
	end)
end
