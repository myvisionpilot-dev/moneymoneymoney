-- Lists parts whose faces flicker against each other (z-fighting): two faces in the same plane,
-- facing the same way and overlapping. Run in Edit mode (command bar or MCP) after building the
-- town. "DIFF" rows look different (colour or material) and will visibly flicker; "same" rows
-- are identical surfaces and can't be seen. Bottoms resting on the ground are skipped.
local root = workspace:FindFirstChild("Map") or workspace

local parts = {}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 and not d:IsA("Terrain") then
		table.insert(parts, d)
	end
end
local base = workspace:FindFirstChild("Baseplate")
if base and root ~= workspace then
	table.insert(parts, base)
end

-- Flat faces: a block's six, a wedge's flat ones, a cylinder's two ends (as squares).
local function faces(p)
	local list = {}
	local shape = if p:IsA("Part") then p.Shape else nil
	if shape == Enum.PartType.Ball or not (p:IsA("Part") or p:IsA("WedgePart")) then
		return list
	end
	local cf, s = p.CFrame, p.Size
	local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local half = { s.X / 2, s.Y / 2, s.Z / 2 }
	for i = 1, 3 do
		if not (shape == Enum.PartType.Cylinder and i ~= 1) then
			for _, sign in { -1, 1 } do
				local slope = p:IsA("WedgePart") and ((i == 2 and sign == 1) or (i == 3 and sign == -1))
				local n = axes[i] * sign
				local c = cf.Position + n * half[i]
				if not slope and not (n.Y < -0.99 and c.Y < 0.6) then
					local j, k = i % 3 + 1, (i + 1) % 3 + 1
					table.insert(list, { n = n, c = c, u = axes[j], v = axes[k], hu = half[j], hv = half[k] })
				end
			end
		end
	end
	return list
end

local function overlap(f1, f2)
	local minU, maxU, minV, maxV = math.huge, -math.huge, math.huge, -math.huge
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			local corner = f2.c + f2.u * f2.hu * a + f2.v * f2.hv * b - f1.c
			local cu, cv = corner:Dot(f1.u), corner:Dot(f1.v)
			minU, maxU = math.min(minU, cu), math.max(maxU, cu)
			minV, maxV = math.min(minV, cv), math.max(maxV, cv)
		end
	end
	local ou = math.min(maxU, f1.hu) - math.max(minU, -f1.hu)
	local ov = math.min(maxV, f1.hv) - math.max(minV, -f1.hv)
	if ou <= 0.01 or ov <= 0.01 then
		return 0, nil
	end
	local mu = (math.min(maxU, f1.hu) + math.max(minU, -f1.hu)) / 2
	local mv = (math.min(maxV, f1.hv) + math.max(minV, -f1.hv)) / 2
	return ou * ov, f1.c + f1.u * mu + f1.v * mv
end

-- Only compare parts whose bounding boxes touch (a grid of 24-stud cells).
local CELL = 24
local grid, boxes = {}, {}
for index, p in parts do
	local cf, s = p.CFrame, p.Size
	local extent = Vector3.new(
		math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
		math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
		math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
	)
	local lo, hi = cf.Position - extent / 2 - Vector3.one * 0.05, cf.Position + extent / 2 + Vector3.one * 0.05
	boxes[index] = { lo, hi }
	if p ~= base then
		for gx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for gz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				local key = `{gx},{gz}`
				grid[key] = grid[key] or {}
				table.insert(grid[key], index)
			end
		end
	end
end

local groups, seen = {}, {}
local function check(i, j)
	local a, b = parts[i], parts[j]
	local ba, bb = boxes[i], boxes[j]
	for axis = 1, 3 do
		local key = if axis == 1 then "X" elseif axis == 2 then "Y" else "Z"
		if ba[2][key] < bb[1][key] or bb[2][key] < ba[1][key] then
			return
		end
	end
	for _, f1 in faces(a) do
		for _, f2 in faces(b) do
			if f1.n:Dot(f2.n) > 0.999 and math.abs((f2.c - f1.c):Dot(f1.n)) < 0.02 then
				local area, at = overlap(f1, f2)
				if area > 0.02 then
					local n1, n2 = a.Name:gsub("%d+$", "#"), b.Name:gsub("%d+$", "#")
					if n1 > n2 then
						n1, n2 = n2, n1
					end
					local same = a.Color == b.Color and a.Material == b.Material
					local key = `{if same then "same" else "DIFF"} {n1} / {n2}`
					local group = groups[key] or { count = 0, at = at }
					group.count += 1
					groups[key] = group
				end
			end
		end
	end
end

for index, p in parts do
	if p ~= base then
		local lo, hi = boxes[index][1], boxes[index][2]
		for gx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for gz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				for _, other in grid[`{gx},{gz}`] or {} do
					local key = `{index}:{other}`
					if other > index and not seen[key] then
						seen[key] = true
						check(index, other)
					end
				end
			end
		end
		if base then
			check(index, #parts)
		end
	end
end

local lines = {}
for key, group in groups do
	table.insert(
		lines,
		string.format("%s  x%d  e.g. (%.1f, %.2f, %.1f)", key, group.count, group.at.X, group.at.Y, group.at.Z)
	)
end
table.sort(lines)
return `{#parts} parts checked\n{table.concat(lines, "\n")}`
