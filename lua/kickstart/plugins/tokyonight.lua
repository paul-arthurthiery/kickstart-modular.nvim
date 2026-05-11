return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'Mofiqul/dracula.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      require('dracula').setup {
        italic_comment = false,
      }

      vim.cmd.colorscheme 'dracula'
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
