local M = {}

function M.dimensions()
	local columns = vim.o.columns
	local lines = vim.o.lines

	return {
		width = math.max(1, math.min(columns - 4, math.max(56, math.floor(columns * 0.82)))),
		height = math.max(1, math.min(lines - 4, math.max(14, math.floor(lines * 0.72)))),
	}
end

local function resolve_position(value, available, size)
	if type(value) == "number" then
		return value
	end

	if type(value) == "string" then
		local percentage = tonumber(value:match("^([%d%.]+)%%$"))
		if percentage then
			return math.floor((available - size) * percentage / 100)
		end

		return tonumber(value) or 0
	end

	return 0
end

function M.get_bounds(renderer)
	local options = renderer:get_layout_options()
	local size = renderer:get_size()

	if options.relative ~= "editor" then
		return nil
	end

	local position = options.position
	if type(position) == "string" then
		position = { row = position, col = position }
	end

	position = position or {}

	local editor_height = math.max(1, vim.o.lines - vim.o.cmdheight)

	return {
		row = resolve_position(position.row, editor_height, size.height),
		col = resolve_position(position.col, vim.o.columns, size.width),
		width = size.width,
		height = size.height,
	}
end

function M.relative_position(renderer, edge, height, gap)
	local bounds = M.get_bounds(renderer)
	if not bounds then
		return nil
	end

	local row

	if edge == "bottom" then
		row = bounds.row + bounds.height + (gap or 0)
	elseif edge == "top" then
		row = bounds.row - height - (gap or 0)
	else
		return nil
	end

	local editor_height = math.max(1, vim.o.lines - vim.o.cmdheight)

	return {
		row = math.max(0, math.min(row, editor_height - height)),
		col = math.max(0, bounds.col),
	}
end

function M.create_renderer(opts)
	opts = opts or {}
	local size = M.dimensions()
	local n = require("nui-components")
	local renderer = n.create_renderer({
		width = opts.width or size.width,
		height = opts.height or size.height,
		position = opts.position or "50%",
		relative = opts.relative or "editor",
	})

	local origin = renderer:get_origin_winid()

	renderer:on_unmount(function()
		if opts.on_unmount then
			opts.on_unmount(renderer)
		end

		vim.schedule(function()
			if vim.api.nvim_win_is_valid(origin) then
				vim.api.nvim_set_current_win(origin)
			end
		end)
	end)

	return renderer
end

return M
