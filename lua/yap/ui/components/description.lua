local style = require("yap.ui.components.style")

return function(n, props)
	return n.paragraph(style.with_defaults({
		id = "project-readme",
		is_focusable = false,
		align = "left",
		max_lines = 8,
		truncate = false,
	}, props))
end
