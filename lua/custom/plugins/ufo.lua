return {
  'kevinhwang91/nvim-ufo',
  dependencies = { 'kevinhwang91/promise-async' },
  lazy = false,
  keys = {
    { 'zR', function() require('ufo').openAllFolds() end, desc = 'Open all folds' },
    { 'zM', function() require('ufo').closeAllFolds() end, desc = 'Close all folds' },
    { 'zK', function() require('ufo').peekFoldedLinesUnderCursor() end, desc = 'Peek fold' },
  },
  opts = {
    provider_selector = function(_, filetype, _)
      if filetype == 'octo' then return require('custom.octo-ufo-provider') end
      return { 'lsp', 'indent' }
    end,
    fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
      local newVirtText = {}
      local suffix = ('  %d lines'):format(endLnum - lnum)
      local sufWidth = vim.fn.strdisplaywidth(suffix)
      local targetWidth = width - sufWidth
      local curWidth = 0
      for _, chunk in ipairs(virtText) do
        local chunkText = chunk[1]
        local chunkWidth = vim.fn.strdisplaywidth(chunkText)
        if targetWidth > curWidth + chunkWidth then
          table.insert(newVirtText, chunk)
        else
          chunkText = truncate(chunkText, targetWidth - curWidth)
          table.insert(newVirtText, { chunkText, chunk[2] })
          break
        end
        curWidth = curWidth + chunkWidth
      end
      table.insert(newVirtText, { suffix, 'MoreMsg' })
      return newVirtText
    end,
  },
}
