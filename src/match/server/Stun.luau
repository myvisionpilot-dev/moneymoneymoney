--!strict
-- Knocked down (by the rival crew): the character sits on the ground seeing stars for a few
-- seconds. It's the "Stunned" attribute on the character: their own client sits them down and
-- everyone sees the stars (client/StunController), and jobs check it (a carried parcel drops,
-- no throwing).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Juice = require(script.Parent.Juice)
local Particles = require(ReplicatedStorage.Shared.Particles)

local STUN_ATTRIBUTE = "Stunned"
local STAR_COLOR = Color3.fromRGB(255, 230, 90)

local Stun = {}

function Stun.isStunned(character: Model): boolean
	return character:GetAttribute(STUN_ATTRIBUTE) == true
end

function Stun.player(victim: Player, seconds: number)
	local character = victim.Character
	if not character or Stun.isStunned(character) then
		return
	end
	character:SetAttribute(STUN_ATTRIBUTE, true)
	Juice.sound(victim, "Stun")
	task.delay(seconds, function()
		if character.Parent then
			character:SetAttribute(STUN_ATTRIBUTE, nil)
		end
	end)
end

-- Stars twinkling round an NPC's head (a shoved rival) for a while.
function Stun.stars(model: Model, seconds: number)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local halo = Instance.new("Attachment")
	halo.Name = "StunStars"
	halo.Position = Vector3.new(0, 1.4, 0)
	halo.Parent = head
	local twinkle = Particles.keep(halo, "Stars", 10, STAR_COLOR, 0.5)
	twinkle.SpreadAngle = Vector2.new(180, 15)
	twinkle.Speed = NumberRange.new(1.5, 2.5)
	task.delay(seconds, function()
		halo:Destroy()
	end)
end

return Stun
