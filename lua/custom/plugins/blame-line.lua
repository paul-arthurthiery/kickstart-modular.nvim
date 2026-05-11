return {
  'braxtons12/blame_line.nvim',
  event = 'BufReadPost',
  opts = {
    show_in_visual = false,
    show_in_insert = false,
    delay = 200,
    template = '<author> • <author-time> • <summary>',
    date = {
      relative = true,
    },
  },
}
