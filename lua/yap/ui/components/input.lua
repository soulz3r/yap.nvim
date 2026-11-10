local style = require("yap.ui.components.style")

return function(n, props)
	return n.prompt(style.with_defaults({
		id = "project-search",
		size = 1,
		autofocus = true,
		is_focusable = true,
		max_lines = 1,
		prefix = "  ",
		placeholder = "Search C projects...",
		border_label = {
			text = "Search",
			align = "left",
		},
		border_style = "rounded",
	}, props))
end
