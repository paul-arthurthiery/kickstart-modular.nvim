return {
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      -- JS/TS linting is handled by eslint LSP — no need for nvim-lint there.
      -- Add non-LSP linters here as needed.
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
      }

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function(ev)
          if not vim.bo[ev.buf].modifiable then
            return
          end
          lint.try_lint()
        end,
      })
    end,
  },
}
