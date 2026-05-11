return {
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    lazy = false,
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
    config = function(_, o)
      require('nvim-tree').setup(o)
    end,
    opts = {
      hijack_directories = {
        enable = true,
        auto_open = true,
      },
      view = {
        width = 35,
        side = 'left',
      },
      filters = {
        dotfiles = false,
        git_ignored = false,
      },
      git = {
        enable = true,
      },
      renderer = {
        highlight_git = true,
        icons = {
          show = {
            git = true,
          },
        },
      },
      actions = {
        open_file = {
          window_picker = {
            enable = true,
          },
        },
      },
      on_attach = function(bufnr)
        local api = require 'nvim-tree.api'
        api.config.mappings.default_on_attach(bufnr)
        -- Free up 's' for flash.nvim, remap system-open to 'O'
        vim.keymap.del('n', 's', { buffer = bufnr })
        vim.keymap.set('n', 'O', api.node.run.system, { buffer = bufnr, desc = 'System open' })
      end,
      -- Sync tree root to git repo root
      sync_root_with_cwd = true,
      respect_buf_cwd = true,
      update_focused_file = {
        enable = true,
        update_root = {
          enable = true,
        },
      },
    },
    keys = {
      { '<leader>e', '<cmd>NvimTreeToggle<cr>', desc = 'Toggle file explorer' },
      { '<leader>E', '<cmd>NvimTreeFindFile<cr>', desc = 'Find current file in explorer' },
    },
  },
}
