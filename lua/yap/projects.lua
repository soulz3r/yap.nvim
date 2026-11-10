-- lua/soul/core/projects.lua
local M = {}

local paths = require("yap.config")
local registry = require("yap.project_registry")

local root_markers = {
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

local active_job
local last_runs = {}

local function run_records_path()
	local directory = vim.fn.stdpath("data") .. "/yap/project-runs"
	vim.fn.mkdir(directory, "p")

	local platform = paths.is_windows and "windows" or "unix"
	return directory .. "/" .. platform .. ".json"
end

local function load_run_records()
	local path = run_records_path()

	if vim.fn.filereadable(path) ~= 1 then
		local platform = paths.is_windows and "windows" or "unix"
		local legacy = vim.fn.stdpath("data") .. "/soul/project-runs/" .. platform .. ".json"
		if vim.fn.filereadable(legacy) == 1 then path = legacy else return {} end
	end

	local lines = vim.fn.readfile(path)
	if #lines == 0 then
		return {}
	end

	local ok, saved = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok or type(saved) ~= "table" then
		return {}
	end

	-- Migrate the previous single-project record format.
	if type(saved.file) == "string" and type(saved.root) == "string" then
		return {
			[vim.fs.normalize(saved.root)] = saved,
		}
	end

	return saved
end

local function save_run_records()
	local ok, encoded = pcall(vim.json.encode, last_runs)
	if not ok then
		return false
	end

	return vim.fn.writefile({ encoded }, run_records_path()) == 0
end

last_runs = load_run_records()

local function project_root(path)
	path = vim.fn.fnamemodify(path or vim.fn.getcwd(), ":p")

	if vim.fn.isdirectory(path) ~= 1 then
		path = vim.fs.dirname(path)
	end

	return vim.fs.root(path, root_markers) or path
end

local function stop_active_job()
	if not active_job then
		return false
	end

	local job = active_job
	local stopped = vim.fn.jobstop(job)

	if stopped > 0 then
		return true
	end

	active_job = nil
	return false
end

local function list_build_scripts(root)
	local patterns = paths.is_windows and { "build*.bat", "build*.sh" } or { "build*.sh" }
	local found = {}

	for _, pattern in ipairs(patterns) do
		for _, file in ipairs(vim.fn.globpath(root, pattern, false, true)) do
			if vim.fn.filereadable(file) == 1 then
				found[#found + 1] = vim.fn.fnamemodify(file, ":t")
			end
		end
	end

	table.sort(found)
	return found
end

local function build_script(root, selected)
	if selected and vim.fn.filereadable(root .. "/" .. selected) == 1 then
		return selected
	end

	local scripts = paths.is_windows
		and { "build_all.bat", "build.bat", "build_all.sh", "build.sh" }
		or { "build_all.sh", "build.sh" }

	for _, name in ipairs(scripts) do
		if vim.fn.filereadable(root .. "/" .. name) == 1 then
			return name
		end
	end
end

local function clean_script(root)
	local scripts = paths.is_windows
		and { "clean_all.bat", "clean.bat", "clean_all.sh", "clean.sh" }
		or { "clean_all.sh", "clean.sh" }

	for _, name in ipairs(scripts) do
		if vim.fn.filereadable(root .. "/" .. name) == 1 then
			return name
		end
	end
end

local function script_command(script)
	if script:match("%.bat$") then
		local cmd = vim.fn.exepath("cmd.exe")
		if cmd == "" then
			cmd = "cmd.exe"
		end

		return { cmd, "/d", "/c", "call", script }
	end

	local shell = vim.fn.exepath("bash")
	if shell == "" then
		shell = vim.fn.exepath("sh")
	end

	if shell == "" then
		return nil
	end

	return { shell, "./" .. script }
end

local function open_output(root, title)
	local floats = require("yap.ui")
	local output_lines = {}
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.max(1, math.min(vim.o.columns - 4, math.floor(vim.o.columns * 0.82)))
	local height = math.max(1, math.min(vim.o.lines - 4, math.floor(vim.o.lines * 0.72)))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = floats.border,
		title = " " .. title .. " ",
		title_pos = "center",
	})

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "project-output"
	vim.bo[buf].swapfile = false
	vim.bo[buf].readonly = true
	vim.bo[buf].modifiable = false

	require("yap.ui").hide_statusline(win)

	vim.wo[win].wrap = true
	vim.wo[win].cursorline = true
	floats.apply(win)

	local function apply_semantic_highlight(line, row)
		local trimmed = vim.trim(line)
		local group

		if trimmed:match("^%$ ") or trimmed:match("^Command:") then
			group = "YapCommand"
		elseif trimmed:match("^Project:") or trimmed:match("^Root:") then
			group = "YapPath"
		elseif trimmed:match("^Build script:") or trimmed:match("^Clean script:")
			or trimmed:match("^Executable:") or trimmed:match("^Directory:")
		then
			group = "YapPath"
		elseif trimmed:match("^Duration:") or trimmed:match("^Exit code:")
			or trimmed:match("^Arguments:") or trimmed:match("^Platform:")
		then
			group = "YapMetadata"
		elseif trimmed:match("^BUILD$") or trimmed:match("^CLEAN$")
			or trimmed:match("^EXECUTION$") or trimmed:match("^PROJECT$")
		then
			group = "YapPhase"
		elseif trimmed:match("succeeded") or trimmed:match("successfully")
			or trimmed:match("^Build completed")
		then
			group = "YapSuccess"
		elseif trimmed:match("failed") or trimmed:match("Could not")
			or trimmed:match("No supported") or trimmed:match("No .* found")
		then
			group = "YapError"
		elseif trimmed:match("warning:")
			or trimmed:match("Warning:")
		then
			group = "YapWarning"
		elseif trimmed:match("error:")
			or trimmed:match("Error:")
		then
			group = "YapError"
		elseif trimmed:match("^%s*[%w_.%-]+%.[ch]%w*:%d+:%d+:") then
			group = "YapDiagnostic"
		end

		if group then
			vim.api.nvim_buf_add_highlight(buf, -1, group, row, 0, -1)
		end
	end

	local ansi_palette = {
		"#000000", "#cc6666", "#b5bd68", "#f0c674",
		"#81a2be", "#b294bb", "#8abeb7", "#c5c8c6",
		"#666666", "#d54e53", "#b9ca4a", "#e7c547",
		"#7aa6da", "#c397d8", "#70c0b1", "#eaeaea",
	}
	local ansi_groups = {}
	local ansi_state = {
		bold = false,
		italic = false,
		underline = false,
	}

	local function ansi_color(index)
		if index < 16 then
			return ansi_palette[index + 1]
		end

		if index < 232 then
			local value = index - 16
			local red = math.floor(value / 36)
			local green = math.floor(value % 36 / 6)
			local blue = value % 6
			local function channel(component)
				return component == 0 and 0 or 55 + component * 40
			end

			return string.format("#%02x%02x%02x", channel(red), channel(green), channel(blue))
		end

		local gray = 8 + (index - 232) * 10
		return string.format("#%02x%02x%02x", gray, gray, gray)
	end

	local function ansi_group()
		if not ansi_state.fg and not ansi_state.bg
			and not ansi_state.bold and not ansi_state.italic and not ansi_state.underline
		then
			return
		end

		local key = table.concat({
			ansi_state.fg or "",
			ansi_state.bg or "",
			ansi_state.bold and "b" or "",
			ansi_state.italic and "i" or "",
			ansi_state.underline and "u" or "",
		}, ":")
		if not ansi_groups[key] then
			local group = "YapProjectAnsi" .. (#vim.tbl_keys(ansi_groups) + 1)
			local highlight = {
				bold = ansi_state.bold,
				italic = ansi_state.italic,
				underline = ansi_state.underline,
			}

			if ansi_state.fg then
				highlight.fg = ansi_state.fg
			end
			if ansi_state.bg then
				highlight.bg = ansi_state.bg
			end

			vim.api.nvim_set_hl(0, group, highlight)
			ansi_groups[key] = group
		end

		return ansi_groups[key]
	end

	local function apply_sgr(parameters)
		local codes = {}
		for value in (parameters .. ";"):gmatch("(.-);") do
			codes[#codes + 1] = tonumber(value) or 0
		end

		local index = 1
		while index <= #codes do
			local code = codes[index]

			if code == 0 then
				ansi_state = { bold = false, italic = false, underline = false }
			elseif code == 1 then
				ansi_state.bold = true
			elseif code == 2 then
				ansi_state.bold = false
			elseif code == 3 then
				ansi_state.italic = true
			elseif code == 4 then
				ansi_state.underline = true
			elseif code == 22 then
				ansi_state.bold = false
			elseif code == 23 then
				ansi_state.italic = false
			elseif code == 24 then
				ansi_state.underline = false
			elseif code == 39 then
				ansi_state.fg = nil
			elseif code == 49 then
				ansi_state.bg = nil
			elseif code >= 30 and code <= 37 then
				ansi_state.fg = ansi_palette[code - 29]
			elseif code >= 90 and code <= 97 then
				ansi_state.fg = ansi_palette[code - 81]
			elseif code >= 40 and code <= 47 then
				ansi_state.bg = ansi_palette[code - 39]
			elseif code >= 100 and code <= 107 then
				ansi_state.bg = ansi_palette[code - 91]
			elseif code == 38 or code == 48 then
				local target = code == 38 and "fg" or "bg"
				local mode = codes[index + 1]

				if mode == 5 and codes[index + 2] then
					ansi_state[target] = ansi_color(math.max(0, math.min(255, codes[index + 2])))
					index = index + 2
				elseif mode == 2 and codes[index + 4] then
					ansi_state[target] = string.format(
						"#%02x%02x%02x",
						math.max(0, math.min(255, codes[index + 2])),
						math.max(0, math.min(255, codes[index + 3])),
						math.max(0, math.min(255, codes[index + 4]))
					)
					index = index + 4
				end
			end

			index = index + 1
		end
	end

	local function parse_output_line(line)
		local clean = {}
		local highlights = {}
		local position = 1
		local column = 0
		local segment_group = ansi_group()

		while position <= #line do
			local first, last, parameters, intermediate, final =
				line:find("\27%[([%d;?]*)([ -/]*)([@-~])", position)

			if not first then
				local text = line:sub(position):gsub("\r", "")
				if #text > 0 then
					clean[#clean + 1] = text
					local finish = column + #text
					if segment_group then
						highlights[#highlights + 1] = { column, finish, segment_group }
					end
					column = finish
				end
				break
			end

			local text = line:sub(position, first - 1):gsub("\r", "")
			if #text > 0 then
				clean[#clean + 1] = text
				local finish = column + #text
				if segment_group then
					highlights[#highlights + 1] = { column, finish, segment_group }
				end
				column = finish
			end

			if final == "m" then
				apply_sgr(parameters)
			end
			position = last + 1
			segment_group = ansi_group()
		end

		return table.concat(clean), highlights
	end

	local function append(lines)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local clean_lines = {}
		local line_highlights = {}
		for _, line in ipairs(lines) do
			local clean, highlights = parse_output_line(line)
			clean_lines[#clean_lines + 1] = clean
			line_highlights[#line_highlights + 1] = highlights
			output_lines[#output_lines + 1] = clean
		end

		local replacing_placeholder = vim.api.nvim_buf_line_count(buf) == 1
			and vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == ""
		local start_line = replacing_placeholder and 0 or vim.api.nvim_buf_line_count(buf)

		vim.bo[buf].readonly = false
		vim.bo[buf].modifiable = true

		if replacing_placeholder then
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, clean_lines)
		else
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, clean_lines)
		end

		for line_index, highlights in ipairs(line_highlights) do
			apply_semantic_highlight(clean_lines[line_index], start_line + line_index - 1)
			for _, highlight in ipairs(highlights) do
				vim.api.nvim_buf_add_highlight(
					buf,
					-1,
					highlight[3],
					start_line + line_index - 1,
					highlight[1],
					highlight[2]
				)
			end
		end

		vim.bo[buf].modifiable = false
		vim.bo[buf].readonly = true

		if vim.api.nvim_win_is_valid(win) then
			local line_count = vim.api.nvim_buf_line_count(buf)
			vim.api.nvim_win_set_cursor(win, { line_count, 0 })
		end
	end

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, close, {
			buffer = buf,
			silent = true,
			nowait = true,
			desc = "Close project output",
		})
	end

	local function notify_readonly()
		vim.notify("Project output is read-only.", vim.log.levels.INFO, {
			title = "Project Runner",
		})
	end

	for _, key in ipairs({
		"i", "I", "a", "A", "o", "O", "s", "S", "R",
		"r", "x", "X", "d", "D", "c", "C", "p", "P",
		"J", "u", "<C-r>", ">", "<",
	}) do
		vim.keymap.set("n", key, notify_readonly, {
			buffer = buf,
			silent = true,
			desc = "Project output is read-only",
		})
	end

	vim.keymap.set("n", "<C-c>", function()
		if not stop_active_job() then
			vim.notify("No project process is running.", vim.log.levels.INFO)
		end
	end, {
		buffer = buf,
		silent = true,
		desc = "Stop project process",
	})

	vim.keymap.set("n", "<leader>pq", function()
		local items = {}

		for _, line in ipairs(output_lines) do
			local filename, row, column, severity, message =
				line:match("^(.-):(%d+):(%d+):%s*([^:]+):%s*(.*)$")

			if not filename then
				filename, row, column, severity, message =
					line:match("^(.-)%((%d+),(%d+)%)%s*:%s*([^:]+):%s*(.*)$")
			end

			if filename and row and column then
				local absolute = (filename:match("^%a:[/\\\\]") or filename:match("^[/\\\\]"))
					and filename
					or (root .. "/" .. filename)

				items[#items + 1] = {
					filename = absolute,
					lnum = tonumber(row),
						col = tonumber(column),
						text = severity .. ": " .. message,
				}
			end
		end

		if #items == 0 then
			vim.notify("No compiler diagnostics found in project output.", vim.log.levels.INFO)
			return
		end

		vim.fn.setqflist({}, " ", {
			title = "Project Diagnostics",
			items = items,
		})
		vim.cmd.copen()
	end, {
		buffer = buf,
		silent = true,
		desc = "Open project diagnostics",
	})

	append({
		"YAP PROJECT RUNNER",
		string.rep("─", 64),
		"Project: " .. vim.fn.fnamemodify(root, ":t"),
		"Root: " .. root,
		"Platform: " .. (paths.is_windows and "Windows" or "Unix"),
		"Started: " .. os.date("%Y-%m-%d %H:%M:%S"),
		string.rep("─", 64),
	})

	return append
end

local function run_command(command, root, append, callback)
	if active_job and vim.fn.jobwait({ active_job }, 0)[1] == -1 then
		append({ "", "Another project process is already running.", "Stop it before starting another." })
		return false
	end

	active_job = nil
	append({ "", "Command: " .. table.concat(command, " ") })
	local started_at = vim.uv.hrtime()

	local job = vim.fn.jobstart(command, {
		cwd = root,
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.schedule(function()
					while #data > 0 and data[#data] == "" do
						table.remove(data)
					end

					if #data > 0 then
						append(data)
					end
				end)
			end
		end,
		on_stderr = function(_, data)
			if data then
				vim.schedule(function()
					while #data > 0 and data[#data] == "" do
						table.remove(data)
					end

					if #data > 0 then
						append(data)
					end
				end)
			end
		end,
		on_exit = function(job_id, code)
			vim.schedule(function()
				if active_job == job_id then
					active_job = nil
				end

				local elapsed = (vim.uv.hrtime() - started_at) / 1000000000
				append({ string.format("Duration: %.2fs", elapsed) })
				callback(code)
			end)
		end,
	})

	if job <= 0 then
		append({ "Could not start process. jobstart returned " .. job })
		return false
	end

	active_job = job
	return true
end

local function get_build_command(root, append, selected_script)
	local script = build_script(root, selected_script)

	if not script then
		append({
			"",
			"No supported build script found.",
			"Expected build.sh, build.bat, build_all.sh, or build_all.bat.",
		})
		return nil
	end

	local command = script_command(script)
	if not command then
		append({ "", "No sh or bash executable was found to run " .. script })
		return nil
	end

	append({ "Build script: " .. script })
	return command
end

local function find_project_executable(root)
	local name = vim.fn.fnamemodify(root, ":t")
	local executable = root .. "/bin/" .. name

	if paths.is_windows then
		executable = executable .. ".exe"
	end

	if vim.fn.filereadable(executable) == 1 then
		return executable
	end
end

local function find_bin_executables(root)
	local bin = root .. "/bin"
	if vim.fn.isdirectory(bin) ~= 1 then
		return {}
	end

	local found = {}
	for _, file in ipairs(vim.fn.glob(bin .. "/*", false, true)) do
		if vim.fn.isdirectory(file) == 0 then
			local valid = paths.is_windows
				and file:lower():match("%.exe$") ~= nil
				or (not paths.is_windows and vim.fn.executable(file) == 1)

			if valid then
				found[#found + 1] = file
			end
		end
	end

	table.sort(found)
	return found
end

local function launch(file, root, append, args)
	file = vim.fs.normalize(vim.fn.fnamemodify(file, ":p"))
	root = vim.fs.normalize(vim.fn.fnamemodify(root, ":p"))

	local state = {
		file = file,
		root = root,
		args = vim.deepcopy(args or {}),
		last_run = os.time(),
	}

	append({
		"",
		"Executable: " .. vim.fn.fnamemodify(file, ":t"),
		"Path: " .. file,
		"Arguments: " .. (#(args or {}) > 0 and table.concat(args, " ") or "(none)"),
	})

	local command = { file }
	vim.list_extend(command, args or {})

	local started = run_command(command, root, append, function(code)
		append({
			"",
			code == 0 and "Process finished successfully."
				or ("Process exited with code " .. code),
		})
	end)

	if started then
		last_runs[vim.fs.normalize(root)] = state
		save_run_records()
		registry.update(root, {
			last_executable = file,
			last_args = vim.deepcopy(args or {}),
			last_run = os.time(),
		})
	end
end

local function build(root, append, callback, selected_script)
	local command = get_build_command(root, append, selected_script)
	if not command then
		return
	end

	run_command(command, root, append, function(code)
		if code == 0 then
			append({ "", "Build succeeded." })
			callback(true)
		else
			append({ "", "Build failed. Exit code: " .. code })
			callback(false)
		end
	end)
end

local function clean(root, append, callback)
	local script = clean_script(root)

	if not script then
		append({ "", "No clean script found. Expected clean.sh or clean.bat." })
		callback(false, false)
		return
	end

	local command = script_command(script)
	if not command then
		append({ "", "No sh or bash executable was found to run " .. script })
		callback(false, true)
		return
	end

	append({ "Clean script: " .. script })
	run_command(command, root, append, function(code)
		if code == 0 then
			append({ "", "Clean succeeded." })
		else
			append({ "", "Clean failed. Exit code: " .. code })
		end

		callback(code == 0, true)
	end)
end

function M.stop()
	if not stop_active_job() then
		vim.notify("No project process is running.", vim.log.levels.INFO)
	end
end

function M.build(path, selected_script)
	local root = project_root(path)
	local append = open_output(root, "Build Project")
	append({ "", "BUILD" })

	build(root, append, function() end, selected_script)
end

function M.clean(path)
	local root = project_root(path)
	local append = open_output(root, "Clean Project")
	append({ "", "CLEAN" })

	clean(root, append, function(ok, found)
		if not found then
			vim.notify("No clean script found for this project.", vim.log.levels.WARN)
		end
	end)
end

function M.rebuild(path)
	local root = project_root(path)
	local append = open_output(root, "Rebuild Project")
	append({ "", "CLEAN" })

	clean(root, append, function(ok, found)
		if found and not ok then
			return
		end

		append({ "", "BUILD" })
		build(root, append, function() end)
	end)
end

function M.run(path, args, selected_script)
	local root = project_root(path)
	local append = open_output(root, "Run Executable")
	append({ "", "BUILD" })

	build(root, append, function(ok)
		if not ok then
			return
		end

		local executable = find_project_executable(root)
		local available = find_bin_executables(root)

		if not executable and #available == 1 then
			executable = available[1]
		end

		if not executable then
			append({
				"",
				"Could not determine which executable to run.",
				"Expected: bin/" .. vim.fn.fnamemodify(root, ":t")
					.. (paths.is_windows and ".exe" or ""),
			})

			if #available > 1 then
				append({ "Multiple executables found. Use <leader>pe to select one:" })
				for _, file in ipairs(available) do
					append({ "  " .. vim.fn.fnamemodify(file, ":t") })
				end
			end

			return
		end

		append({ "", "EXECUTION" })
		launch(executable, root, append, args)
	end, selected_script)
end

local function parse_args(input)
	local args = {}
	local current = {}
	local quote = nil
	local escaped = false
	local token_started = false

	for i = 1, #input do
		local char = input:sub(i, i)

		if escaped then
			current[#current + 1] = char
			escaped = false
		elseif char == "\\" and quote ~= "'" then
			local next_char = input:sub(i + 1, i + 1)

			if next_char == '"' or next_char == "'" or next_char == "\\" or next_char:match("%s") then
				escaped = true
				token_started = true
			else
				current[#current + 1] = char
				token_started = true
			end
		elseif quote then
			if char == quote then
				quote = nil
			else
				current[#current + 1] = char
			end
			token_started = true
		elseif char == "'" or char == '"' then
			quote = char
			token_started = true
		elseif char:match("%s") then
			if token_started then
				args[#args + 1] = table.concat(current)
				current = {}
				token_started = false
			end
		else
			current[#current + 1] = char
			token_started = true
		end
	end

	if escaped then
		current[#current + 1] = "\\"
	end

	if quote then
		return nil, "Unclosed quote in arguments."
	end

	if token_started then
		args[#args + 1] = table.concat(current)
	end

	return args
end

function M.get_root(path)
	return project_root(path)
end

function M.list_build_scripts(path)
	local root = project_root(path)
	return root, list_build_scripts(root)
end

function M.list_executables(path)
	local root = project_root(path)
	return root, find_bin_executables(root)
end

function M.project_executable(path)
	local root = project_root(path)
	local executable = find_project_executable(root)

	if executable then
		return executable
	end

	local available = find_bin_executables(root)
	if #available == 1 then
		return available[1]
	end

	return root .. "/bin/" .. vim.fn.fnamemodify(root, ":t") .. (paths.is_windows and ".exe" or "")
end

function M.parse_args(input)
	return parse_args(input)
end

function M.run_binary(file, root, args)
	local append = open_output(root, "Run Executable")
	launch(file, root, append, args)
end

function M.rerun()
	local previous
	for root, run in pairs(last_runs) do
		if type(run) == "table" then
			local metadata = registry.get(root) or {}
			local timestamp = run.last_run or metadata.last_run or 0
			if not previous or timestamp > previous.last_run then
				previous = vim.deepcopy(run)
				previous.last_run = timestamp
			end
		end
	end
	if not previous then
		vim.notify("No previous project execution was recorded.", vim.log.levels.INFO)
		return
	end
	if vim.fn.isdirectory(previous.root) ~= 1 then
		vim.notify("The last-run project directory no longer exists.", vim.log.levels.WARN)
		return
	end
	local executable_valid = vim.fn.filereadable(previous.file) == 1
	if executable_valid and not paths.is_windows then executable_valid = vim.fn.executable(previous.file) == 1 end
	if not executable_valid then
		vim.notify("The last-run executable is missing or is not executable. Build the project again.", vim.log.levels.WARN)
		return
	end
	M.run_binary(previous.file, previous.root, previous.args)
end

return M
