local detect = require 'helpers.detect'

local js_fts = {
  'javascript',
  'javascriptreact',
  'typescript',
  'typescriptreact',
}

local formatters_by_ft = {
  lua = { 'stylua' },
}

-- JS/TS filetypes use dynamic detection for formatter only
-- (linter --fix is handled by eslint LSP via LspEslintFixAll)
for _, ft in ipairs(js_fts) do
  formatters_by_ft[ft] = function(bufnr)
    return detect.formatter(bufnr)
  end
end

return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        end
        return {
          timeout_ms = 3000,
          lsp_format = 'fallback',
        }
      end,
      formatters_by_ft = formatters_by_ft,
      formatters = {
        oxfmt = {
          command = function()
            local local_bin = vim.fs.find('node_modules/.bin/oxfmt', {
              upward = true,
              path = vim.fn.getcwd(),
              stop = vim.uv.os_homedir(),
            })[1]
            return local_bin or 'oxfmt'
          end,
          args = { '--stdin-filepath', '$FILENAME' },
          stdin = true,
        },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
