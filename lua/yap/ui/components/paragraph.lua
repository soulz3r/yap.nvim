local style = require("yap.ui.components.style")

return function(n, props)
	return n.paragraph(style.with_defaults({
		id = "yap-paragraph",
		is_focusable = false,
		align = "left",
		truncate = true,
	}, props))
end
