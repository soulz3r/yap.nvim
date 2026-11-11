local Button = require("yap.ui.components.button")
local style = require("yap.ui.components.style")

local function make_button(n, hint, index)
	local props = vim.deepcopy(hint)
	local key = props.key
	local label = props.label or ""

	props.key = nil
	props.label = (key and (key .. "  ") or "") .. label
	props.id = props.id or ("yap-keymap-hint-" .. index)
	props.flex = props.flex or math.max(1, #props.label + 2)

	return Button(n, props)
end

return function(n, hints, props)
	local children = {}

	for index, hint in ipairs(hints or {}) do
		children[#children + 1] = make_button(n, hint, index)
	end

	return n.columns(style.with_defaults({
		id = "yap-keymap-hints",
		flex = 1,
		size = 1,
		gap = 1,
	}, props), unpack(children))
end
