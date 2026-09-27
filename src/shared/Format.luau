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

return Format
