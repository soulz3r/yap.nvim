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
	command = { link = "Identifier" },
	path = { link = "Directory" },
	phase = { link = "Title" },
	metadata = { link = "Comment" },
	diagnostic = { link = "DiagnosticInfo" },
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
	command = "YapCommand",
	path = "YapPath",
	phase = "YapPhase",
	metadata = "YapMetadata",
	diagnostic = "YapDiagnostic",
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
	local configured = vim.deepcopy(default_highlights)

	for name, options in pairs(highlights or {}) do
		configured[name] = vim.deepcopy(options)
	end
	local group = vim.api.nvim_create_augroup("YapHighlights", { clear = true })

	apply_highlights(configured)
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			apply_highlights(configured)
		end,
	})
end

---@param buf integer
---@param opts table|nil
---@return table renderer, integer win
function M.open_buffer(buf, opts)
	opts = opts or {}

	local n = require("nui-components")
	local renderer = n.create_renderer({
		width = opts.width or math.floor(vim.o.columns * 0.72),
		height = opts.height or math.floor(vim.o.lines * 0.62),
		position = "50%",
		relative = "editor",
	})

	renderer:render(function()
		return n.buffer({
			id = "yap-buffer",
			buf = buf,
			flex = 1,
			autoscroll = opts.autoscroll == true,
			linebreak = opts.wrap ~= false,
			border_label = opts.title and {
				text = opts.title,
				align = "center",
			} or nil,
			border_style = "rounded",
			window = {
				highlight = {
					Normal = "YapFloatNormal",
					FloatBorder = "YapFloatBorder",
				},
			},
		})
	end)

	local component = renderer:get_component_by_id("yap-buffer")
	local win = component and component.winid
	if not win or not vim.api.nvim_win_is_valid(win) then
		renderer:close()
		error("YAP: NuiComponents did not create the buffer window")
	end

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].statuscolumn = ""
	vim.wo[win].wrap = opts.wrap ~= false
	vim.wo[win].cursorline = opts.cursorline ~= false

	return renderer, win
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

	local renderer, win = M.open_buffer(buf, {
		width = opts.width or math.floor(vim.o.columns * 0.72),
		height = opts.height or math.min(#lines + 2, math.floor(vim.o.lines * 0.62)),
		title = title,
		wrap = opts.wrap == true,
	})

	local function close()
		renderer:close()
	end

	vim.keymap.set("n", "q", close, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Close YAP window",
	})
	vim.keymap.set("n", "<Esc>", close, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Close YAP window",
	})

	return buf, win, renderer
end

return M
