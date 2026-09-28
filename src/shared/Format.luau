--!strict
-- Text formatting for money, Cred, percentages and timers.

local Format = {}

local function withCommas(n: number): string
	local digits = tostring(n)
	local grouped = (digits:reverse():gsub("(%d%d%d)", "%1,")):reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	return grouped
end

function Format.number(amount: number): string
	local n = math.floor(math.abs(amount) + 0.5)
	local sign = if amount < 0 then "-" else ""
	return sign .. withCommas(n)
end

function Format.money(amount: number): string
	local n = math.floor(math.abs(amount) + 0.5)
	local sign = if amount < 0 then "-" else ""
	if n >= 1_000_000 then
		local text = string.format("%.2f", n / 1_000_000)
		text = (text:gsub("0+$", ""))
		text = (text:gsub("%.$", ""))
		return `{sign}${text}M`
	end
	return `{sign}${withCommas(n)}`
end

function Format.cred(amount: number): string
	return `{Format.number(amount)} Cred`
end

function Format.percent(fraction: number): string
	return `{math.floor(fraction * 100 + 0.5)}%`
end

function Format.clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

-- Race times to a tenth: 0:46.2
function Format.raceTime(seconds: number): string
	local tenths = math.max(0, math.floor(seconds * 10 + 0.5))
	local minutes = tenths // 600
	return string.format("%d:%04.1f", minutes, (tenths - minutes * 600) / 10)
end

-- 1st, 2nd, 3rd, 4th...
function Format.ordinal(n: number): string
	local lastTwo = n % 100
	local suffix = "th"
	if lastTwo < 11 or lastTwo > 13 then
		local last = n % 10
		suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	end
	return `{n}{suffix}`
end

return Format
