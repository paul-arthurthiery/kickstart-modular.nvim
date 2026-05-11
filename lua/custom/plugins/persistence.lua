return {
  {
    'rmagatti/auto-session',
    enabled = not vim.g.vscode,
    lazy = false,
    ---@module "auto-session"
    ---@type AutoSession.Config
    opts = {
      suppressed_dirs = { '~/', '~/Downloads', '/' },
      -- Close nvim-tree before saving so it doesn't pollute the session
      pre_save_cmds = {
        function()
          local ok, api = pcall(require, 'nvim-tree.api')
          if ok and require('nvim-tree.view').is_visible() then
            api.tree.close()
          end
        end,
      },
      -- After restoring a session, close any leftover directory buffers
      -- that nvim-tree's hijack_directories may have created
      post_restore_cmds = {
        function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= '' and vim.fn.isdirectory(name) == 1 then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end
        end,
      },
    },
    keys = {
      { '<leader>qs', '<cmd>AutoSession search<cr>', desc = 'Search sessions' },
      { '<leader>qS', '<cmd>AutoSession save<cr>', desc = 'Save session' },
      { '<leader>qd', '<cmd>AutoSession delete<cr>', desc = 'Delete session' },
    },
  },
}
