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
		local hints = self:get_props().hints
		local width = self:get_size().width - self:get_border_delta_size().width
		local padding = math.max(0, width - vim.api.nvim_strwidth(hints))
		local line = n.line(string.rep(" ", padding), hints)

		line:render(self.bufnr, -1, 1)
	end)
end

return function(props)
	return Footer(props)
end
