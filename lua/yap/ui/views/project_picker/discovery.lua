local registry = require("yap.project_registry")

local M = {}

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

function M.collect(projects_dir)
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

function M.filter(entries, query)
	local filtered = {}

	for _, project in ipairs(entries) do
		if fuzzy_match(query, project.name) or fuzzy_match(query, project.root) then
			filtered[#filtered + 1] = project
		end
	end

	return filtered
end

function M.find(entries, root)
	for _, project in ipairs(entries) do
		if normalize(project.root) == normalize(root) then
			return project
		end
	end
end

function M.nodes(n, entries)
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

return M
