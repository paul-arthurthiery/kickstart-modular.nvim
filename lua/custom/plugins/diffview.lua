return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
  keys = {
    { '<leader>dv', '<cmd>DiffviewOpen<cr>', desc = '[D]iff[v]iew open' },
    { '<leader>dV', '<cmd>DiffviewClose<cr>', desc = '[D]iff[v]iew close' },
  },
}
