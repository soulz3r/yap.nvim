local M = {}

function M.create(ctx)
	return {
		{
			mode = { "n" },
			key = "i",
			hint = { key = "i", label = "search" },
			handler = function()
				local input = ctx.renderer:get_component_by_id("project-search")
				if not input then
					return
				end

				ctx.set_mode("insert")
				ctx.refresh()

				input:focus()
				vim.schedule(function()
					if input.winid and vim.api.nvim_win_is_valid(input.winid) then
						vim.cmd("startinsert")
					end
				end)
			end,
		},
		{
			mode = { "i" },
			key = "<Esc>",
			hint = { key = "Esc", label = "normal mode" },
			handler = function()
				ctx.set_mode("normal")
				ctx.refresh()

				vim.schedule(function()
					local input = ctx.renderer:get_component_by_id("project-search")
					if input and input.winid and vim.api.nvim_get_current_win() == input.winid then
						vim.cmd("stopinsert")
					end
				end)
			end,
		},
		{
			mode = { "n", "i" },
			key = "<C-n>",
			hint = { key = "Ctrl-N/P", label = "navigate" },
			handler = function()
				ctx.move_selection("next")
			end,
		},
		{
			mode = { "n", "i" },
			key = "<C-p>",
			handler = function()
				ctx.move_selection("prev")
			end,
		},
		{
			mode = { "n" },
			key = "j",
			hint = { key = "j/k", label = "navigate" },
			handler = function()
				ctx.move_selection("next")
			end,
		},
		{
			mode = { "n" },
			key = "k",
			handler = function()
				ctx.move_selection("prev")
			end,
		},
		{
			mode = { "n" },
			key = "<CR>",
			hint = { key = "Enter", label = "open" },
			handler = function()
				ctx.choose(ctx.selected_path())
			end,
		},
		{
			mode = { "n" },
			key = "q",
			hint = { key = "q", label = "close" },
			handler = ctx.close,
		},
	}
end

function M.hints(actions, mode)
	local active_mode = mode == "insert" and "i" or "n"
	local hints = {}

	for _, action in ipairs(actions) do
		if action.hint and vim.tbl_contains(action.mode, active_mode) then
			hints[#hints + 1] = action.hint
		end
	end

	return hints
end

return M
