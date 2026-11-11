# YAP UI system: architecture plan

> Status: design and pseudocode only. This document defines the intended contracts; it is not an implementation.

## Goals

- Keep the existing project engine, project detection, registry, C/C++ helpers, build/run/clean workflows, diagnostics, and Telescope integration.
- Remove the NuiComponents dependency and do not build the new UI around a third-party component framework.
- Let each UI component own its state and lifecycle.
- Let keymaps and features describe a UI declaratively instead of manually creating windows.
- Keep layout, rendering, component behavior, and feature-specific actions separate.
- Make components reusable across unrelated YAP views.

## 1. Mental model

A feature asks the UI manager to open a session. The manager creates a session, validates the specification, calculates panel geometry, creates panel hosts, mounts components, routes focus/input, and tears everything down.

A panel is a region in a session. A component is the thing displayed inside that region. A component may own internal state and resources, but it does not decide the geometry of sibling panels.

The intended dependency direction is:

```text
Feature / keymap
      |
      v
  UI manager ------ session lifecycle / error boundary
      |
      v
    Layout -------- panel geometry and ordering
      |
      v
     Panel -------- panel host and component attachment
      |
      v
   Component ------ tree, list, input, preview, ...
      |
      v
   UI backend ------ Neovim buffers, windows, options, autocmds
```

The UI backend is a small YAP-owned layer over Neovim APIs. It is not a component framework.

## 2. Public API shape

Prefer one specification table over a long positional argument list. It is easier to extend and impossible to confuse because somebody swapped the second and third integers.

```lua
local session = UI.open({
    size = {
        width = 0.80,       -- fraction of editor, or an absolute cell count
        height = 0.70,
        min_width = 60,
        min_height = 12,
    },

    layout = {
        direction = "row", -- row or column
        gap = 1,
    },

    items = shared_items, -- optional shared data/context

    panels = {
        {
            id = "navigation",
            type = "tree",
            name = "Project files",
            at = 1,
            size = { width = 0.35 },
            options = {
                items = file_items,
                callbacks = {
                    on_select = on_file_selected,
                },
            },
        },
        {
            id = "details",
            type = "preview",
            name = "File preview",
            at = 2,
            size = { width = 0.65 },
            options = {
                source = preview_source,
            },
        },
    },

    callbacks = {
        on_open = on_open,
        on_close = on_close,
        on_error = on_ui_error,
    },
})
```

Conceptual shorthand:

```lua
UI.open({
    panels = {
        panel("tree", "navigation", { at = 1 }, yTree(tree_options)),
        panel("preview", "details", { at = 2 }, yPreview(preview_options)),
    },
})
```

The shorthand is only syntax sugar. The normalized panel specification is the actual contract.

### Arguments and derived values

| Field | Meaning |
|---|---|
| `size` | Overall session dimensions and constraints |
| `layout` | How panels are arranged |
| `items` | Optional shared data/context |
| `panels` | Ordered panel specifications |
| `panels_count` | Derived from `#panels`; never supplied separately |
| `item_count` | Derived by the component from its own item data |
| `callbacks` | Session-level lifecycle and error callbacks |

Do not store counts that can be derived from the same table. The UI manager should validate types and reject invalid specifications before opening windows.

## 3. Panel contract

A panel is a host and a layout slot, not a visual component with its own arbitrary styling.

Proposed panel fields:

- `id`: stable unique identifier inside the session.
- `type`: registered component type, such as `tree`, `list`, `input`, or `preview`.
- `name`: readable label for debugging and optional display.
- `at`: ordering / placement hint.
- `size`: preferred size, minimum size, maximum size, or flex weight.
- `options`: component-specific configuration.
- `component`: optional already-created component instance.

The layout engine calculates a rectangle for each panel. The panel host gives that rectangle and a backend context to its component. A component must not resize or reposition sibling panels.

## 4. Component contract

Each component is a separate module and is responsible for its own internal state and lifecycle.

Example modules:

- `yTree`: hierarchical navigation and selection.
- `yList`: flat selectable entries.
- `yInput`: text input and validation.
- `yPreview`: read-only or generated preview content.
- `yText`: simple text / description region.

Proposed factory and lifecycle:

```lua
local tree = yTree.new({
    items = items,
    callbacks = {
        on_select = function(item, index, tree) end,
        on_change = function(items, tree) end,
        on_error = function(err, context) end,
    },
})

tree:mount(panel_context)
tree:update(next_items)
tree:focus()
tree:handle_key(key)
tree:close()
tree:destroy()
```

Lifecycle responsibilities:

1. `new(options)`: validate component options and create its private state. Do not create windows yet.
2. `mount(context)`: attach to the assigned panel host and allocate required resources.
3. `update(data)`: update state and redraw only what changed.
4. `focus()`: request focus through the session/backend.
5. `handle_key(key)`: handle component-owned input and report whether it consumed the key.
6. `close()`: stop interaction and release temporary resources.
7. `destroy()`: final idempotent cleanup. Clear autocmds, timers, mappings, namespaces, buffers, and windows owned by the component.

A component can own multiple internal resources. It must track exactly what it owns and must never close a resource owned by another component or by the editor.

### Panel content versus overlays

Normal components render into the panel host supplied by the manager. A component may request a separate overlay for a menu, tooltip, completion popup, or floating detail view. Overlays are registered with the session and receive their own lifecycle handle. They are not silently inserted into the main panel layout.

## 5. Component registration

The manager should not hard-code every component.

```lua
UI.register("tree", yTree)
UI.register("list", yList)
UI.register("input", yInput)
UI.register("preview", yPreview)
```

Registration validates that a component factory implements the required contract. Unknown component types should fail during specification validation, before any window is created.

## 6. Lifecycle ownership

There are three levels of ownership:

- **Session** owns the root UI resources, panel collection, layout, global input routing, and session callbacks.
- **Panel** owns its host region and the component instance attached to it.
- **Component** owns its local state, mappings, autocmds, timers, namespaces, and any explicitly registered overlays.

Closing a session closes its panels. Closing a panel closes its component. Destroying a component must be safe to call more than once.

The manager should expose explicit operations:

```lua
session:mount()
session:update(spec_or_data)
session:focus(panel_id)
session:get(panel_id)
session:close()
session:destroy()
```

## 7. Error handling and callbacks

Do not make every component reinvent try/catch. Lua has `pcall` and `xpcall`; use one shared protected-call utility at the manager boundary.

- Component callbacks can provide `on_error(err, context)` for feature-specific recovery or reporting.
- Session callbacks can provide `on_error(err, context)` for session-wide reporting.
- If no callback handles an error, the manager reports it with `vim.notify` and a useful traceback.
- A failed mount must clean up resources already allocated by that component.
- One component failing to update should not corrupt or silently destroy unrelated panels.
- Cleanup should continue even if one cleanup callback fails.

Conceptual wrapper:

```lua
local function safe_call(owner, callback_name, callback, ...)
    if type(callback) ~= "function" then
        return true
    end

    local ok, result = xpcall(callback, debug.traceback, ...)
    if not ok then
        owner:report_error(result, callback_name)
        return false, result
    end

    return true, result
end
```

Callbacks are notifications / extension points. The manager owns protection and cleanup. Components should not wrap every normal callback in nested protected calls.

## 8. Layout rules

The layout engine only calculates geometry. It does not render component content or decide component behavior.

Initial layout support should stay small:

- `row`: panels arranged horizontally.
- `column`: panels arranged vertically.
- `at`: stable ordering within the selected direction.
- `size`: fixed cells or a fraction / flex weight.
- `min_size` and `max_size`: constraints.
- `gap`: spacing between panels.

Later additions can include nested layouts, hidden panels, split ratios, and responsive collapse. Do not implement those before the first two-panel view works.

## 9. Backend boundary

The backend is the only layer that directly handles low-level Neovim UI resources.

It should eventually centralize:

- scratch buffer creation and configuration;
- window creation, configuration, and validity checks;
- window/buffer ownership tracking;
- buffer-local keymaps;
- autocmd group creation and disposal;
- namespace creation and clearing;
- safe close and cleanup helpers;
- editor resize handling.

The backend should expose small functions, not a giant generic framework. Components can use a supplied backend context and should not call arbitrary global UI helpers.

## 10. Proposed file structure

This is a target structure, not a demand to create every file immediately.

```text
lua/yap/
├── init.lua                 # public exports and explicit setup only
├── config.lua               # existing platform/project defaults
├── projects.lua             # existing project workflow engine
├── project_registry.lua     # existing persistent project metadata
├── c.lua                    # existing C/C++ helpers
├── telescope.lua            # existing optional integration
├── ui.lua                   # existing legacy float helpers used by output/tools
└── ui/
    ├── manager.lua           # UI.open, registration, sessions
    ├── session.lua           # session lifecycle and error boundary
    ├── panel.lua             # panel host and component attachment
    ├── layout.lua            # geometry only
    ├── backend.lua           # Neovim buffer/window primitives
    ├── callbacks.lua         # protected callback invocation
    ├── registry.lua          # component type registry
    └── components/
        ├── tree.lua
        ├── list.lua
        ├── input.lua
        ├── preview.lua
        └── text.lua
```

The existing `lua/yap/ui.lua` stays in place for now. It is used by the current process output and C metadata utilities. The new system should be introduced alongside it, then those call sites can migrate deliberately. Do not break working project functionality just to make the folder tree look pretty.

## 11. Implementation milestones

1. **Contracts only**: settle the UI spec, panel schema, component lifecycle, and error policy.
2. **Backend prototype**: create one scratch buffer and one window with deterministic cleanup.
3. **One component**: implement `yTree` in a single panel, including selection and teardown.
4. **Two-panel session**: place `yTree` beside `yPreview`; verify resizing and focus.
5. **Callbacks and failure tests**: force mount, update, callback, and cleanup errors.
6. **Reusable components**: add list and input without changing the manager contract.
7. **Migrate one feature**: move the project picker only after the standalone prototype is stable.
8. **Remove old UI paths only when unused**: preserve the process output UI and C tools until their replacements are complete.

## 12. Acceptance criteria

- No NuiComponents dependency or NuiComponents imports.
- A keymap can open a UI by passing a declarative specification.
- The manager derives counts and validates the specification.
- Components can be mounted, updated, focused, closed, and destroyed independently.
- A component cannot accidentally close another component's windows.
- A failed callback reports a traceback and does not leak resources.
- Closing a session leaves no YAP-owned windows, buffers, autocmds, or mappings behind.
- A component can be reused in another view without knowing which feature opened it.
- Existing project detection, build/run/clean, registry, diagnostics, C helpers, and Telescope integration continue to work.
