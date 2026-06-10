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
    local snacks = require('snacks')

    if vim.g.octo_review_mode then
      vim.api.nvim_set_hl(0, 'DiffAdd', { bg = '#1a3a2a' })
      vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#3a1a1a' })
      vim.api.nvim_set_hl(0, 'DiffChange', { bg = 'NONE' })
      vim.api.nvim_set_hl(0, 'DiffText', { bg = '#2a4a3a' })
    end

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

    local in_octo_review = function()
      local ok, reviews = pcall(require, 'octo.reviews')
      if not ok then
        return false
      end
      return reviews.get_current_layout() ~= nil
    end

    local open_pr_files_picker = function()
      local reviews = require('octo.reviews')
      local layout = reviews.get_current_layout()
      if not layout then
        return
      end

      local items = {}
      for i, file in ipairs(layout.files) do
        items[#items + 1] = {
          idx = i,
          text = file.path,
          file = file.path,
          _file_entry = file,
        }
      end

      snacks.picker({
        title = 'PR Changed Files',
        items = items,
        layout = { preview = false, preset = 'vertical' },
        confirm = function(picker, item)
          picker:close()
          if item and item._file_entry then
            layout:set_current_file(item._file_entry)
          end
        end,
      })
    end

    local open_pr_grep_picker = function()
      local reviews = require('octo.reviews')
      local layout = reviews.get_current_layout()
      if not layout then
        return
      end

      local files = layout.files

      local build_items = function()
        local items = {}
        for _, file in ipairs(files) do
          local lines = file.right_lines or {}
          for lnum, line in ipairs(lines) do
            if line ~= '' then
              items[#items + 1] = {
                text = string.format('%s:%d:%s', file.path, lnum, line),
                file = file.path,
                lnum = lnum,
                _file_entry = file,
              }
            end
          end
        end

        snacks.picker({
          title = 'PR Grep (head)',
          items = items,
          layout = { preview = false, preset = 'vertical' },
          confirm = function(picker, item)
            picker:close()
            if not item or not item._file_entry then
              return
            end
            layout:set_current_file(item._file_entry)
            vim.schedule(function()
              local win = item._file_entry:get_win('right')
              if not win or not vim.api.nvim_win_is_valid(win) then
                return
              end
              vim.api.nvim_set_current_win(win)
              local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
              vim.api.nvim_win_set_cursor(win, { math.min(item.lnum, line_count), 0 })
            end)
          end,
        })
      end

      local unfetched = {}
      for _, file in ipairs(files) do
        if not file:is_ready_to_render() then
          unfetched[#unfetched + 1] = file
        end
      end

      if #unfetched == 0 then
        build_items()
        return
      end

      vim.notify(string.format('Fetching %d PR files...', #unfetched), vim.log.levels.INFO)
      for _, file in ipairs(unfetched) do
        file:fetch(false)
      end

      local attempts = 0
      local timer = vim.uv.new_timer()
      timer:start(200, 200, vim.schedule_wrap(function()
        attempts = attempts + 1
        local all_ready = true
        for _, file in ipairs(files) do
          if not file:is_ready_to_render() then
            all_ready = false
            break
          end
        end

        if all_ready or attempts > 150 then
          timer:stop()
          timer:close()
          if all_ready then
            build_items()
          else
            vim.notify('Timed out fetching PR files', vim.log.levels.ERROR)
          end
        end
      end))
    end

    local panel_timers = {}

    local attach_file_panel_auto_open = function(bufnr)
      if vim.b[bufnr]._octo_panel_autoselect_attached then
        return
      end
      vim.b[bufnr]._octo_panel_autoselect_attached = true

      vim.api.nvim_create_autocmd('CursorMoved', {
        buffer = bufnr,
        callback = function()
          local timer = panel_timers[bufnr]
          if timer then
            timer:stop()
            timer:close()
          end

          local new_timer = vim.uv.new_timer()
          panel_timers[bufnr] = new_timer
          new_timer:start(150, 0, vim.schedule_wrap(function()
            local reviews = require('octo.reviews')
            local layout = reviews.get_current_layout()
            if not layout or not layout.file_panel or not layout.file_panel:is_open() then
              return
            end
            if layout.file_panel.bufid ~= bufnr then
              return
            end

            local file = layout.file_panel:get_file_at_cursor()
            if not file then
              return
            end

            if layout.files[layout.selected_file_idx] == file then
              return
            end

            layout:set_current_file(file)
          end))
        end,
      })

      vim.api.nvim_create_autocmd('BufWipeout', {
        buffer = bufnr,
        callback = function()
          local timer = panel_timers[bufnr]
          if timer then
            timer:stop()
            timer:close()
            panel_timers[bufnr] = nil
          end
        end,
      })
    end

    vim.api.nvim_create_autocmd('BufEnter', {
      callback = function(args)
        local reviews = require('octo.reviews')
        local layout = reviews.get_current_layout()
        if not layout or not layout.file_panel then
          return
        end
        if not layout.file_panel.bufid or layout.file_panel.bufid ~= args.buf then
          return
        end
        attach_file_panel_auto_open(args.buf)
      end,
    })

    vim.keymap.set('n', '<leader>or', '<cmd>Octo review start<cr>', { desc = 'Octo review start' })
    vim.keymap.set('n', '<leader>oR', '<cmd>Octo review resume<cr>', { desc = 'Octo review resume' })
    vim.keymap.set('n', '<leader>os', '<cmd>Octo review submit<cr>', { desc = 'Octo review submit' })
    vim.keymap.set('n', '<leader>od', '<cmd>Octo review discard<cr>', { desc = 'Octo review discard' })
    vim.keymap.set('n', '<leader>op', toggle_file_difft_float, { desc = 'Octo difftastic peek (current file)' })
    vim.keymap.set('n', '<leader>ob', function()
      local ok_nav, nav = pcall(require, 'octo.navigation')
      local ok_utils, utils = pcall(require, 'octo.utils')
      if not ok_nav or not ok_utils then
        vim.notify('Octo not available in this buffer', vim.log.levels.WARN)
        return
      end

      local buffer = utils.get_current_buffer()
      if buffer and buffer.isPullRequest and buffer:isPullRequest() then
        nav.open_in_browser()
        return
      end

      local repo = vim.env.OCTO_REPO
      local pr = tonumber(vim.env.OCTO_PR or '')
      if repo and repo ~= '' and pr then
        nav.open_in_browser('pull_request', repo, pr)
        return
      end

      nav.open_in_browser()
    end, { desc = 'Octo open in browser' })
    vim.keymap.set('n', '<leader>sf', function()
      if in_octo_review() then
        open_pr_files_picker()
        return
      end
      snacks.picker.smart()
    end, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>sg', function()
      if in_octo_review() then
        open_pr_grep_picker()
        return
      end
      snacks.picker.grep({ args = { '--fixed-strings' } })
    end, { desc = '[S]earch by [G]rep' })
  end,
}
