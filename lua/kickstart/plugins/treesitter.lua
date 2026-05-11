-- Treesitter: parser installation + highlighting/indentation for Nvim 0.12+
-- Note: nvim-treesitter now only handles parser installation.
-- Highlighting and indentation are managed natively via vim.treesitter.start().

local parsers = {
  'bash',
  'c',
  'diff',
  'html',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'query',
  'vim',
  'vimdoc',
  'javascript',
  'typescript',
  'tsx',
  'rust',
  'groovy',
  'java',
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.config',
    opts = {
      install_dir = vim.fn.stdpath 'data' .. '/site',
    },
    config = function(_, opts)
      require('nvim-treesitter.config').setup(opts)

      -- Install parsers listed above (async, non-blocking)
      require('nvim-treesitter.install').install(parsers)

      -- Enable treesitter highlighting and indentation for all filetypes
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
