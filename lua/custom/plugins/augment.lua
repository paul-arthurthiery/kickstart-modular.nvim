return {
  'augmentcode/augment.vim',
  lazy = false,
  init = function()
    vim.g.augment_workspace_folders = { vim.fn.getcwd() }
  end,
}
