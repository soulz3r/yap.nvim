local M = {}
M.config = require("yap.config")
M.projects = require("yap.projects")
M.project_registry = require("yap.project_registry")
M.c = require("yap.c")
local defaults = { telescope = true, keymaps = true, projects_dir = M.config.projects_dir }
function M.setup(opts)
	local config = vim.tbl_deep_extend("force", defaults, opts or {})
	require("yap.ui").setup()
	M.c.setup()
	if config.telescope then require("yap.telescope").setup(config) end
	return M
end
return M
