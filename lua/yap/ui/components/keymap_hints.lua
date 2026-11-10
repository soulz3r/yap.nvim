local Line = require("nui.line")
local style = require("yap.ui.components.style")

local function normalize_lines(lines)
	local normalized = {}

	for _, value in ipairs(lines or {}) do
		if type(value) == "string" then
			local line = Line()
			line:append(value)
			normalized[#normalized + 1] = line
		elseif type(value) == "table" and type(value.width) == "function" then
			normalized[#normalized + 1] = value
		end
	end

	return normalized
end

return function(n, props)
	return n.paragraph(style.with_defaults({
		id = "project-keymap-hints",
		size = 1,
		is_focusable = false,
		align = "left",
		max_lines = 1,
		truncate = true,
		prepare_lines = normalize_lines,
	}, props))
end
