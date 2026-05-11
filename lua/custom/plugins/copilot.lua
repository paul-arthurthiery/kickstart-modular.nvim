return {
  'github/copilot.vim',
  lazy = false,
  init = function()
    vim.g.copilot_filetypes = { ['*'] = false }
    vim.g.copilot_no_tab_map = true
  end,
}
