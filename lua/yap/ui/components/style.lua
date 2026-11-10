local M = {}

function M.with_defaults(defaults, props)
	local base = vim.tbl_deep_extend("force", {
		window = {
			highlight = {
				NormalFloat = "YapFloatNormal",
				FloatBorder = "YapFloatBorder",
			},
		},
	}, defaults or {})

	return vim.tbl_deep_extend("force", base, props or {})
end

return M
