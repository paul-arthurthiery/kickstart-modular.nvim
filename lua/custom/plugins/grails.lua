-- Grails / Groovy filetype settings
return {
  {
    dir = '.',
    name = 'grails-settings',
    config = function()
      vim.filetype.add {
        extension = {
          groovy = 'groovy',
          gradle = 'groovy',
          gsp = 'html',
        },
        filename = {
          ['Jenkinsfile'] = 'groovy',
        },
        pattern = {
          ['.*%.gradle%.kts'] = 'kotlin',
        },
      }

      -- Groovy indent settings (4 spaces is Groovy/Grails convention)
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('grails-settings', { clear = true }),
        pattern = { 'groovy' },
        callback = function()
          vim.bo.tabstop = 4
          vim.bo.shiftwidth = 4
          vim.bo.softtabstop = 4
          vim.bo.expandtab = true
        end,
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
