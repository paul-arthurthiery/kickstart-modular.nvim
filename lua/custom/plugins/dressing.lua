return {
  'stevearc/dressing.nvim',
  event = 'VeryLazy',
  opts = {
    input = {
      enabled = true,
    },
    select = {
      enabled = false, -- fzf-lua handles vim.ui.select
    },
  },
}
