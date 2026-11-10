local M = {}
M.config = require("yap.config")
M.projects = require("yap.projects")
M.project_registry = require("yap.project_registry")
M.c = require("yap.c")
local defaults = { telescope = false, keymaps = true, projects_dir = M.config.projects_dir, highlights = {} }
function M.setup(opts)
	local config = vim.tbl_deep_extend("force", defaults, opts or {})
	require("yap.ui").setup(config.highlights)
	M.c.setup()

	if config.telescope then
		require("yap.telescope").setup(config)
	end

	if config.keymaps ~= false then
		M.project_picker = require("yap.ui.views.project_picker")
		M.project_picker.setup(config)
	end

	return M
end
return M
