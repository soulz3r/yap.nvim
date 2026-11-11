local Paragraph = require("yap.ui.components.paragraph")
local style = require("yap.ui.components.style")

return function(n, props)
	return Paragraph(n, style.with_defaults({
		id = "yap-description",
		border_style = "rounded",
		border_label = "Description",
		max_lines = 9,
		truncate = false,
	}, props))
end
