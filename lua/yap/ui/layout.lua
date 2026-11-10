local M = {}

function M.dimensions()
	local columns = vim.o.columns
	local lines = vim.o.lines

	return {
		width = math.max(1, math.min(columns - 4, math.max(56, math.floor(columns * 0.82)))),
		height = math.max(1, math.min(lines - 4, math.max(14, math.floor(lines * 0.72)))),
	}
end

function M.create_renderer(opts)
	opts = opts or {}
	local size = M.dimensions()
	local n = require("nui-components")
	local renderer = n.create_renderer({
		width = opts.width or size.width,
		height = opts.height or size.height,
		position = "50%",
		relative = "editor",
	})

	local origin = renderer:get_origin_winid()

	renderer:on_unmount(function()
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(origin) then
				vim.api.nvim_set_current_win(origin)
			end
		end)
	end)

	return renderer
end

return M
