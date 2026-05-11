return {
  {
    'andymass/vim-matchup',
    lazy = false,
    init = function()
      vim.g.matchup_surround_enabled = 1
      vim.g.matchup_matchparen_offscreen = { method = 'popup' }
      vim.g.matchup_treesitter_stopline = 500
    end,
  },
}
