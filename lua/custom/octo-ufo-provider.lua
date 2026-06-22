local foldingrange = require('ufo.model.foldingrange')
local ns = vim.api.nvim_create_namespace('octo_marks')

-- ponytail: extmarks survive ufo's zE; offsets correct for octo's fold placement
return function(bufnr)
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
  local ranges = {}
  for _, mark in ipairs(marks) do
    local start_row = mark[2]
    local end_row = mark[4] and mark[4].end_row + 1
    if end_row and end_row > start_row then
      table.insert(ranges, foldingrange.new(start_row, end_row))
    end
  end
  return ranges
end
