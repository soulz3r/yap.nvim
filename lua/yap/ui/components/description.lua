local style = require("yap.ui.components.style")

return function(n, props)
	return n.paragraph(style.with_defaults({
		id = "project-readme",
		flex = 1,
		is_focusable = false,
		align = "left",
		max_lines = 22,
		truncate = false,
	}, props))
end
