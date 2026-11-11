local M = {}

-- Public modules. Loading YAP does not configure keymaps, highlights, or
-- integrations automatically. The user decides what gets initialized.
M.config = require("yap.config")
M.projects = require("yap.projects")
M.project_registry = require("yap.project_registry")
M.c = require("yap.c")

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}

	-- Explicit setup only. No implicit defaults are merged here.
	--
	-- PSEUDOCODE:
	--
	-- if opts.ui then
	--     require("yap.ui").setup(opts.ui.highlights)
	-- end
	--
	-- if opts.c_tools then
	--     M.c.setup()
	-- end
	--
	-- if opts.telescope then
	--     require("yap.telescope").setup(opts.telescope)
	-- end
	--
	-- Future UI manager registration belongs here only if the user opts in.
	-- Project detection and project operations remain available through
	-- M.projects without requiring UI initialization.

	return M
end

return M
