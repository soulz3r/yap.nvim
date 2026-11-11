# yap.nvim

A small Neovim toolkit for C/C++ project workflows. YAP handles project detection, build scripts, execution, output, compiler diagnostics, C/C++ helpers, persistent project metadata, and an optional Telescope Projects integration.

> **Beta direction:** the existing project tools are being preserved. The new UI system is currently a design and pseudocode prototype. It will use Neovim APIs directly and will not depend on NuiComponents.

## Existing functionality

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
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-project.nvim",
  },
  config = function()
    local yap = require("yap")

    -- Setup is intentionally explicit in beta. No defaults or keymaps
    -- are silently installed by require("yap").setup().
    yap.setup({
      -- c_tools = true,
      -- ui = { highlights = { ... } },
      -- telescope = { projects_dir = vim.fn.expand("~/projects") },
    })
  end,
}
```

The setup entry point is intentionally a user-owned placeholder in this beta. Existing modules remain available directly:

- `require("yap").projects`: project detection, build/run/clean, output, and diagnostics.
- `require("yap").project_registry`: persistent project metadata.
- `require("yap").c`: C/C++ helper module.
- `require("yap.ui")`: existing floating-window helpers used by process output and C metadata.

## UI architecture

The new UI system is planned as a declarative manager with independent components:

```text
Feature / keymap
      |
      v
  UI manager
      |
      v
    Layout
      |
      v
     Panel
      |
      v
   Component
      |
      v
   UI backend
```

A feature will call the manager with a specification containing overall size, layout, shared items, panels, and callbacks. Each panel declares a component type, name, position, size, and component options. Counts such as the number of panels or items are derived from the supplied tables rather than passed separately.

Components such as `yTree`, `yList`, `yInput`, and `yPreview` own their internal state and lifecycle: `new`, `mount`, `update`, `focus`, `handle_key`, `close`, and `destroy`. The session coordinates them without taking over their internal behavior.

Error handling will be centralized through a protected callback wrapper using `xpcall`. Components and sessions can supply `on_error` callbacks; cleanup must still run when a callback fails.

**Read the full design:** [docs/ui-system.md](docs/ui-system.md)

**Lua pseudocode:** [lua/yap/ui/prototype.lua](lua/yap/ui/prototype.lua)

## Current setup behavior

- `require("yap")` exports the existing modules.
- `setup(opts)` does not merge defaults or initialize features automatically in beta.
- The existing `lua/yap/ui.lua` is retained for current process output and C metadata windows. It is not the proposed component manager.
- No NuiComponents dependency or imports are part of the beta branch.

## Build conventions

YAP runs scripts from the project root. Windows priority is `build_all.bat`, then `build.bat`; Unix priority is `build_all.sh`, then `build.sh`. Clean scripts use equivalent `clean_all` / `clean` names.

The default executable is `bin/<project-name>` (`.exe` on Windows). If absent, YAP uses the only executable in `bin/`, or lets you select one when multiple are present.

YAP stores state under `stdpath("state")/yap` and `stdpath("data")/yap`. Existing Soul project state and argument history are read as migration fallbacks.
