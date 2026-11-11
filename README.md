# yap.nvim

A small Neovim toolkit for C/C++ project workflows. YAP handles project detection, build scripts, execution, output, compiler diagnostics, and an optional Telescope Projects integration without depending on another user's config namespace.

## Features

- Detect project roots from Git, Make, CMake, and common build metadata.
- Build using `build_all.bat`, `build.bat`, `build_all.sh`, or `build.sh`, with platform-aware priority.
- Clean and rebuild using matching clean scripts.
- Build and run the project-named executable from `bin/`.
- Select and run other executables from `bin/`.
- Parse quoted command-line arguments and keep per-project argument history.
- Persist the last executed project and executable across Neovim sessions.
- Show ANSI-colored process output in a floating window.
- Parse common GCC/Clang and MSVC diagnostics into the quickfix list.
- C/C++ helpers for switching source/header files, inserting includes, and viewing project metadata.
- Optional Telescope Projects integration with project actions and recent-project restoration.

## Installation

With lazy.nvim:

```lua
{
  "soulz3r/yap.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "grapp-dev/nui-components.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-project.nvim",
  },
  config = function()
    require("yap").setup({
      projects_dir = vim.fn.expand("~/projects"),
      telescope = true,
      highlights = {
        normal = { fg = "#D3C6AA", bg = "NONE" },
        border = { fg = "#859289", bg = "NONE" },
        title = { fg = "#A7C080", bg = "NONE", bold = true },
        section_title = { fg = "#A7C080", bold = true },
        muted = { fg = "#859289" },
        success = { fg = "#A7C080" },
        warning = { fg = "#DBBC7F" },
        error = { fg = "#E67E80" },
      },
    })
  end,
}
```

NuiComponents is used for YAP's floating output and C/C++ project-information views. It is a required UI dependency; `nui.nvim` is installed alongside it. Set `projects_dir` to your project directory. If omitted, YAP uses `PROJECTS_DIR`, `D:/config/projects` on Windows, or `~/projects` elsewhere. Telescope integration is disabled by default; set `telescope = true` to enable it. When enabling it, install both Telescope and `telescope-project.nvim` as shown above.

## UI

YAP uses NuiComponents for its floating views and the C-project switcher. The process-output buffer remains a normal Neovim buffer, so ANSI parsing, compiler diagnostics, quickfix extraction, and streaming process output stay in YAP's existing project engine. The project switcher is composed from shared components exported by `yap.ui.components`: input, selectable list, panel, paragraph, and description. Its shortcut hints are built directly with NuiComponents buttons in a horizontal row. They are informational, non-focusable, and rendered outside the bordered panels.

## Colors

YAP exposes a `highlights` option in `setup()`. Each entry accepts the same highlight options as `vim.api.nvim_set_hl()`, including `fg`, `bg`, `bold`, `italic`, and `link`. Colors are reapplied after every `ColorScheme` event.

Available keys are `normal`, `border`, `title`, `section_title`, `muted`, `success`, `warning`, `error`, `command`, `path`, `phase`, `metadata`, and `diagnostic`. Omit any key to keep its default link to the corresponding Neovim highlight group. Use `bg = "NONE"` for transparent float content and borders.

The float uses the plugin-owned `YapFloatNormal`, `YapFloatBorder`, and `YapFloatTitle` groups, so its appearance can be customized without changing global Neovim highlights.

## Keymaps

| Keymap | Action |
|---|---|
| `<leader>pp` | Open project picker |
| `<leader>pr` | Build and run project |
| `<leader>pb` | Build project |
| `<leader>pc` | Clean project |
| `<leader>pB` | Clean and rebuild |
| `<leader>pS` | Choose build script |
| `<leader>pe` | Choose executable from `bin/` |
| `<leader>ps` | Stop active process |
| `<leader>pR` | Rerun last executable |
| `<leader>ch` | Switch C/C++ source/header |
| `<leader>ci` | Insert include |
| `<leader>cp` | Show C project metadata |

Inside Telescope Projects: `<C-g>/gR` builds and runs, `<C-y>/gB` builds, `<C-e>/gE` selects an executable, `<C-a>/gA` opens project actions, `gC` cleans, `gX` cleans and rebuilds, and `gS` chooses a build script.

## Build conventions

YAP runs scripts from the project root. Windows priority is `build_all.bat`, then `build.bat`; Unix priority is `build_all.sh`, then `build.sh`. Clean scripts use equivalent `clean_all` / `clean` names.

The default executable is `bin/<project-name>` (`.exe` on Windows). If absent, YAP uses the only executable in `bin/`, or lets you select one when multiple are present.

## API and state

- `:CProjectInfo` shows project metadata.
- `:CSwitchHeader` switches source/header files.
- `require("yap").projects` exposes the project engine.
- `require("yap").project_registry` exposes persistent metadata.
- `require("yap").setup({ telescope = false })` initializes the core without Telescope.

YAP uses only `Yap*` highlight groups and stores state under `stdpath("state")/yap` and `stdpath("data")/yap`. Existing Soul project state and argument history are read as migration fallbacks.
