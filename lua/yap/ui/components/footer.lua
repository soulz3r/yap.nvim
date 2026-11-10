local Component = require("nui-components.component")
local n = require("nui-components")

local Footer = Component:extend("Footer")

function Footer:init(props, popup_options)
	Footer.super.init(
		self,
		vim.tbl_deep_extend("force", {
			hints = "",
			is_focusable = false,
			border_style = "none",
		}, props or {}),
		popup_options
	)
end

function Footer:prop_types()
	return {
		hints = "string",
	}
end

function Footer:get_line()
	return n.line(self:get_props().hints)
end

function Footer:on_layout()
	return {
		height = 1,
		width = self:get_line():width(),
	}
end

function Footer:on_update()
	self:modify_buffer_content(function()
		local line = self:get_line()
		local width = self:get_size().width - self:get_border_delta_size().width
		local padding = math.max(0, width - line:width())

		if padding > 0 then
			line = n.line(string.rep(" ", padding), line)
		end

		line:render(self.bufnr, -1, 1)
	end)
end

return function(props)
	return Footer(props)
end
