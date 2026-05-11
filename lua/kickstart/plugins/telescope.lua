return {
  {
    'ibhagwan/fzf-lua',
    dependencies = {
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      local fzf = require 'fzf-lua'

      fzf.setup {
        'default-title',
        fzf_opts = {
          ['--layout'] = 'reverse',
        },
        files = {
          fzf_opts = {
            ['--scheme'] = 'path',
          },
        },
        grep = {
          formatter = 'path.filename_first',
          -- Don't scroll to matched content — keeps filename visible.
          -- Preview pane shows the full match in context.
          fzf_opts = {
            ['--no-hscroll'] = '',
          },
        },
      }

      -- Register as vim.ui.select handler (replaces telescope-ui-select)
      fzf.register_ui_select()

      vim.keymap.set('n', '<leader>sh', fzf.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', fzf.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', fzf.builtin, { desc = '[S]earch [S]elect fzf-lua' })
      vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', function()
        fzf.grep { search = '', no_esc = true }
      end, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', fzf.diagnostics_workspace, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', fzf.buffers, { desc = '[ ] Find existing buffers' })

      vim.keymap.set('n', '<leader>/', fzf.lgrep_curbuf, { desc = '[/] Fuzzily search in current buffer' })

      vim.keymap.set('n', '<leader>s/', function()
        local bufs = vim.tbl_filter(function(b)
          return vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_get_name(b) ~= ''
        end, vim.api.nvim_list_bufs())
        local paths = vim.tbl_map(vim.api.nvim_buf_get_name, bufs)
        fzf.live_grep { search_paths = paths, prompt = 'Live Grep in Open Files> ' }
      end, { desc = '[S]earch [/] in Open Files' })

      vim.keymap.set('n', '<leader>sn', function()
        fzf.files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
