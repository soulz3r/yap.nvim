local style = require("yap.ui.components.style")

return function(n, props)
	return n.paragraph(style.with_defaults({
		id = "project-keymap-hints",
		size = 1,
		is_focusable = false,
		align = "right",
		max_lines = 1,
		truncate = true,
	}, props))
end
