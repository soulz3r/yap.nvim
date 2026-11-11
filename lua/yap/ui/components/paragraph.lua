local Line = require("nui.line")
local style = require("yap.ui.components.style")

return function(n, props)
	props = vim.deepcopy(props or {})
	local prepare_lines = props.prepare_lines

	props.prepare_lines = function(lines, component)
		if type(lines[1]) == "string" then
			lines = vim.tbl_map(function(text)
				local line = Line()
				line:append(text)
				return line
			end, lines)
		end

		if prepare_lines then
			return prepare_lines(lines, component)
		end

		return lines
	end

	return n.paragraph(style.with_defaults({
		id = "yap-paragraph",
		is_focusable = false,
		align = "left",
		truncate = true,
	}, props))
end
