return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  event = 'BufReadCmd octo://*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'folke/snacks.nvim',
  },
  opts = {
    picker = 'snacks',
  },
  config = function(_, opts)
    require('octo').setup(opts)

    local diff_float = {
      win = nil,
      buf = nil,
    }

    local close_diff_float = function()
      if diff_float.win and vim.api.nvim_win_is_valid(diff_float.win) then
        vim.api.nvim_win_close(diff_float.win, true)
      end
      diff_float.win = nil
      diff_float.buf = nil
    end

    local get_pr_context = function()
      -- Try buffer-local Octo state first
      local buf_repo = vim.b.octo_repo
      local buf_number = vim.b.octo_number

      local repo = buf_repo
      local number = buf_number

      -- Fallback to env vars if not in an Octo buffer
      if not repo or repo == '' then
        repo = vim.env.OCTO_REPO
      end
      if not number then
        number = vim.env.OCTO_PR and tonumber(vim.env.OCTO_PR) or nil
      end

      if not repo or repo == '' then
        return nil, 'Could not determine PR repository'
      end
      if not number then
        return nil, 'Could not determine PR number'
      end

      local details = vim.fn.systemlist({
        'gh',
        'pr',
        'view',
        tostring(number),
        '--repo',
        repo,
        '--json',
        'baseRefName,headRefName',
        '--jq',
        '.baseRefName + "\t" + .headRefName',
      })

      if vim.v.shell_error ~= 0 or not details[1] or details[1] == '' then
        return nil, 'Could not fetch PR base/head refs'
      end

      local base, head = details[1]:match('^([^\t]+)\t(.+)$')
      if not base or not head then
        return nil, 'Unexpected gh pr view output'
      end

      return {
        repo = repo,
        base = base,
        head = head,
      }, nil
    end

    local toggle_pr_difft_float = function()
      if diff_float.win and vim.api.nvim_win_is_valid(diff_float.win) then
        close_diff_float()
        return
      end

      local ctx, err = get_pr_context()
      if err then
        vim.notify(err, vim.log.levels.ERROR)
        return
      end

      local width = math.floor(vim.o.columns * 0.92)
      local height = math.floor(vim.o.lines * 0.88)
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = string.format(' difft: %s...%s (%s) ', ctx.base, ctx.head, ctx.repo),
        title_pos = 'center',
      })

      diff_float.win = win
      diff_float.buf = buf

      vim.bo[buf].bufhidden = 'wipe'

      vim.keymap.set('n', 'q', close_diff_float, { buffer = buf, silent = true, nowait = true })
      vim.keymap.set('t', 'q', function()
        close_diff_float()
      end, { buffer = buf, silent = true, nowait = true })
      vim.keymap.set('t', '<Esc><Esc>', function()
        close_diff_float()
      end, { buffer = buf, silent = true })

      local term_cmd = string.format(
        'git fetch origin %s %s --quiet 2>/dev/null; git -c diff.external=difft diff --ext-diff origin/%s...HEAD; echo ""; echo "[Press q to close]"; read -r',
        vim.fn.shellescape(ctx.base),
        vim.fn.shellescape(ctx.head),
        ctx.base
      )
      vim.fn.termopen({ 'zsh', '-lc', term_cmd }, {
        on_exit = function()
          vim.schedule(function()
            close_diff_float()
          end)
        end,
      })
      vim.cmd 'startinsert'
    end

    vim.keymap.set('n', '<leader>or', '<cmd>Octo review start<cr>', { desc = 'Octo review start' })
    vim.keymap.set('n', '<leader>oR', '<cmd>Octo review resume<cr>', { desc = 'Octo review resume' })
    vim.keymap.set('n', '<leader>os', '<cmd>Octo review submit<cr>', { desc = 'Octo review submit' })
    vim.keymap.set('n', '<leader>od', '<cmd>Octo review discard<cr>', { desc = 'Octo review discard' })
    vim.keymap.set('n', '<leader>op', toggle_pr_difft_float, { desc = 'Octo difftastic peek' })
  end,
}
