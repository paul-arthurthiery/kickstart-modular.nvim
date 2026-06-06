-- from https://github.com/ruicsh/nvim-config/blob/main/lua/plugins/snacks.picker.lua
-- Open picker.select to search for a directory to search in
local grep_directory = function()
  local snacks = require 'snacks'
  local has_fd = vim.fn.executable 'fd' == 1
  local cwd = vim.fn.getcwd()

  local function show_picker(dirs)
    if #dirs == 0 then
      vim.notify('No directories found', vim.log.levels.WARN)
      return
    end

    local items = {}
    for i, item in ipairs(dirs) do
      table.insert(items, {
        idx = i,
        file = item,
        text = item,
      })
    end

    snacks.picker {
      confirm = function(picker, item)
        picker:close()
        snacks.picker.grep {
          dirs = { item.file },
        }
      end,
      items = items,
      format = function(item, _)
        local file = item.file
        local ret = {}
        local a = Snacks.picker.util.align
        local icon, icon_hl = Snacks.util.icon(file.ft, 'directory')
        ret[#ret + 1] = { a(icon, 3), icon_hl }
        ret[#ret + 1] = { ' ' }
        local path = file:gsub('^' .. vim.pesc(cwd) .. '/', '')
        ret[#ret + 1] = { a(path, 20), 'Directory' }

        return ret
      end,
      layout = {
        preview = false,
        preset = 'vertical',
      },
      title = 'Grep in directory',
    }
  end

  if has_fd then
    local cmd = { 'fd', '--type', 'directory', '--hidden', '--no-ignore-vcs', '--exclude', '.git' }
    local dirs = {}

    vim.fn.jobstart(cmd, {
      on_stdout = function(_, data, _)
        for _, line in ipairs(data) do
          if line and line ~= '' then
            table.insert(dirs, line)
          end
        end
      end,
      on_exit = function(_, code, _)
        if code == 0 then
          show_picker(dirs)
        else
          -- Fallback to plenary if fd fails
          local fallback_dirs = require('plenary.scandir').scan_dir(cwd, {
            only_dirs = true,
            respect_gitignore = true,
          })
          show_picker(fallback_dirs)
        end
      end,
    })
  else
    -- Use plenary if fd is not available
    local dirs = require('plenary.scandir').scan_dir(cwd, {
      only_dirs = true,
      respect_gitignore = true,
    })
    show_picker(dirs)
  end
end
-- The default nvim-remote preset opens files in a new tabpage because the
-- floating terminal can't :edit. We intercept this with a TabNewEntered
-- autocmd that moves the buffer back and closes the extra tabpage.
return {
  'folke/snacks.nvim',
  keys = {
    {
      '<leader>lg',
      function()
        Snacks.lazygit()
      end,
      desc = 'LazyGit',
    },
    {
      '<leader>s?',
      function()
        grep_directory()
      end,
      desc = 'Grep in directory',
    },
  },
  opts = {
    lazygit = {},
  },
  init = function()
    local augroup = vim.api.nvim_create_augroup('LazygitEdit', { clear = true })
    local lazygit_tab = nil

    -- Before opening lazygit, remember which tabpage we're on
    vim.api.nvim_create_autocmd('TermOpen', {
      group = augroup,
      pattern = '*lazygit*',
      callback = function()
        lazygit_tab = vim.api.nvim_get_current_tabpage()
      end,
    })

    -- When a new tabpage appears while lazygit is running, steal the buffer
    vim.api.nvim_create_autocmd('TabNewEntered', {
      group = augroup,
      callback = function()
        if lazygit_tab == nil then
          return
        end
        local buf = vim.api.nvim_get_current_buf()
        local bufname = vim.api.nvim_buf_get_name(buf)
        -- Only act on real file buffers (not terminals)
        if bufname == '' or vim.bo[buf].buftype ~= '' then
          return
        end
        local cursor = vim.api.nvim_win_get_cursor(0)
        -- Go back to original tab and open the buffer there
        vim.api.nvim_set_current_tabpage(lazygit_tab)
        vim.api.nvim_set_current_buf(buf)
        pcall(vim.api.nvim_win_set_cursor, 0, cursor)
        -- Close the extra tabpage
        local new_tab = vim.fn.tabpagenr '$'
        if new_tab > 1 then
          vim.cmd 'tablast | tabclose'
        end
        lazygit_tab = nil
      end,
    })
  end,
}
