return {
  {
    'inkarkat/vim-ReplaceWithRegister',
    init = function()
      vim.g.ReplaceWithRegister_no_default_key_mappings = 1
    end,
    config = function()
      vim.keymap.set('n', '<leader>r', '<Plug>ReplaceWithRegisterOperator')
      vim.keymap.set('x', '<leader>r', '<Plug>ReplaceWithRegisterVisual')
    end,
  },
}
