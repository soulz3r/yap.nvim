local M = {}
M.is_windows = vim.fn.has("win32") == 1
M.projects_dir = vim.env.PROJECTS_DIR or (M.is_windows and "D:/config/projects") or vim.fn.expand("~/projects")
return M
