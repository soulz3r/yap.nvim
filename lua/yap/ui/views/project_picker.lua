local M = {}

local registry = require("yap.project_registry")
local layout = require("yap.ui.layout")

local Discovery = require("yap.ui.views.project_picker.discovery")
local Preview = require("yap.ui.views.project_picker.preview")
local Keymaps = require("yap.ui.views.project_picker.keymaps")
local KeymapHints = require("yap.ui.components.keymap_hints")

local Components = require("yap.ui.components")

local Input = Components.Input
local SelectableList = Components.SelectableList
local Panel = Components.Panel
local Paragraph = Components.Paragraph
local Description = Components.Description

function M.open(opts)
	opts = opts or {}
	local n = require("nui-components")
	local entries = Discovery.collect(opts.projects_dir)
	local first = entries[1]
	local initial_readme = first and Preview.readme(first.root) or nil

	local preview_content = Preview.tree(first)
	local readme_content = initial_readme
	local current_mode = "normal"
	local keymap_actions = {}

	local renderer = layout.create_renderer(opts)

	local signal = n.create_signal({
		filtered = Discovery.nodes(n, entries),
		selected_path = first and first.root or "",
		preview_lines = preview_content,
		description_lines = initial_readme or "",
		has_readme = initial_readme ~= nil,
		has_results = #entries > 0,
		empty_message = #entries > 0 and "No matching C projects" or "No C projects found",
		hint_lines = KeymapHints.build({}),
	})


	local function refresh_content()
		signal.preview_lines = preview_content
		signal.description_lines = readme_content or ""
		signal.has_readme = readme_content ~= nil
		signal.hint_lines = KeymapHints.build(Keymaps.hints(keymap_actions, current_mode))
	end

	local function update_preview(project)
		signal.selected_path = project and project.root or ""
		preview_content = Preview.tree(project)
		readme_content = project and Preview.readme(project.root) or nil
		refresh_content()
	end

	local function choose(path)
		if type(path) ~= "string" or path == "" or vim.fn.isdirectory(path) ~= 1 then
			vim.notify("No C project is selected.", vim.log.levels.WARN, { title = "YAP" })
			return
		end

		vim.cmd.cd(vim.fn.fnameescape(path))
		registry.touch(path)
		renderer:close()
	end

	local function set_filter(query)
		local filtered = Discovery.filter(entries, query)

		signal.filtered = Discovery.nodes(n, filtered)
		signal.has_results = #filtered > 0
		signal.empty_message = #entries == 0 and "No C projects found" or "No matching C projects"

		update_preview(filtered[1])

		vim.schedule(function()
			local list = renderer:get_component_by_id("project-list")
			if not list or not list.winid or not vim.api.nvim_win_is_valid(list.winid) then
				return
			end

			local tree = list:get_tree()
			local node = tree and tree:get_node(1)
			if node then
				vim.api.nvim_win_set_cursor(list.winid, { 1, 0 })
				list:set_focused_node(node)
				list:get_actions().on_change(node)
			end
		end)
	end

	local function move_selection(direction)
		local list = renderer:get_component_by_id("project-list")
		if not list then
			return
		end

		local tree = list:get_tree()
		if not tree or #tree:get_nodes() == 0 then
			return
		end

		local actions = list:get_actions()
		if direction == "next" then
			actions.on_focus_next()
		else
			actions.on_focus_prev()
		end
	end

	local function selected_path()
		return signal.selected_path:get_value()
	end

	local function close()
		renderer:close()
	end

	local body = function()
		return n.rows({
			flex = 1,
			padding = {
				top = 1,
				right = 2,
				bottom = 1,
				left = 2,
			},
		},
			Input(n, {
				border_style = "rounded",
				border_label = "Search",
				on_change = function(value)
					set_filter(value)
				end,
				on_submit = function()
					choose(selected_path())
				end,
			}),
			n.columns({ flex = 1 },
				Panel({
					id = "project-list-panel",
					flex = 1,
					border_label = "Projects",
				},
					SelectableList(n, {
						data = signal.filtered,
						hidden = signal.has_results:negate(),
						on_change = function(node)
							if node then
								update_preview(Discovery.find(entries, node.path))
							end
						end,
						on_select = function(node)
							if node then
								choose(node.path)
							end
						end,
					}),
					Paragraph(n, {
						id = "project-empty-message",
						size = 1,
						lines = signal.empty_message,
						hidden = signal.has_results,
					})
				),
				n.rows({ flex = 1.35, padding = { left = 1 } },
					Paragraph(n, {
						id = "project-preview",
						border_style = "rounded",
						border_label = "Preview",
						flex = 1,
						truncate = true,
						lines = signal.preview_lines,
					})
				)
			),

			Description(n, {
				id = "project-description",
				lines = signal.description_lines,
				hidden = signal.has_readme:negate(),
			}),
			KeymapHints.new(n, {
				lines = signal.hint_lines,
			})
		)
	end

	keymap_actions = Keymaps.create({
		renderer = renderer,
		set_mode = function(mode)
			current_mode = mode
		end,
		refresh = refresh_content,
		move_selection = move_selection,
		selected_path = selected_path,
		choose = choose,
		close = close,
	})

	refresh_content()
	renderer:add_mappings(keymap_actions)

	renderer:render(body)
	return renderer
end

function M.setup(opts)
	M.opts = opts or {}
	vim.keymap.set("n", "<leader>pp", function()
		M.open(M.opts)
	end, {
		noremap = true,
		silent = true,
		desc = "Switch C project",
	})
end

return M
