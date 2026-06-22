return {
  'zbirenbaum/copilot.lua',
  event = 'InsertEnter',
  config = function()
    require('copilot').setup {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = '<Tab>',
          dismiss = '<C-]>',
          next = '<M-]>',
          prev = '<M-[>',
        },
      },
      panel = { enabled = false },
      workspace_folders = { vim.fn.getcwd() },
    }
  end,
}
