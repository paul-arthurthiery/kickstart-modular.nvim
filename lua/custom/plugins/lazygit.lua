-- Use snacks.nvim's built-in lazygit integration.
-- The default nvim-remote preset opens files in a new tabpage because the
-- floating terminal can't :edit. We intercept this with a TabNewEntered
-- autocmd that moves the buffer back and closes the extra tabpage.
return {
  'folke/snacks.nvim',
  keys = {
    { '<leader>lg', function() Snacks.lazygit() end, desc = 'LazyGit' },
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
        local new_tab = vim.fn.tabpagenr('$')
        if new_tab > 1 then
          vim.cmd('tablast | tabclose')
        end
        lazygit_tab = nil
      end,
    })
  end,
}
