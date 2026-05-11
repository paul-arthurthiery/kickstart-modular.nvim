-- nvim v0.8.0
return {
  'kdheepak/lazygit.nvim',
  lazy = true,
  cmd = {
    'LazyGit',
    'LazyGitConfig',
    'LazyGitCurrentFile',
    'LazyGitFilter',
    'LazyGitFilterCurrentFile',
  },
  -- optional for floating window border decoration
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  init = function()
    vim.g.lazygit_use_neovim_remote = 1
    -- Set GIT_EDITOR so lazygit commit/rebase editors open in this nvim instance
    if vim.fn.executable('nvr') == 1 then
      vim.env.GIT_EDITOR = "nvr -cc split --remote-wait +'set bufhidden=wipe'"
      vim.env.VISUAL = "nvr -cc split --remote-wait +'set bufhidden=wipe'"
    end
  end,
  -- setting the keybinding for LazyGit with 'keys' is recommended in
  -- order to load the plugin when the command is run for the first time
  keys = {
    { '<leader>lg', '<cmd>LazyGit<cr>', desc = 'LazyGit' },
  },
}
