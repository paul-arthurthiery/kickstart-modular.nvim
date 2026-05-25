return {
  'stevearc/dressing.nvim',
  event = 'VeryLazy',
  opts = {
    input = {
      enabled = true,
    },
    select = {
      enabled = false, -- snacks.picker handles vim.ui.select
    },
  },
}
