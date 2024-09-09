local M = {}

local enabled = true

local api = vim.api

local win = nil
local last_clicked_line = nil
local terminalwin = nil
local filewin = nil

local isOpen = true

local tab_buffer_name = "tabs_buffer"

-- Function to check if a buffer with a specific name exists
local function buffer_exists_by_name(name)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf):match(name) then
			return buf
		end
	end
	return -1
end

local sidebar_style = {
	width = 12,
	height = vim.o.lines - 2,
}

---@class Icon
---@field content string
---@field id integer
---@field onSelect function():void
Icon = {}
Icon.__index = Icon

---@param name string
---@param callback function ():void
function Icon.new(name, callback)
	local self = setmetatable({}, Icon)
	self.content = name

	self.onSelect = callback
	return self
end

---@class Panel
---@field icon Icon
---@field id integer
---@field name string
Panel = {}
Panel.__index = Panel

local panelLen = 0
---@param name string
---@param icon Icon
function Panel.new(name, icon)
	local self = setmetatable({}, Panel)

	self.id = panelLen
	self.name = name
	panelLen = panelLen + 1

	self.icon = icon
	return self
end

---@type Panel[]
local menuOptons = {
	Panel.new(
		string.format("%s-Terminal", LazyVim.config.icons.kinds.Keyword),
		Icon.new(string.format("%s-Terminal", LazyVim.config.icons.kinds.Keyword), function()
			if terminalwin ~= nil then
				vim.api.nvim_win_close(terminalwin, true)
				terminalwin = nil
				return
			end
			local termbuffer = vim.api.nvim_create_buf(true, true)
			vim.cmd(":leftabove vsplit")
			terminalwin = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(terminalwin, termbuffer)

			vim.api.nvim_win_set_width(terminalwin, sidebar_style.width * 4) -- Adjust the width as needed
			vim.cmd("term")
		end)
	),
	Panel.new(
		string.format("%s- File", LazyVim.config.icons.kinds.File),
		Icon.new(string.format("%s- File", LazyVim.config.icons.kinds.File), function()
			if filewin ~= nil then
				vim.api.nvim_win_close(filewin, true)
				filewin = nil
				return
			end
			vim.cmd(":leftabove vsplit")

			filewin = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_width(filewin, sidebar_style.width * 4) -- Adjust the width as needed
			vim.cmd("Neotree current")

			--vim.api.nvim_win_set_cursor(fwin, { 1, 1 })
		end)
	),
	Panel.new(
		string.format("%s- Git", LazyVim.config.icons.kinds.Control),
		Icon.new(string.format("%s- Git", LazyVim.config.icons.kinds.Control), function()
			LazyVim.lazygit({ cwd = LazyVim.root.git() })
		end)
	),
}

M.handle_click = function()
	local cursor = vim.fn.getmousepos() -- Get the mouse click position
	local clicked_line = cursor.line -- Extract the clicked line number

	if win and win ~= cursor.winid then
		vim.api.nvim_set_current_win(cursor.winid)
		return
	end

	local line = vim.api.nvim_get_current_line()
	if last_clicked_line == clicked_line then
		for _, item in ipairs(menuOptons) do
			if line == item.icon.content then
				item.icon.onSelect()
			end
		end
	else
		-- Update the cursor position to the clicked line and move it to the start of the line
		vim.api.nvim_win_set_cursor(0, { clicked_line, 0 })
		last_clicked_line = clicked_line -- Update the last clicked line
	end
end

M.handle_enter = function()
	local line = vim.api.nvim_get_current_line()

	for _, item in ipairs(menuOptons) do
		if line == item.icon.content then
			item.icon.onSelect()
		end
	end
end

M.start = function()
	-- Function to open a simple sidebar
	-- Create a new vertical split and set it to the left of the current window
	vim.cmd("vsplit")
	win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true) -- Create a new empty buffer (not listed, scratch)
	vim.api.nvim_buf_set_name(buf, tab_buffer_name)

	-- Set the new buffer to the split window
	vim.api.nvim_win_set_buf(win, buf)

	-- Disable mouse for the entire session (global setting)
	vim.o.mouse = ""

	api.nvim_set_option_value("number", false, {
		win = win,
	})

	api.nvim_set_option_value("relativenumber", false, {
		win = win,
	})
	api.nvim_set_option_value("signcolumn", "no", {
		win = win,
	})
	api.nvim_set_option_value("winfixwidth", true, {
		win = win,
	})
	api.nvim_set_option_value("buftype", "nofile", {
		buf = buf,
	})
	api.nvim_set_option_value("bufhidden", "wipe", {
		buf = buf,
	})
	api.nvim_set_option_value("swapfile", false, {
		buf = buf,
	})

	-- Set the width of the sidebar
	vim.api.nvim_win_set_width(win, sidebar_style.width) -- Adjust the width as needed
	---@type string[]
	local strs = {}

	for _, value in ipairs(menuOptons) do
		table.insert(strs, value.icon.content)
	end

	-- Set text lines for the button
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, strs)

	-- Keymap to handle mouse clicks
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<LeftMouse>",
		":lua require('tabs').handle_click()<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		":lua require('tabs').handle_enter()<CR>",
		{ noremap = true, silent = true }
	)

	-- Disable visual mode selection by mapping keys to <Nop>
	vim.api.nvim_buf_set_keymap(buf, "v", "v", "<Nop>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "v", "<LeftMouse>", "<Nop>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "v", "<RightMouse>", "<Nop>", { noremap = true, silent = true })

	-- Make the text non-editable and disable mouse interactions
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<LeftMouse>",
		':lua require("tabs").handle_click()<CR>',
		{ noremap = true, silent = true }
	)

	-- Disable visual mode selection by mapping keys to <Nop>
	vim.api.nvim_buf_set_keymap(
		buf,
		"v",
		"<LeftMouse>",
		'<Cmd>lua vim.cmd("normal! \\<Esc>")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"x",
		"<LeftMouse>",
		'<Cmd>lua vim.cmd("normal! \\<Esc>")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(buf, "v", "v", "<Nop>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "x", "v", "<Nop>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(
		buf,
		"x",
		"<2-LeftMouse>",
		':lua require("tabs").handle_click()<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"v",
		"<2-LeftMouse>",
		':lua require("tabs").handle_click()<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<2-LeftMouse>",
		':lua require("tabs").handle_click()<CR>',
		{ noremap = true, silent = true }
	)

	-- Make the text non-editable
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true
end
M.setup = function(opts)
	opts = opts or {}
	if opts.enabled then
		enabled = opts.enabled
	end

	if not enabled then
		return
	end

	local bufname = buffer_exists_by_name(tab_buffer_name)
	vim.notify(string.format("%d", bufname))
	if bufname >= 0 then
		vim.api.nvim_buf_delete(bufname, {
			force = true,
		})
	end
	-- Variables to track the last clicked line and floating window ID

	-- Function to handle mouse clicks

	-- Function to create a floating window with button-like text

	vim.opt.mouse = "a"

	M.start()

	-- Function to check if there is only one active buffer
	local function check_single_buffer()
		local uis = vim.api.nvim_list_chans()
		vim.notify(string.format("valid buffs %s", table.getn(uis)))
		local active_buffers = 0

		if active_buffers == 1 then
			print("Only one buffer is active")
			-- You can add any action you want to take here
		end
	end

	-- Autocmd to trigger the function when buffers are added or removed
	vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
		callback = check_single_buffer,
	})

	-- Create the button when Neovim starts
end

M.open = function()
	M.start()
	isOpen = true
end

M.close = function()
	if win ~= nil then
		vim.api.nvim_win_close(win, true)
		win = nil
	end
	if terminalwin ~= nil then
		vim.api.nvim_win_close(terminalwin, true)
		terminalwin = nil
	end
	if filewin ~= nil then
		vim.api.nvim_win_close(filewin, true)
		filewin = nil
	end
	isOpen = false
end

M.toggle = function()
	if isOpen then
		M.close()
	else
		M.open()
	end
end

api.nvim_set_keymap("n", "<C-t>", ":lua require('tabs').toggle()<CR>", {
	noremap = true,
	silent = true,
})

return M
