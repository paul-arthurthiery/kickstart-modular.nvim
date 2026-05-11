return {
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    lazy = false,
    opts = {
      options = {
        offsets = {
          {
            filetype = 'NvimTree',
            text = 'File Explorer',
            highlight = 'Directory',
            separator = true,
          },
        },
        show_buffer_close_icons = true,
        show_close_icon = false,
        separator_style = 'thin',
        diagnostics = 'nvim_lsp',
      },
    },
    keys = {
      { '<S-l>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next buffer' },
      { '<S-h>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Previous buffer' },
      {
        '<leader>bd',
        function()
          local buf = vim.api.nvim_get_current_buf()
          local bufs = vim.fn.getbufinfo({ buflisted = 1 })
          if #bufs <= 1 then
            -- Last buffer — just quit nvim
            vim.cmd 'quit'
            return
          end
          -- Switch to previous buffer first so the window doesn't collapse
          vim.cmd 'BufferLineCyclePrev'
          vim.cmd('bdelete ' .. buf)
        end,
        desc = 'Close buffer',
      },
    },
  },
}
