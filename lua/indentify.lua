local ns = vim.api.nvim_create_namespace("indentify")
local augroup = vim.api.nvim_create_augroup("indentify", { clear = true })

---@alias indentify.filter fun(win: integer, buf: integer): boolean?

---@class indentify.config
---@field char string?
---@field filter indentify.filter?
---@field include_range_end boolean?

local indent_char = '🭱'
---@type indentify.filter
local filter = function(_, buf)
  if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then return false end
end

---@param name string
---@param default string
---@param dim boolean
---@return integer
local function set_hl(name, default, dim)
  vim.api.nvim_set_hl(0, name, {
    fg = vim.api.nvim_get_hl(0, { name = default, link = false }).fg,
    default = true,
    dim = dim,
  })
  return vim.api.nvim_get_hl_id_by_name(name)
end

local hl_inactive
local hl_active
local function on_colorscheme()
  hl_inactive = set_hl("IndentifyInactive", "NonText", true)
  hl_active = set_hl("IndentifyActive", "Delimiter", true)
end
on_colorscheme()
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = on_colorscheme,
  group = augroup
})

---@param buf integer
---@param row integer
local function next_non_blank_row(buf, row)
  local lnum = row + 1
  return vim.api.nvim_buf_call(buf, function()
    return vim.fn.nextnonblank(lnum) - 1
  end)
end

---@param buf integer
---@param row integer
local function prev_non_blank_row(buf, row)
  local lnum = row + 1
  return vim.api.nvim_buf_call(buf, function()
    return vim.fn.prevnonblank(lnum) - 1
  end)
end

---@param buf integer
---@param row integer
---@return integer
local function get_indent(buf, row)
  return vim.api.nvim_buf_call(buf, function()
    return vim.fn.indent(row + 1)
  end)
end

---@param buf integer
---@param row integer
---@param row_end integer
---@param indent integer
---@return integer
local function find_range_end(buf, row, row_end, indent)
  while row < row_end do
    local next_i = next_non_blank_row(buf, row + 1)
    if next_i == -1 then break end
    if get_indent(buf, next_i) <= indent then
      return next_i
    end
    row = next_i
  end
  return row_end
end

---@param buf integer
---@param row integer
---@param row_begin integer
---@param indent integer
---@return integer
local function find_range_begin(buf, row, row_begin, indent)
  while row >= row_begin do
    local next_i = prev_non_blank_row(buf, row - 1)
    if next_i == -1 then break end
    if get_indent(buf, next_i) <= indent then
      return next_i + 1
    end
    row = next_i
  end
  return row_begin
end

---@param buf integer
---@param row integer
---@param level_width integer
---@param row_begin integer
---@param row_end integer
---@return integer, integer, integer
local function indent_range(buf, row, level_width, row_begin, row_end)
  local next_row = next_non_blank_row(buf, row)
  local prev_row = prev_non_blank_row(buf, row)
  local indent = get_indent(buf, row)
  local not_blank = next_row == row
  if not_blank then
    if get_indent(buf, next_non_blank_row(buf, row + 1)) > indent then
      return indent / level_width + 1, row, find_range_end(buf, row, row_end, indent)
    end

    if get_indent(buf, prev_non_blank_row(buf, row - 1)) > indent then
      return indent / level_width + 1, find_range_begin(buf, row, row_begin, indent), row
    end
  else
    indent = math.max(get_indent(buf, prev_row), get_indent(buf, next_row))
  end

  return indent / level_width, find_range_begin(buf, row, row_begin, indent - 1),
      find_range_end(buf, row, row_end, indent - 1)
end

---@type vim.api.keyset.set_decoration_provider
local indent_handler = {
  on_win = function(_, win, buf, top, bot)
    if filter(win, buf) == false then return false end

    local cursor_row = vim.api.nvim_win_get_cursor(win)[1] - 1

    local level_width = vim.api.nvim_buf_call(buf, vim.fn.shiftwidth)
    local cursor_indent_level, range_begin, range_end = indent_range(buf, cursor_row, level_width, top, bot + 1)
    local left_col = vim.api.nvim_win_call(win, vim.fn.winsaveview).leftcol

    ---@param row integer
    ---@param indent integer
    local function on_line(row, indent)
      local i = 0
      for raw_col = 0, indent - 1, level_width do
        i = i + 1
        local active = i == math.ceil(cursor_indent_level) and row >= range_begin and row < range_end
        local hl = active and hl_active or hl_inactive
        local col = raw_col - left_col
        if col >= 0 then
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            virt_text = { { indent_char, hl } },
            virt_text_win_col = col,
            ephemeral = true,
            hl_mode = 'combine',
            undo_restore = false,
          })
        end
      end
    end

    local prev_indent = get_indent(buf, prev_non_blank_row(buf, top))
    local row = top
    while row <= bot do
      local next_row = next_non_blank_row(buf, row + 1)
      local next_indent = get_indent(buf, next_row)
      local indent = math.max(prev_indent, next_indent)
      on_line(row, prev_indent)
      if next_row == -1 then
        break
      end
      for i = row + 1, next_row - 1 do
        on_line(i, indent)
      end
      prev_indent = next_indent
      row = next_row
    end
    return false
  end,
}

local current_handler
---@param handler vim.api.keyset.set_decoration_provider
local function set_handler(handler)
  current_handler = handler
  vim.api.nvim_set_decoration_provider(ns, current_handler)
end

local function enabled()
  return current_handler == indent_handler
end

---@type integer?
local redraw_cb
local function enable()
  set_handler(indent_handler)
  redraw_cb = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    callback = function(arg)
      -- if not should_redraw(arg.buf, vim.api.nvim_win_get_cursor(0)[1] - 1) then return end
      vim.api.nvim__redraw {
        valid = true,
        buf = arg.buf,
        range = { 0, -1 },
      }
    end,
    group = augroup,
  })
end

local function disable()
  set_handler {}
  if redraw_cb then vim.api.nvim_del_autocmd(redraw_cb) end
end

return {
  ---@param config indentify.config
  setup = function(config)
    if config.char then
      indent_char = config.char
    end
    if config.filter then
      filter = config.filter
    end
    enable()
  end,
  enabled = enabled,
  enable = enable,
  disable = disable,
  toggle = function()
    if enabled() then disable() else enable() end
  end,
  ---@param buf integer?
  ---@param lnum integer?
  ---@param level_width integer?
  ---@param begin_row integer?
  ---@param end_row integer?
  ---@return integer, integer range_begin, integer range_end
  get_indent_range = function(buf, lnum, level_width, begin_row, end_row)
    local buf = buf or 0
    return indent_range(
      buf,
      lnum and lnum - 1 or vim.api.nvim_win_get_cursor(0)[1] - 1,
      level_width or vim.api.nvim_buf_call(buf, vim.fn.shiftwidth),
      begin_row or 0,
      end_row or vim.api.nvim_buf_line_count(buf)
    )
  end,
}
