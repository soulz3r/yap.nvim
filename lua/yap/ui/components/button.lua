local style = require("yap.ui.components.style")

local function normalize_padding(padding)
	if type(padding) == "number" then
		return {
			top = padding,
			right = padding,
			bottom = padding,
			left = padding,
		}
	end

	if type(padding) == "table" then
		return vim.tbl_deep_extend("force", {
			top = 0,
			right = 0,
			bottom = 0,
			left = 0,
		}, padding)
	end

	return {
		top = 0,
		right = 0,
		bottom = 0,
		left = 0,
	}
end

return function(n, props)
	props = vim.deepcopy(props or {})
	props.padding = normalize_padding(props.padding)

	return n.button(style.with_defaults({
		flex = 1,
		size = 1,
		align = "center",
		is_focusable = false,
		is_active = false,
		press_key = {},
		on_press = function() end,
		border_style = "none",
		padding = {
			top = 0,
			right = 0,
			bottom = 0,
			left = 0,
		},
		window = {
			highlight = {
				NormalFloat = "YapFloatNormal",
				FloatBorder = "YapFloatBorder",
			},
		},
	}, props))
end
