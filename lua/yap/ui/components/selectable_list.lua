local style = require("yap.ui.components.style")

return function(n, props)
	return n.tree(style.with_defaults({
		id = "project-list",
		flex = 1,
		is_focusable = false,
		autofocus = false,
		border_style = "none",
		prepare_node = function(node, line)
			line:append("  " .. (node.text or node.path or ""))
			return line
		end,
	}, props))
end
