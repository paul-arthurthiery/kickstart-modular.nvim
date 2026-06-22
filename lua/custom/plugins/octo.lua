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

    local utils = require('octo.utils')
    utils.merge_state_hl_map['IN_QUEUE']      = 'OctoStatePending'
    utils.merge_state_message_map['IN_QUEUE'] = '⟳ IN-QUEUE'
    utils.mergeable_hl_map['UNKNOWN']         = 'OctoStatePending'
    utils.mergeable_message_map['UNKNOWN']    = ' UNKNOWN'
    utils.state_map['ACTION_REQUIRED']        = { symbol = '! ', hl = 'OctoStateDismissed' }

    -- Monkey-patch write_review_thread_header to split into two virtual text
    -- lines so that long file paths don't push the resolved/outdated badges
    -- off-screen. Line 1: path + line range. Line 2: commit + status badges.
    local writers = require 'octo.ui.writers'
    local constants = require 'octo.constants'
    local bubbles = require 'octo.ui.bubbles'
    local octo_config = require 'octo.config'

    writers.write_review_thread_header = function(bufnr, opts, line)
      line = line or vim.api.nvim_buf_line_count(bufnr) - 1
      local conf = octo_config.values

      vim.api.nvim_buf_clear_namespace(bufnr, constants.OCTO_THREAD_HEADER_VT_NS, line, line + 3)

      local indent = string.rep(' ', conf.timeline_indent) .. conf.timeline_marker .. ' '

      -- Line 1: path + line range
      local line1_vt = {
        { indent, 'OctoTimelineMarker' },
        { 'THREAD: ', 'OctoTimelineItemHeading' },
        { '[', 'OctoSymbol' },
        { opts.path .. ' ', 'OctoDetailsLabel' },
        { tostring(opts.start_line) .. ':' .. tostring(opts.end_line), 'OctoDetailsValue' },
        { ']', 'OctoSymbol' },
      }

      -- Line 2: commit + status badges
      local line2_vt = {
        { indent, 'OctoTimelineMarker' },
        { '[Commit: ', 'OctoSymbol' },
        { opts.commit, 'OctoDetailsLabel' },
        { '] ', 'OctoSymbol' },
      }

      if opts.isOutdated then
        vim.list_extend(line2_vt, bubbles.make_bubble('Outdated', 'OctoBubbleYellow', { margin_width = 1 }))
      end

      if opts.isResolved then
        vim.list_extend(line2_vt, bubbles.make_bubble('Resolved', 'OctoBubbleGreen', { margin_width = 1 }))
        if opts.resolvedBy then
          vim.list_extend(line2_vt, {
            { ' [by: ', 'OctoSymbol' },
            { opts.resolvedBy.login, 'OctoDetailsLabel' },
            { ']', 'OctoSymbol' },
          })
        end
      end

      -- Insert two blank anchor lines then overlay both with virtual text
      local write_block = writers.write_block
      write_block(bufnr, { '', '' })
      vim.api.nvim_buf_set_extmark(bufnr, constants.OCTO_THREAD_HEADER_VT_NS, line + 1, 0, {
        virt_text = line1_vt,
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
      })
      vim.api.nvim_buf_set_extmark(bufnr, constants.OCTO_THREAD_HEADER_VT_NS, line + 2, 0, {
        virt_text = line2_vt,
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
      })
    end

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
    end

    local in_octo_review = function()
      local ok, reviews = pcall(require, 'octo.reviews')
      if not ok then
        return false
      end
      return reviews.get_current_layout() ~= nil
    end

    local extract_image_url = function(line)
      local url = line:match('src%s*=%s*"(https?://[^"]+)"')
      if url then
        return url
      end

      url = line:match("src%s*=%s*'(https?://[^']+)'")
      if url then
        return url
      end

      url = line:match('!%b[]%((https?://[^)%s]+)')
      if url then
        return url
      end

      url = line:match('(https?://%S+)')
      if not url then
        return nil
      end

      return (url:gsub("[)>\"']+$", ''))
    end

    local open_image_url_under_cursor = function()
      if vim.bo.filetype ~= 'octo' then
        vim.notify('Image URL opener is only enabled for octo buffers', vim.log.levels.WARN)
        return
      end

      local line = vim.api.nvim_get_current_line()
      local url = extract_image_url(line)
      if not url then
        vim.notify('No image URL found on this line', vim.log.levels.INFO)
        return
      end

      if vim.ui and vim.ui.open then
        vim.ui.open(url)
        return
      end

      vim.fn.jobstart({ 'open', url }, { detach = true })
    end

    local open_pr_files_picker = function()
      local reviews = require('octo.reviews')
      local layout = reviews.get_current_layout()
      if not layout then
        return
      end

      local picker_preview = require('snacks.picker.preview')

      local file_preview = function(ctx)
        local item = ctx.item
        if not item or not item._file_entry then
          return picker_preview.none(ctx)
        end

        local file = item._file_entry
        if not file.right_fetched then
          file:fetch(true)
        end

        local lines = file.right_lines or {}
        local text = table.concat(lines, '\n')
        if text == '' then
          text = '[empty file]'
        end

        item.preview = {
          text = text,
          ft = vim.filetype.match({ filename = file.path }) or '',
          loc = false,
        }
        return picker_preview.preview(ctx)
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
        preview = file_preview,
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
                pos = { lnum, 0 },
                _file_entry = file,
                preview = {
                  text = table.concat(file.right_lines or {}, '\n'),
                  ft = vim.filetype.match({ filename = file.path }) or '',
                  loc = true,
                },
              }
            end
          end
        end

        snacks.picker({
          title = 'PR Grep (head)',
          items = items,
          preview = 'preview',
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
            local panel_win = vim.fn.bufwinid(bufnr)
            if panel_win ~= -1 and vim.api.nvim_win_is_valid(panel_win) then
              vim.api.nvim_set_current_win(panel_win)
            end
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

    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'octo',
      callback = function(args)
        vim.keymap.set('n', '<leader>r', '<Nop>', { buffer = args.buf })
        vim.keymap.set('x', '<leader>r', '<Nop>', { buffer = args.buf })
        local ufo = require('ufo')
        ufo.detach(args.buf)
        ufo.attach(args.buf)

        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(args.buf) then return end
          vim.keymap.set('n', '<C-r>', function()
            local bufnr = vim.api.nvim_get_current_buf()
            local done = false
            local notif_id = 'octo_refresh_' .. bufnr
            local frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
            local frame = 0
            local spinner_timer = vim.uv.new_timer()
            local timeout_timer = vim.uv.new_timer()

            local function finish(success)
              if done then return end
              done = true
              spinner_timer:stop()
              spinner_timer:close()
              timeout_timer:stop()
              timeout_timer:close()
              Snacks.notifier.hide(notif_id)
              if success then
                vim.notify('PR refreshed', vim.log.levels.INFO, { timeout = 2000 })
              else
                vim.notify('PR refresh timed out', vim.log.levels.WARN, { timeout = 3000 })
              end
            end

            vim.notify('Refreshing PR…', vim.log.levels.INFO, { id = notif_id, timeout = false, icon = frames[1] })
            spinner_timer:start(80, 80, vim.schedule_wrap(function()
              frame = (frame + 1) % #frames
              vim.notify('Refreshing PR…', vim.log.levels.INFO, { id = notif_id, timeout = false, icon = frames[frame + 1] })
            end))

            vim.api.nvim_create_autocmd('TextChanged', {
              buffer = bufnr,
              once = true,
              callback = function() finish(true) end,
            })

            timeout_timer:start(30000, 0, vim.schedule_wrap(function()
              finish(false)
            end))

            require('octo.commands').reload()
          end, { buffer = args.buf, desc = 'Refresh PR with spinner' })
        end)
      end,
    })

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

    vim.keymap.set('n', '<leader>oc', '<cmd>Octo pr checks<cr>', { desc = 'Octo PR checks' })
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
    vim.keymap.set('n', '<leader>oi', open_image_url_under_cursor, { desc = 'Octo open image URL' })
    vim.keymap.set('n', '<leader>oy', '<cmd>Octo comment url<cr>', { desc = 'Octo copy comment URL to clipboard' })
    vim.keymap.set('n', '<leader>oY', '<cmd>Octo pr url<cr>', { desc = 'Octo copy PR URL to clipboard' })
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
