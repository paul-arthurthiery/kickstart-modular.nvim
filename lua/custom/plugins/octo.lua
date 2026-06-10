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

    local get_file_diff_context = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local octo_utils = require('octo.utils')

      if not octo_utils.in_diff_window(bufnr) then
        return nil, 'Not in an Octo review diff buffer'
      end

      local props = vim.b[bufnr].octo_diff_props
      if not props or not props.path then
        return nil, 'Could not determine file path from diff buffer'
      end

      -- Get repo and PR number from env (set by launcher)
      local repo = vim.env.OCTO_REPO
      local pr = vim.env.OCTO_PR

      if not repo or repo == '' or not pr or pr == '' then
        return nil, 'Missing OCTO_REPO/OCTO_PR env vars'
      end

      -- Get base and head commit SHAs
      local result = vim.fn.system({
        'gh', 'pr', 'view', pr,
        '--repo', repo,
        '--json', 'baseRefOid,headRefOid',
        '--jq', '.baseRefOid + "\t" + .headRefOid',
      })

      if vim.v.shell_error ~= 0 or not result or result == '' then
        return nil, 'Could not fetch PR base/head SHAs'
      end

      result = vim.trim(result)
      local base_sha, head_sha = result:match('^([^\t]+)\t(.+)$')
      if not base_sha or not head_sha then
        return nil, 'Unexpected gh pr view output'
      end

      return {
        repo = repo,
        path = props.path,
        base_sha = base_sha,
        head_sha = head_sha,
      }, nil
    end

    local toggle_file_difft_float = function()
      -- Toggle off if already open
      if diff_float.win and vim.api.nvim_win_is_valid(diff_float.win) then
        close_diff_float()
        return
      end

      local ctx, err = get_file_diff_context()
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
        title = string.format(' difft: %s ', ctx.path),
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

      -- Build a script that fetches both file versions via gh api and runs difft
      local term_cmd = string.format(
        [[
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

base_file="$tmpdir/base_%s"
head_file="$tmpdir/head_%s"

# Fetch base version
gh api "repos/%s/contents/%s?ref=%s" --jq '.content' 2>/dev/null | base64 -d > "$base_file" 2>/dev/null || echo "" > "$base_file"

# Fetch head version
gh api "repos/%s/contents/%s?ref=%s" --jq '.content' 2>/dev/null | base64 -d > "$head_file" 2>/dev/null || echo "" > "$head_file"

# Run difftastic
difft --color=always --display=side-by-side-show-both "$base_file" "$head_file"

echo ""
echo "[Press q to close]"
read -r
]],
        vim.fn.fnamemodify(ctx.path, ':t'),
        vim.fn.fnamemodify(ctx.path, ':t'),
        ctx.repo, ctx.path, ctx.base_sha,
        ctx.repo, ctx.path, ctx.head_sha
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
    vim.keymap.set('n', '<leader>op', toggle_file_difft_float, { desc = 'Octo difftastic peek (current file)' })
  end,
}
