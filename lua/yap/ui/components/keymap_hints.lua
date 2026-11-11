local Line = require("nui.line")
local Paragraph = require("yap.ui.components.paragraph")
local style = require("yap.ui.components.style")

local M = {}

function M.build(hints)
	local line = Line()

	for index, hint in ipairs(hints) do
		if index > 1 then
			line:append("   ", "Normal")
		end

		line:append(hint.key, "NuiComponentsButtonActive")
		line:append(" ", "Normal")
		line:append(hint.label, "YapMuted")
	end

	return { line }
end

function M.new(n, props)
	return Paragraph(n, style.with_defaults({
		id = "project-keymap-hints",
		flex = 1,
		size = 1,
		is_focusable = false,
		border_style = "none",
		padding = 0,
		truncate = true,
		window = {
			highlight = {
				NormalFloat = "Normal",
				FloatBorder = "Normal",
			},
		},
	}, props))
end

return M
