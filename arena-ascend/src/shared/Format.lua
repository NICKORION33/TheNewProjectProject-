local Format = {}

-- 1234567 -> "1,234,567"
function Format.Commas(n)
	local s = tostring(math.floor(n))
	local sign, digits = s:match("^(-?)(%d+)$")
	if not digits then
		return s
	end
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return sign .. out
end

-- 1234567 -> "1.2M"
function Format.Short(n)
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return Format.Commas(n)
end

function Format.Percent(fraction)
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

return Format
