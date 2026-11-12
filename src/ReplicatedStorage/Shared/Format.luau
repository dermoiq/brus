--!strict

-- Deep rebirths reach very large numbers, so the suffix list runs to 1e63.
local SUFFIXES = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
	"Sxd",
	"Spd",
	"Ocd",
	"Nod",
	"Vg",
}

local Format = {}

-- 999 -> "999", 1234 -> "1.2K", 15_600_000 -> "15.6M"
function Format.Abbreviate(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text = if scaled < 100
		then string.format("%.1f", math.floor(scaled * 10) / 10)
		else tostring(math.floor(scaled))
	text = (string.gsub(text, "%.0$", ""))
	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.Multiplier(value: number): string
	local text = (string.gsub(string.format("%.2f", value), "%.?0+$", ""))
	return "x" .. text
end

function Format.Percent(value: number): string
	return tostring(math.floor(value * 100 + 0.5)) .. "%"
end

return Format
