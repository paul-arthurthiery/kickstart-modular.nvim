-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Split/pane navigation is handled by vim-tmux-navigator plugin
-- which seamlessly navigates both nvim splits and tmux panes with <C-h/j/k/l>

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Restart nvim in-place via tmux (save session, quit, relaunch)
vim.keymap.set('n', '<leader>qr', function()
  -- Remember nvim-tree state before save closes it
  local tree_ok, tree_view = pcall(require, 'nvim-tree.view')
  local tree_was_open = tree_ok and tree_view.is_visible()
  local flag = vim.fn.stdpath 'state' .. '/nvim_tree_was_open'
  if tree_was_open then
    vim.fn.writefile({ '1' }, flag)
  else
    vim.fn.delete(flag)
  end

  vim.cmd 'silent! AutoSession save'

  local pane = vim.env.TMUX_PANE
  if pane then
    local cwd = vim.fn.getcwd()
    vim.fn.system(string.format("tmux respawn-pane -k -t %s 'cd %s && exec $SHELL -c nvim'", pane, vim.fn.shellescape(cwd)))
  else
    vim.cmd 'qa'
  end
end, { desc = 'Restart nvim (save, quit, relaunch)' })

-- Break line keymap
vim.keymap.set('n', '<leader>j', 'a<CR><Esc>', {
  silent = true,
  desc = 'Break line at cursor',
})

-- Close all buffers except current and nvim-tree
vim.keymap.set('n', '<leader>bo', '<cmd>BufferLineCloseOthers<cr>', { desc = 'Close all other buffers' })

-- Copy relative file path to clipboard
vim.keymap.set('n', '<leader>cp', function()
  local path = vim.fn.fnamemodify(vim.fn.expand '%', ':.')
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path)
end, { desc = '[C]opy relative [p]ath' })

-- vim: ts=2 sts=2 sw=2 et
