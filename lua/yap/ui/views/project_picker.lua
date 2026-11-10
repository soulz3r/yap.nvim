local M = {}

local registry = require("yap.project_registry")
local layout = require("yap.ui.layout")

local Input = require("yap.ui.components.input")
local SelectableList = require("yap.ui.components.selectable_list")
local style = require("yap.ui.components.style")

local markers = {
	".git",
	"build.sh",
	"build.bat",
	"build_all.sh",
	"build_all.bat",
	"compile_commands.json",
	"compile_flags.txt",
	"CMakeLists.txt",
	"Makefile",
}

local preview_limits = {
	depth = 3,
	entries = 60,
}

local function normalize(path)
	path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
	return vim.fn.has("win32") == 1 and path:lower() or path
end

local function is_c_project(root)
	if vim.fn.isdirectory(root) ~= 1 then
		return false
	end

	return #vim.fn.globpath(root, "**/*.c", false, true) > 0
end

local function collect_projects(projects_dir)
	local found = {}
	local seen = {}

	local function add(path)
		if type(path) ~= "string" or path == "" or vim.fn.isdirectory(path) ~= 1 then
			return
		end

		local root = vim.fs.root(path, markers) or path
		root = vim.fs.normalize(vim.fn.fnamemodify(root, ":p"))
		local key = normalize(root)

		if seen[key] or not is_c_project(root) then
			return
		end

		seen[key] = true
		local metadata = registry.get(root) or {}

		found[#found + 1] = {
			id = root,
			root = root,
			name = vim.fn.fnamemodify(root, ":t"),
			last_opened = metadata.last_opened or 0,
		}
	end

	for _, entry in ipairs(registry.list()) do
		add(entry.root)
	end

	if type(projects_dir) == "string" and vim.fn.isdirectory(projects_dir) == 1 then
		for name, kind in vim.fs.dir(projects_dir) do
			if kind == "directory" then
				add(projects_dir .. "/" .. name)
			end
		end
	end

	table.sort(found, function(a, b)
		if a.last_opened ~= b.last_opened then
			return a.last_opened > b.last_opened
		end
		return a.name:lower() < b.name:lower()
	end)

	return found
end

local function fuzzy_match(query, candidate)
	query = query:lower()
	candidate = candidate:lower()

	if query == "" then
		return true
	end

	local query_index = 1
	for index = 1, #candidate do
		if candidate:sub(index, index) == query:sub(query_index, query_index) then
			query_index = query_index + 1
			if query_index > #query then
				return true
			end
		end
	end

	return false
end

local function readme_for(root)
	for _, name in ipairs({ "README.md", "readme.md" }) do
		local path = root .. "/" .. name
		if vim.fn.filereadable(path) == 1 then
			local lines = vim.fn.readfile(path, "", 8)
			if #lines == 0 then
				lines = { "(README is empty)" }
			elseif #lines == 8 then
				lines[8] = "…"
			end
			return table.concat(lines, "\n")
		end
	end
end

local function preview_for(project)
	if not project then
		return "Select a project to preview its files."
	end

	local lines = { project.name .. "/" }
	local count = 0
	local skipped = false

	local function append_directory(path, prefix, depth)
		local entries = {}

		for name, kind in vim.fs.dir(path) do
			if name ~= ".git" then
				entries[#entries + 1] = {
					name = name,
					kind = kind,
				}
			end
		end

		table.sort(entries, function(a, b)
			local a_dir = a.kind == "directory"
			local b_dir = b.kind == "directory"
			if a_dir ~= b_dir then
				return a_dir
			end
			return a.name:lower() < b.name:lower()
		end)

		for index, entry in ipairs(entries) do
			if count >= preview_limits.entries then
				skipped = true
				return
			end

			count = count + 1
			local is_last = index == #entries
			local branch = is_last and "└── " or "├── "
			local child_prefix = prefix .. (is_last and "    " or "│   ")
			local is_directory = entry.kind == "directory"

			lines[#lines + 1] = prefix .. branch .. entry.name .. (is_directory and "/" or "")

			if is_directory and depth < preview_limits.depth then
				append_directory(vim.fs.joinpath(path, entry.name), child_prefix, depth + 1)
				if skipped then
					return
				end
			end
		end
	end

	append_directory(project.root, "", 1)

	if skipped then
		lines[#lines + 1] = "… more files"
	elseif count == 0 then
		lines[#lines + 1] = "└── (empty project)"
	end

	return table.concat(lines, "\n")
end

local function make_nodes(n, entries)
	local nodes = {}
	for _, project in ipairs(entries) do
		nodes[#nodes + 1] = n.node({
			id = project.root,
			path = project.root,
			text = project.name,
		})
	end
	return nodes
end

local function find_project(entries, root)
	for _, project in ipairs(entries) do
		if normalize(project.root) == normalize(root) then
			return project
		end
	end
end

local function hints_for(mode)
	if mode == "insert" then
		return "Esc  normal mode     Ctrl-N/P  navigate     Enter  open"
	end
	return "i  search     j/k or Ctrl-N/P  navigate     Enter  open     q  close"
end

local function description_lines(n, readme, hints, width)
	local lines = {}

	if readme then
		for _, line in ipairs(vim.split(readme, "\n", { plain = true })) do
			lines[#lines + 1] = n.line(line)
		end
	end

	local padding = math.max(0, width - vim.api.nvim_strwidth(hints))
	lines[#lines + 1] = n.line(string.rep(" ", padding), hints)

	return lines
end

function M.open(opts)
	opts = opts or {}
	local n = require("nui-components")
	local entries = collect_projects(opts.projects_dir)
	local first = entries[1]
	local initial_readme = first and readme_for(first.root) or nil

	local preview_content = preview_for(first)
	local readme_content = initial_readme
	local current_hints = hints_for("normal")

	local renderer = layout.create_renderer(opts)

	local signal = n.create_signal({
		filtered = make_nodes(n, entries),
		selected_path = first and first.root or "",
		preview_lines = preview_content,
		description_lines = description_lines(
			n,
			initial_readme,
			current_hints,
			math.max(1, renderer:get_size().width - 4)
		),
		has_results = #entries > 0,
		empty_message = #entries > 0 and "No matching C projects" or "No C projects found",
	})

	local function refresh_content()
		signal.preview_lines = preview_content
		signal.description_lines = description_lines(
			n,
			readme_content,
			current_hints,
			math.max(1, renderer:get_size().width - 4)
		)
	end

	local function update_preview(project)
		signal.selected_path = project and project.root or ""
		preview_content = preview_for(project)
		readme_content = project and readme_for(project.root) or nil
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
		local filtered = {}

		for _, project in ipairs(entries) do
			if fuzzy_match(query, project.name) or fuzzy_match(query, project.root) then
				filtered[#filtered + 1] = project
			end
		end

		signal.filtered = make_nodes(n, filtered)
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
				n.rows({ flex = 1 },
					SelectableList(n, {
						border_style = "rounded",
						border_label = "Projects",
						data = signal.filtered,
						hidden = signal.has_results:negate(),
						on_change = function(node)
							if node then
								update_preview(find_project(entries, node.path))
							end
						end,
						on_select = function(node)
							if node then
								choose(node.path)
							end
						end,
					}),
					n.paragraph(style.with_defaults({
						id = "project-empty-message",
						border_style = "rounded",
						border_label = "Projects",
						size = 1,
						is_focusable = false,
						align = "left",
						lines = signal.empty_message,
						hidden = signal.has_results,
					}))
				),
				n.rows({ flex = 1.35, padding = { left = 1 } },
					n.paragraph(style.with_defaults({
						id = "project-preview",
						border_style = "rounded",
						border_label = "Preview",
						flex = 1,
						is_focusable = false,
						align = "left",
						truncate = true,
						lines = signal.preview_lines,
					}))
				)
			),

			n.paragraph(style.with_defaults({
				id = "project-description",
				is_focusable = false,
				align = "left",
				max_lines = 9,
				truncate = false,
				lines = signal.description_lines,
			}))
		)
	end

	renderer:add_mappings({
		{
			mode = { "n" },
			key = "i",
			handler = function()
				local input = renderer:get_component_by_id("project-search")
				if not input then
					return
				end
				input:focus()
				current_hints = hints_for("insert")
				refresh_content()
				vim.schedule(function()
					if vim.api.nvim_win_is_valid(input.winid) then
						vim.cmd("startinsert")
					end
				end)
			end,
		},
		{
			mode = { "i" },
			key = "<Esc>",
			handler = function()
				current_hints = hints_for("normal")
				refresh_content()
				vim.schedule(function()
					local input = renderer:get_component_by_id("project-search")
					if input and vim.api.nvim_get_current_win() == input.winid then
						vim.cmd("stopinsert")
					end
				end)
			end,
		},
		{
			mode = { "n", "i" },
			key = "<C-n>",
			handler = function()
				move_selection("next")
			end,
		},
		{
			mode = { "n", "i" },
			key = "<C-p>",
			handler = function()
				move_selection("prev")
			end,
		},
		{
			mode = { "n" },
			key = "j",
			handler = function()
				move_selection("next")
			end,
		},
		{
			mode = { "n" },
			key = "k",
			handler = function()
				move_selection("prev")
			end,
		},
		{
			mode = { "n" },
			key = "q",
			handler = close,
		},
	})

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
