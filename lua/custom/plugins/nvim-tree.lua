local VIEW_WIDTH_FIXED = 30
local view_width_max = VIEW_WIDTH_FIXED -- fixed to start

local function get_view_width_max()
  return view_width_max
end

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

      -- Recipes --
      local api = require 'nvim-tree.api'

      -- Open file on creation
      api.events.subscribe(api.events.Event.FileCreated, function(file)
        vim.cmd('edit ' .. vim.fn.fnameescape(file.fname))
      end)
    end,
    opts = {
      hijack_directories = {
        enable = true,
        auto_open = true,
      },
      view = {
        width = {
          min = 30,
          max = get_view_width_max,
        },
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
      live_filter = {
        always_show_folders = false,
      },
      on_attach = function(bufnr)
        local api = require 'nvim-tree.api'
        api.config.mappings.default_on_attach(bufnr)
        -- Free up 's' for flash.nvim, remap system-open to 'O'
        vim.keymap.del('n', 's', { buffer = bufnr })
        vim.keymap.set('n', 'O', api.node.run.system, { buffer = bufnr, desc = 'System open' })

        -- h | Collapse current containing folder
        -- H | Collapse Tree
        -- l | Open node if it is a folder, else edit the file and close tree
        -- L | Open node if it is a folder, else create vsplit of file and keep cursor focus on tree
        local function edit_or_open()
          local node = api.tree.get_node_under_cursor()

          if node.nodes ~= nil then
            -- expand or collapse folder
            api.node.open.edit()
          else
            -- open file
            api.node.open.edit()
            -- Close the tree if file was opened
            api.tree.close()
          end
        end

        -- open as vsplit on current node
        local function vsplit_preview()
          local node = api.tree.get_node_under_cursor()

          if node.nodes ~= nil then
            -- expand or collapse folder
            api.node.open.edit()
          else
            -- open file as vsplit
            api.node.open.vertical()
          end

          -- Finally refocus on tree if it was lost
          api.tree.focus()
        end
        vim.keymap.set('n', 'l', edit_or_open, { buffer = bufnr, desc = 'Edit Or Open' })
        vim.keymap.set('n', 'L', vsplit_preview, { buffer = bufnr, desc = 'Vsplit Preview' })
        vim.keymap.set('n', 'h', api.tree.close, { buffer = bufnr, desc = 'Close' })
        vim.keymap.set('n', 'H', api.tree.collapse_all, { buffer = bufnr, desc = 'Collapse All' })

        -- Toggle adaptative width
        local function toggle_width_adaptive()
          if view_width_max == -1 then
            view_width_max = VIEW_WIDTH_FIXED
          else
            view_width_max = -1
          end

          api.tree.reload()
        end

        vim.keymap.set('n', 'A', toggle_width_adaptive, { buffer = bufnr, desc = 'Toggle Width Adaptive' })
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
