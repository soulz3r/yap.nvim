local ActionBar = {}
ActionBar.__index = ActionBar

local style = require("yap.ui.components.style")
local layout = require("yap.ui.layout")

local function active_mode(mode)
	return mode == "insert" and "i" or "n"
end

local function get_hint(action)
	if action.hint then
		return action.hint
	end

	if action.key or action.label then
		return {
			key = action.key,
			label = action.label,
		}
	end
end

local function is_visible(action, mode)
	if not action.mode then
		return true
	end

	return vim.tbl_contains(action.mode, active_mode(mode))
end

function ActionBar:_button_props(action, index)
	local hint = get_hint(action)
	local label = table.concat(vim.tbl_filter(function(value)
		return type(value) == "string" and value ~= ""
	end, {
		hint.key,
		hint.label,
	}), " ")

	local border_style = self.opts.style == "outlined" and "rounded" or "none"

	return style.with_defaults({
		id = string.format("%s-%d", self.opts.id or "yap-action", index),
		label = label,
		flex = 1,
		align = "center",
		truncate = true,
		is_focusable = true,
		border_style = border_style,
		press_key = { "<CR>", "<Space>" },
		on_press = action.on_press or action.handler,
		window = {
			highlight = {
				NormalFloat = self.opts.style == "outlined" and "YapFloatNormal" or "Normal",
				FloatBorder = self.opts.style == "outlined" and "YapFloatBorder" or "Normal",
			},
		},
	}, action.props)
end

function ActionBar:_content(n)
	local children = {}

	for _, action in ipairs(self.actions) do
		local hint = get_hint(action)

		if hint and is_visible(action, self.mode) and (action.on_press or action.handler) then
			if #children > 0 then
				children[#children + 1] = n.gap(self.opts.gap)
			end

			children[#children + 1] = n.button(self:_button_props(action, #children + 1))
		end
	end

	if #children == 0 then
		return n.paragraph({
			id = (self.opts.id or "yap-action-bar") .. "-empty",
			lines = "",
			is_focusable = false,
			border_style = "none",
		})
	end

	return n.columns({ flex = 1 }, unpack(children))
end

function ActionBar:_renderer_options()
	local height = self.opts.height or (self.opts.style == "outlined" and 3 or 1)
	local width = self.opts.width
	local position = self.opts.position or "bottom"
	local relative = self.opts.relative or "editor"

	if type(position) == "table" then
		width = width or (self.parent and self.parent:get_size().width) or vim.o.columns
		return {
			width = width,
			height = height,
			position = position,
			relative = relative,
		}
	end

	if self.parent then
		width = width or self.parent:get_size().width
		position = layout.relative_position(self.parent, position, height, self.opts.offset or 0)
	end

	if type(position) ~= "table" then
		local editor_height = math.max(1, vim.o.lines - vim.o.cmdheight)
		position = {
			row = math.max(0, editor_height - height),
			col = 0,
		}
	end

	width = math.max(1, math.min(width or vim.o.columns, vim.o.columns))

	return {
		width = width,
		height = height,
		position = position,
		relative = relative,
	}
end

function ActionBar:_render()
	if self.renderer then
		self.renderer:close()
		self.renderer = nil
	end

	local n = require("nui-components")
	local options = self:_renderer_options()

	self.renderer = n.create_renderer(options)
	self.renderer:render(function()
		return self:_content(n)
	end)
end

function ActionBar:mount()
	self.closed = false
	self:_render()
	return self
end

function ActionBar:update(actions, mode)
	if actions then
		self.actions = actions
	end

	if mode then
		self.mode = mode
	end

	if not self.closed then
		self:_render()
	end
end

function ActionBar:close()
	self.closed = true

	if self.renderer then
		self.renderer:close()
		self.renderer = nil
	end
end

function ActionBar:hide()
	self:close()
end

function ActionBar:show()
	if self.closed then
		self:mount()
	end
end

local M = {}

---@param opts table
---@return ActionBar
function M.new(opts)
	opts = opts or {}

	return setmetatable({
		opts = vim.tbl_deep_extend("force", {
			id = "yap-action-bar",
			position = "bottom",
			style = "flat",
			gap = 2,
			height = 1,
		}, opts),
		parent = opts.parent,
		actions = opts.actions or {},
		mode = opts.mode or "normal",
		closed = true,
		renderer = nil,
	}, ActionBar)
end

return M
