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
        win = {
          input = {
            keys = {
              ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
            },
          },
        },
      },
    },
    keys = {
      { '<leader>sh', function() Snacks.picker.help() end, desc = '[S]earch [H]elp' },
      { '<leader>sk', function() Snacks.picker.keymaps() end, desc = '[S]earch [K]eymaps' },
      { '<leader>sf', function() Snacks.picker.smart() end, desc = '[S]earch [F]iles (smart/frecency)' },
      { '<leader>ss', function() Snacks.picker.pickers() end, desc = '[S]earch [S]elect picker' },
      { '<leader>sw', function() Snacks.picker.grep_word() end, desc = '[S]earch current [W]ord', mode = { 'n', 'x' } },
      { '<leader>sg', function() Snacks.picker.grep({ args = { '--fixed-strings' } }) end, desc = '[S]earch by [G]rep (literal)' },
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
