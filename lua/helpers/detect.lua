-- Auto-detect formatters based on project config files.
-- Uses vim.fs.find() to search upward from the buffer's directory.

local M = {}

---@alias ToolDef { name: string, markers: string[], fallback?: string }

---@type ToolDef[]
local formatter_defs = {
  {
    name = 'oxfmt',
    markers = { '.oxfmtrc.json', '.oxfmtrc', 'oxfmt.json' },
  },
  {
    name = 'biome',
    markers = { 'biome.json', 'biome.jsonc' },
  },
  {
    name = 'deno_fmt',
    markers = { 'deno.json', 'deno.jsonc' },
  },
  {
    name = 'prettierd',
    fallback = 'prettier',
    markers = {
      '.prettierrc',
      '.prettierrc.json',
      '.prettierrc.yml',
      '.prettierrc.yaml',
      '.prettierrc.json5',
      '.prettierrc.js',
      '.prettierrc.cjs',
      '.prettierrc.mjs',
      '.prettierrc.toml',
      'prettier.config.js',
      'prettier.config.cjs',
      'prettier.config.mjs',
      'prettier.config.ts',
    },
  },
}

--- Search upward from the buffer's directory for any of the given marker files.
---@param bufnr integer
---@param markers string[]
---@return boolean
local function has_config(bufnr, markers)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == '' then
    return false
  end
  local found = vim.fs.find(markers, {
    upward = true,
    path = vim.fs.dirname(bufname),
    stop = vim.uv.os_homedir(),
  })
  return #found > 0
end

--- Check if a tool binary is available (globally or in node_modules/.bin/).
---@param bufnr integer
---@param name string
---@return boolean
local function is_available(bufnr, name)
  if vim.fn.executable(name) == 1 then
    return true
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    local found = vim.fs.find('node_modules/.bin/' .. name, {
      upward = true,
      path = vim.fs.dirname(bufname),
      stop = vim.uv.os_homedir(),
    })
    return #found > 0
  end
  return false
end

--- Detect which formatter to use for a JS/TS buffer.
--- Returns the formatter names for conform.nvim (first match wins).
---@param bufnr integer
---@return string[]
function M.formatter(bufnr)
  if vim.b[bufnr]._detected_formatter then
    return vim.b[bufnr]._detected_formatter
  end

  local result = {}
  for _, def in ipairs(formatter_defs) do
    if has_config(bufnr, def.markers) then
      if is_available(bufnr, def.name) then
        result = { def.name }
        break
      elseif def.fallback and is_available(bufnr, def.fallback) then
        result = { def.fallback }
        break
      end
    end
  end

  vim.b[bufnr]._detected_formatter = result
  return result
end

return M
