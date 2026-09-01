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
local show_range_diff = function(vs_head, sel_start, sel_end)
  if sel_start > sel_end then
    sel_start, sel_end = sel_end, sel_start
  end

  local file = vim.fn.expand '%:p'
  local rel_file = vim.fn.expand '%'

  vim.notify(string.format('range: %d-%d', sel_start, sel_end), vim.log.levels.INFO)

  if file == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  local cmd = vs_head and { 'git', 'diff', 'HEAD', '--', file } or { 'git', 'diff', '--', file }

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify('git diff failed: ' .. (result.stderr or ''), vim.log.levels.ERROR)
        return
      end

      local output = result.stdout or ''
      if output == '' then
        vim.notify('No changes in selection', vim.log.levels.INFO)
        return
      end

      -- Parse unified diff, collect only hunks overlapping the selection
      local matched_lines = {}
      local current_hunk = nil
      local hunk_start, hunk_end

      local function flush()
        if current_hunk and hunk_start <= sel_end and hunk_end >= sel_start then
          local kept = {}
          local new_line = hunk_start
          for i, l in ipairs(current_hunk) do
            if i == 1 then
              -- @@ header, added below only if we keep something
            elseif l:match '^%-' then
              -- removed line: emit if within selection range
              if new_line >= sel_start and new_line <= sel_end then
                table.insert(kept, l)
              end
            elseif l:match '^%+' then
              -- added line: emit only if in selection range
              if new_line >= sel_start and new_line <= sel_end then
                table.insert(kept, l)
              end
              new_line = new_line + 1
            else
              -- context line: advance counter, keep it
              if new_line >= sel_start and new_line <= sel_end then
                table.insert(kept, l)
              end
              new_line = new_line + 1
            end
          end
          if #kept > 0 then
            table.insert(matched_lines, current_hunk[1]) -- @@ header
            for _, l in ipairs(kept) do
              table.insert(matched_lines, l)
            end
          end
        end
        current_hunk = nil
      end

      for line in output:gmatch '[^\n]*' do
        if line == '' then
          goto continue
        end
        local trimmed = line:match '^%s*(.*)'
        local c, d = trimmed:match '^@@ %-%d+,?%d* %+(%d+),?(%d*) @@'
        if c then
          flush()
          c = tonumber(c)
          d = d == '' and 1 or tonumber(d)
          hunk_start = c
          hunk_end = c + (d > 0 and d - 1 or 0)
          current_hunk = { trimmed }
        elseif current_hunk then
          table.insert(current_hunk, trimmed)
        end
        ::continue::
      end
      flush()

      if #matched_lines == 0 then
        vim.notify('No changes in selection', vim.log.levels.INFO)
        return
      end

      local label = vs_head and 'HEAD' or 'index'
      Snacks.win.new {
        title = string.format(' diff vs %s (L%d–%d) ', label, sel_start, sel_end),
        title_pos = 'center',
        text = table.concat(matched_lines, '\n'),
        ft = 'diff',
        width = 0.7,
        height = 0.4,
        bo = { modifiable = false, readonly = true },
        keys = { q = 'close' },
      }
    end)
  end)
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
    {
      '<leader>hd',
      function()
        show_range_diff(false, vim.fn.line "'<", vim.fn.line "'>")
      end,
      mode = 'v',
      desc = 'git [d]iff selection vs index',
    },
    {
      '<leader>hD',
      function()
        show_range_diff(true, vim.fn.line "'<", vim.fn.line "'>")
      end,
      mode = 'v',
      desc = 'git [D]iff selection vs HEAD',
    },
  },
  opts = {
    lazygit = {},
    notifier = {},
    image = {
      formats = {
        'png',
        'jpg',
        'jpeg',
        'gif',
        'bmp',
        'webp',
        'tiff',
        'heic',
        'avif',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
        'pdf',
        'icns',
        'svg',
      },
    },
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
