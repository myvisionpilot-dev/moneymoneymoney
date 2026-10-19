--!strict
-- The ten laser layouts for break-ins (BreakInRooms puts one in each laser band of a room; houses
-- take them in turn by house number). A layout is a few beams, placed across a band of the room:
-- `z` is how far through the band (0 = the near edge, 1 = the far one), `x` across the room
-- (-0.5 = the left wall, 0.5 = the right one). Every one can be got through:
--   LOW beams (knee height) you jump over          HIGH beams (chest height) you crawl under (C)
--   a FENCE (low and high together) only has its gap   POSTS (floor to ceiling) you walk round
--   SWEEPERS slide back and forth along the room: time them, or crawl under a high one
-- After a low beam the next one is always at least ~10 studs on (a jump carries you about 8 at
-- sneaking speed, Movement.SneakSpeed), so you never land on it.

local LOW = 1
local HIGH = 2.7
local FENCE = { 1.2, 3.1 }

export type Beam = {
	kind: "Wall" | "Gap" | "Post" | "Sweep",
	z: number,
	y: { number }?, -- Wall, Gap, Sweep: the heights
	x: number?, -- Gap: the gap's middle; Post: where it stands
	gap: number?, -- Gap: how wide (studs)
	swing: number?, -- Sweep: how far either way (share of the band)
	period: number?, -- Sweep: seconds there and back
	phase: number?, -- Sweep: 0..1 head start
}

export type Layout = { name: string, beams: { Beam } }

local BreakInLasers = {}

BreakInLasers.Layouts = {
	{
		name = "Hop and duck",
		beams = {
			{ kind = "Wall", z = 0.2, y = { LOW } },
			{ kind = "Wall", z = 0.85, y = { HIGH } },
		},
	},
	{
		name = "Two gaps",
		beams = {
			{ kind = "Gap", z = 0.3, y = FENCE, x = -0.28, gap = 6 },
			{ kind = "Gap", z = 0.72, y = FENCE, x = 0.28, gap = 6 },
		},
	},
	{
		name = "Pillars",
		beams = {
			{ kind = "Post", z = 0.2, x = -0.22 },
			{ kind = "Post", z = 0.2, x = 0.22 },
			{ kind = "Post", z = 0.5, x = -0.38 },
			{ kind = "Post", z = 0.5, x = 0 },
			{ kind = "Post", z = 0.5, x = 0.38 },
			{ kind = "Post", z = 0.8, x = -0.2 },
			{ kind = "Post", z = 0.8, x = 0.2 },
		},
	},
	{
		name = "Crawlspace",
		beams = {
			{ kind = "Wall", z = 0.2, y = { HIGH } },
			{ kind = "Wall", z = 0.45, y = { HIGH } },
			{ kind = "Wall", z = 0.9, y = { LOW } },
		},
	},
	{
		name = "Sweeper",
		beams = {
			{ kind = "Sweep", z = 0.5, y = { HIGH }, swing = 0.35, period = 5 },
			{ kind = "Post", z = 0.15, x = 0 },
		},
	},
	{
		name = "Hurdles",
		beams = {
			{ kind = "Wall", z = 0.2, y = { LOW } },
			{ kind = "Wall", z = 0.8, y = { LOW } },
		},
	},
	{
		name = "Zigzag",
		beams = {
			{ kind = "Gap", z = 0.2, y = FENCE, x = -0.3, gap = 6 },
			{ kind = "Gap", z = 0.5, y = FENCE, x = 0.3, gap = 6 },
			{ kind = "Gap", z = 0.8, y = FENCE, x = -0.3, gap = 6 },
		},
	},
	{
		name = "Mixed bag",
		beams = {
			{ kind = "Post", z = 0.1, x = -0.2 },
			{ kind = "Post", z = 0.1, x = 0.2 },
			{ kind = "Wall", z = 0.32, y = { LOW } },
			{ kind = "Wall", z = 0.9, y = { HIGH } },
		},
	},
	{
		name = "Twin sweepers",
		beams = {
			{ kind = "Sweep", z = 0.18, y = { LOW }, swing = 0.06, period = 4, phase = 0 },
			{ kind = "Sweep", z = 0.85, y = { LOW }, swing = 0.06, period = 4, phase = 0.5 },
		},
	},
	{
		name = "Fence and crawl",
		beams = {
			{ kind = "Gap", z = 0.3, y = FENCE, x = 0, gap = 7 },
			{ kind = "Post", z = 0.55, x = 0 },
			{ kind = "Wall", z = 0.8, y = { HIGH } },
		},
	},
} :: { Layout }

-- The layout a house gets (`offset` picks a different one for a mansion's second band).
function BreakInLasers.forHouse(houseId: number, offset: number?): Layout
	local count = #BreakInLasers.Layouts
	return BreakInLasers.Layouts[(houseId - 1 + (offset or 0)) % count + 1]
end

return BreakInLasers
