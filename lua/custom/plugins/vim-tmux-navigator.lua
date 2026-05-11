return {
  'christoomey/vim-tmux-navigator',
  init = function()
    -- Disable default tmux navigator mappings, we define our own
    vim.g.tmux_navigator_no_mappings = 1
  end,
  config = function()
    local function navigate(direction)
      return function()
        -- Don't navigate away from terminal buffers (lazygit, etc.)
        if vim.bo.buftype == 'terminal' then
          -- Send the key to the terminal instead
          local keys = { h = '<C-h>', j = '<C-j>', k = '<C-k>', l = '<C-l>' }
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys[direction], true, false, true), 't', false)
          return
        end
        vim.cmd('TmuxNavigate' .. ({ h = 'Left', j = 'Down', k = 'Up', l = 'Right' })[direction])
      end
    end

    vim.keymap.set('n', '<C-h>', navigate 'h', { desc = 'Navigate left (split/pane)' })
    vim.keymap.set('n', '<C-j>', navigate 'j', { desc = 'Navigate down (split/pane)' })
    vim.keymap.set('n', '<C-k>', navigate 'k', { desc = 'Navigate up (split/pane)' })
    vim.keymap.set('n', '<C-l>', navigate 'l', { desc = 'Navigate right (split/pane)' })
  end,
}
