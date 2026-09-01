-- Picker configuration using snacks.nvim picker (replaces fzf-lua)
-- Features: frecency scoring, fast close, built-in preview
return {
  {
    'folke/snacks.nvim',
    opts = {
      picker = {
        matcher = {
          frecency = true,
        },
        actions = {
          -- Hide layout then confirm. Avoids the stopinsert + vim.schedule
          -- stagger that makes confirm close visually slow from insert mode.
          fast_confirm = function(picker)
            if picker.layout and picker.layout.hide then
              picker.layout:hide()
            end
            return picker:action('confirm')
          end,
        },
        win = {
          input = {
            keys = {
              ['<CR>'] = { 'fast_confirm', mode = { 'i', 'n' } },
            },
          },
          list = {
            keys = {
              ['<CR>'] = { 'fast_confirm', mode = { 'n' } },
            },
          },
        },
        on_show = function(picker)
          -- Patch picker:close() to instantly hide all layout windows before
          -- snacks' staggered close runs (cancel/Esc path).
          -- layout:hide() uses nvim_win_set_config({ hide = true }) — no WinClosed event.
          local orig_close = picker.close
          picker.close = function(self)
            if self.layout and self.layout.hide then
              self.layout:hide()
            end
            orig_close(self)
          end
        end,
      },
    },
    keys = {
      { '<leader>sh', function() Snacks.picker.help() end, desc = '[S]earch [H]elp' },
      { '<leader>sk', function() Snacks.picker.keymaps() end, desc = '[S]earch [K]eymaps' },
      { '<leader>sf', function() Snacks.picker.smart() end, desc = '[S]earch [F]iles (smart/frecency)' },
      { '<leader>ss', function() Snacks.picker.pickers() end, desc = '[S]earch [S]elect picker' },
      { '<leader>sw', function() Snacks.picker.grep_word() end, desc = '[S]earch current [W]ord', mode = { 'n', 'x' } },
      { '<leader>sg', function()
        local open_grep
        open_grep = function(extra_opts)
          local opts = vim.tbl_deep_extend('force', {
            args = { '--fixed-strings' },
            win = {
              input = {
                keys = {
                  ['<C-x>'] = {
                    '<C-x>',
                    function(_win)
                      local picker = Snacks.picker.get()[1]
                      if not picker then return end
                      local query = picker.input.filter.search
                      local current_exclude = picker._sg_exclude or {}
                      picker:close()
                      vim.ui.input({ prompt = 'Exclude globs (comma-separated): ' }, function(input)
                        local exclude = vim.deepcopy(current_exclude)
                        if input and input ~= '' then
                          for pat in input:gmatch('[^,]+') do
                            table.insert(exclude, vim.trim(pat))
                          end
                        end
                        open_grep({ search = query, exclude = exclude, _sg_exclude = exclude })
                      end)
                    end,
                    mode = { 'i', 'n' },
                    desc = 'Exclude file globs',
                  },
                },
              },
            },
          }, extra_opts or {})
          Snacks.picker.grep(opts)
        end
        open_grep()
      end, desc = '[S]earch by [G]rep (literal)' },
      { '<leader>sG', function() Snacks.picker.grep() end, desc = '[S]earch by [G]rep (regex)' },
      { '<leader>sd', function() Snacks.picker.diagnostics() end, desc = '[S]earch [D]iagnostics' },
      { '<leader>sr', function() Snacks.picker.resume() end, desc = '[S]earch [R]esume' },
      { '<leader>s.', function() Snacks.picker.recent() end, desc = '[S]earch Recent Files' },
      { '<leader><leader>', function() Snacks.picker.buffers() end, desc = '[ ] Find existing buffers' },
      { '<leader>/', function() Snacks.picker.lines() end, desc = '[/] Fuzzily search in current buffer' },
      { '<leader>s/', function() Snacks.picker.grep_buffers() end, desc = '[S]earch [/] in Open Files' },
      { '<leader>sn', function() Snacks.picker.files { cwd = vim.fn.stdpath 'config' } end, desc = '[S]earch [N]eovim files' },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
