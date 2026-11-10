local M = {}

M.border = {
	{ "╭", "YapFloatBorder" }, { "─", "YapFloatBorder" },
	{ "╮", "YapFloatBorder" }, { "│", "YapFloatBorder" },
	{ "╯", "YapFloatBorder" }, { "─", "YapFloatBorder" },
	{ "╰", "YapFloatBorder" }, { "│", "YapFloatBorder" },
}

M.winhighlight = table.concat({
	"Normal:YapFloatNormal",
	"FloatBorder:YapFloatBorder",
	"FloatTitle:YapFloatTitle",
}, ",")

local hidden_windows, previous_laststatus = {}, nil

local default_highlights = {
	normal = { link = "NormalFloat" },
	border = { link = "FloatBorder" },
	title = { link = "FloatTitle" },
	section_title = { link = "Title" },
	muted = { link = "Comment" },
	success = { link = "DiagnosticOk" },
	warning = { link = "DiagnosticWarn" },
	error = { link = "DiagnosticError" },
}

local highlight_groups = {
	normal = "YapFloatNormal",
	border = "YapFloatBorder",
	title = "YapFloatTitle",
	section_title = "YapSectionTitle",
	muted = "YapMuted",
	success = "YapSuccess",
	warning = "YapWarning",
	error = "YapError",
}

local function apply_highlights(highlights)
	for name, group in pairs(highlight_groups) do
		vim.api.nvim_set_hl(0, group, highlights[name])
	end
end

function M.apply(win)
	if vim.api.nvim_win_is_valid(win) then
		vim.wo[win].winhighlight = M.winhighlight
	end
end

function M.hide_statusline(win)
	if not vim.api.nvim_win_is_valid(win) or hidden_windows[win] then
		return
	end

	if next(hidden_windows) == nil then
		previous_laststatus = vim.o.laststatus
		vim.o.laststatus = 0
	end

	hidden_windows[win] = true
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			hidden_windows[win] = nil
			if next(hidden_windows) == nil and previous_laststatus ~= nil then
				vim.o.laststatus = previous_laststatus
				previous_laststatus = nil
			end
		end,
	})
end

---@param highlights table|nil
function M.setup(highlights)
	local configured = vim.tbl_deep_extend("force", {}, default_highlights, highlights or {})
	local group = vim.api.nvim_create_augroup("YapHighlights", { clear = true })

	apply_highlights(configured)
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			apply_highlights(configured)
		end,
	})
end

function M.centered(width, height, title)
	local columns, lines = vim.o.columns, vim.o.lines
	width = math.max(1, math.min(width or math.floor(columns * 0.72), columns - 4))
	height = math.max(1, math.min(height or math.floor(lines * 0.62), lines - 4))

	return {
		relative = "editor",
		style = "minimal",
		border = M.border,
		title = title and (" " .. title .. " ") or nil,
		title_pos = "center",
		width = width,
		height = height,
		row = math.max(0, math.floor((lines - height) / 2) - 1),
		col = math.max(0, math.floor((columns - width) / 2)),
	}
end

function M.open_text(lines, title, opts)
	opts = opts or {}
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = opts.filetype or "text"
	vim.bo[buf].modifiable = false

	local width = opts.width or math.floor(vim.o.columns * 0.72)
	local height = opts.height or math.min(#lines + 2, math.floor(vim.o.lines * 0.62))
	local win = vim.api.nvim_open_win(buf, true, M.centered(width, height, title))
	vim.wo[win].wrap = opts.wrap == true
	vim.wo[win].cursorline = true
	M.apply(win)

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true, desc = "Close YAP window" })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true, desc = "Close YAP window" })
	return buf, win
end

return M
