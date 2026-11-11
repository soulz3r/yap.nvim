local Component = require("nui-components.component")
local style = require("yap.ui.components.style")

local Panel = Component:extend("YapPanel")

function Panel:init(props, popup_options)
	props = style.with_defaults({
		direction = "column",
		flex = 1,
		is_focusable = false,
		border_style = "rounded",
		padding = {
			top = 0,
			right = 1,
			bottom = 0,
			left = 1,
		},
	}, props)

	Panel.super.init(self, props, popup_options)
end

return function(props, ...)
	local component_props = {}

	for key, value in pairs(props or {}) do
		component_props[key] = value
	end

	component_props.children = { ... }
	return Panel(component_props)
end
