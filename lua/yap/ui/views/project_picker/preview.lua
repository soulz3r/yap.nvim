local M = {}

local limits = {
	depth = 3,
	entries = 60,
}

function M.readme(root)
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

function M.tree(project)
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
			if count >= limits.entries then
				skipped = true
				return
			end

			count = count + 1
			local is_last = index == #entries
			local branch = is_last and "└── " or "├── "
			local child_prefix = prefix .. (is_last and "    " or "│   ")
			local is_directory = entry.kind == "directory"

			lines[#lines + 1] = prefix .. branch .. entry.name .. (is_directory and "/" or "")

			if is_directory and depth < limits.depth then
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

return M
