local function file_only_router(lk)
  lk.lstart = nil
  lk.lend = nil
  return require('gitlinker.routers').github_browse(lk)
end

return {
  'linrongbin16/gitlinker.nvim',
  cmd = 'GitLink',
  opts = {},
  keys = {
    { '<leader>gy', function()
      require('gitlinker').link({ router = file_only_router })
    end, mode = 'n', desc = 'Copy git file link to clipboard' },
    { '<leader>gy', '<cmd>GitLink<cr>', mode = 'v', desc = 'Copy git link with lines to clipboard' },
    { '<leader>gY', function()
      require('gitlinker').link({ action = require('gitlinker.actions').system, router = file_only_router })
    end, mode = 'n', desc = 'Open git file link in browser' },
    { '<leader>gY', '<cmd>GitLink!<cr>', mode = 'v', desc = 'Open git link with lines in browser' },
  },
}
