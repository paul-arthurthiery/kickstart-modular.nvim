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

    local utils = require 'octo.utils'
    utils.merge_state_hl_map['IN_QUEUE'] = 'OctoStatePending'
    utils.merge_state_message_map['IN_QUEUE'] = '⟳ IN-QUEUE'
    utils.mergeable_hl_map['UNKNOWN'] = 'OctoStatePending'
    utils.mergeable_message_map['UNKNOWN'] = ' UNKNOWN'
    utils.state_map['ACTION_REQUIRED'] = { symbol = '! ', hl = 'OctoStateDismissed' }

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

    -- Monkey-patch Review:add_comment to hide any existing thread buffer before
    -- creating a new comment stub. Without this, if the visual selection starts
    -- or ends on a line that already has a thread, show_review_threads() renders
    -- the existing buffer, and create_thread_buffer() then finds a buffer with
    -- the same name (same line) and returns the old one instead of a fresh stub.
    --
    -- The real collision happens inside add_comment itself: it calls
    -- show_review_threads() (which loads the existing thread buffer), then
    -- immediately calls create_thread_buffer() with the stub. The stub generates
    -- the same bufname as the existing thread (same path+line), so the cache
    -- check returns the old buffer. We fix this by patching create_thread_buffer
    -- to force-delete the cached buffer when the threads list contains a stub
    -- (id == -1), so a fresh buffer is always created for new comments.
    local thread_panel = require 'octo.reviews.thread-panel'
    local _orig_create_thread_buffer = thread_panel.create_thread_buffer
    thread_panel.create_thread_buffer = function(threads, repo, number, side, path)
      -- If this is a new-comment stub (id == -1), evict any cached buffer that
      -- shares the same generated name so we never reuse an existing thread.
      if threads and threads[1] and threads[1].id == -1 then
        if not vim.startswith(path, '/') then
          path = '/' .. path
        end
        local line = threads[1].originalStartLine ~= vim.NIL and threads[1].originalStartLine or threads[1].originalLine
        local current_review = require('octo.reviews').get_current_review()
        if current_review then
          local bufname = string.format('octo://%s/review/%s/threads/%s%s:%d', repo, current_review.id, side, path, line)
          local existing = vim.fn.bufnr(bufname)
          if existing ~= -1 then
            vim.api.nvim_buf_delete(existing, { force = true })
          end
        end
      end
      return _orig_create_thread_buffer(threads, repo, number, side, path)
    end

    -- Monkey-patch FilePanel:render to show "old/path → new/path" for renamed
    -- files instead of just the new path. octo already tracks file.previous_path
    -- for status == "R" entries (from GitHub's previous_filename), it just never
    -- renders it. We reproduce the full render function and append the old path
    -- right after the path is written, since everything after that point in the
    -- line (thread-count bubbles) recomputes its offset from #s fresh, so this
    -- is safe to insert without breaking alignment.
    do
      local file_panel_mod = require 'octo.reviews.file-panel'
      local FilePanel = file_panel_mod.FilePanel
      local renderer = require 'octo.reviews.renderer'
      local octo_utils = require 'octo.utils'
      local octo_config = require 'octo.config'

      FilePanel.render = function(self)
        local current_review = require('octo.reviews').get_current_review()
        if not current_review then
          return
        end

        if not self.render_data then
          return
        end

        self.render_data:clear()
        local line_idx = 0
        local lines = self.render_data.lines
        local function add_hl(...)
          self.render_data:add_hl(...)
        end

        local conf = octo_config.values
        local strlen = vim.fn.strlen
        local s = 'Files changed'
        add_hl('OctoFilePanelTitle', line_idx, 0, #s)
        local change_count = string.format('%s%d%s', conf.left_bubble_delimiter, #self.files, conf.right_bubble_delimiter)
        add_hl('OctoBubbleDelimiterYellow', line_idx, strlen(s) + 1, strlen(s) + 1 + strlen(conf.left_bubble_delimiter))
        add_hl(
          'OctoBubbleYellow',
          line_idx,
          strlen(s) + 1 + strlen(conf.left_bubble_delimiter),
          strlen(s) + 1 + strlen(change_count) - strlen(conf.right_bubble_delimiter)
        )
        add_hl(
          'OctoBubbleDelimiterYellow',
          line_idx,
          strlen(s) + 1 + strlen(change_count) - strlen(conf.right_bubble_delimiter),
          strlen(s) + 1 + strlen(change_count)
        )
        s = s .. ' ' .. change_count
        table.insert(lines, s)
        line_idx = line_idx + 1

        local max_changes_length = 0
        local max_path_length = 0
        for _, file in ipairs(self.files) do
          local diffstat = octo_utils.diffstat(file.stats)
          max_changes_length = math.max(max_changes_length, string.len(diffstat.total))
          max_path_length = math.max(max_path_length, string.len(file.path))
        end

        for _, file in ipairs(self.files) do
          local offset = 0
          s = ''

          if file.stats then
            local diffstat = octo_utils.diffstat(file.stats)
            local file_changes_length = string.len(diffstat.total)
            s = string.rep(' ', max_changes_length - file_changes_length) .. diffstat.total .. ' '
            offset = #s
            if diffstat.additions > 0 then
              s = s .. string.rep('■', diffstat.additions)
              add_hl('OctoDiffstatAdditions', line_idx, offset, offset + (3 * diffstat.additions))
              offset = offset + (3 * diffstat.additions)
            end
            if diffstat.deletions > 0 then
              s = s .. string.rep('■', diffstat.deletions)
              add_hl('OctoDiffstatDeletions', line_idx, offset, offset + (3 * diffstat.deletions))
              offset = offset + (3 * diffstat.deletions)
            end
            if diffstat.neutral > 0 then
              s = s .. string.rep('■', diffstat.neutral)
              add_hl('OctoDiffstatNeutral', line_idx, offset, offset + (3 * diffstat.neutral))
              offset = offset + (3 * diffstat.neutral)
            end
          end

          add_hl(renderer.get_git_hl(file.status), line_idx, offset + 1, offset + 2)
          s = s .. ' ' .. file.status
          offset = #s

          if not file.viewed_state then
            file.viewed_state = 'UNVIEWED'
          end
          local viewerViewedStateIcon = octo_utils.viewed_state_map[file.viewed_state].icon
          local viewerViewedStateHl = octo_utils.viewed_state_map[file.viewed_state].hl
          s = s .. ' ' .. viewerViewedStateIcon
          add_hl(viewerViewedStateHl, line_idx, offset + 1, offset + 4)
          offset = #s

          local icon = renderer.get_file_icon(file.basename, file.extension, self.render_data, line_idx, offset)
          offset = offset + #icon

          -- file path
          add_hl('OctoFilePanelFileName', line_idx, offset, offset + #file.path)
          s = s .. icon .. file.path

          -- >>> our addition: show old path for renames <
          if file.status == 'R' and file.previous_path then
            local rename_suffix = '  ⟵ ' .. file.previous_path
            add_hl('OctoDim', line_idx, #s, #s + #rename_suffix)
            s = s .. rename_suffix
          end
          -- >>> end addition <

          local active, resolved, outdated, pending = file_panel_mod.thread_counts(file.path)
          if active > 0 or resolved > 0 or pending > 0 or outdated > 0 then
            offset = #s + 1
            s = s .. string.rep(' ', max_path_length + 1 - string.len(file.path))
          end
          local segments = {
            { count = active, prefix = 'active: ', center_hl = 'OctoBubbleBlue', delimiter_hl = 'OctoBubbleDelimiterBlue' },
            { count = pending, prefix = 'pending: ', center_hl = 'OctoBubbleYellow', delimiter_hl = 'OctoBubbleDelimiterYellow' },
            { count = resolved, prefix = 'resolved: ', center_hl = 'OctoBubbleGreen', delimiter_hl = 'OctoBubbleDelimiterGreen' },
            { count = outdated, prefix = 'outdated: ', center_hl = 'OctoBubbleRed', delimiter_hl = 'OctoBubbleDelimiterRed' },
          }
          for _, segment in ipairs(segments) do
            if segment.count > 0 then
              offset = #s + 1
              local str = string.format('%s%s%d%s', segment.prefix, conf.left_bubble_delimiter, segment.count, conf.right_bubble_delimiter)
              add_hl('OctoMissingDetails', line_idx, offset, offset + string.len(segment.prefix))
              add_hl(segment.delimiter_hl, line_idx, offset + strlen(segment.prefix), offset + strlen(segment.prefix) + strlen(conf.left_bubble_delimiter))
              add_hl(
                segment.center_hl,
                line_idx,
                offset + strlen(segment.prefix) + strlen(conf.left_bubble_delimiter),
                offset + strlen(str) - strlen(conf.right_bubble_delimiter)
              )
              add_hl(segment.delimiter_hl, line_idx, offset + strlen(str) - strlen(conf.right_bubble_delimiter), offset + strlen(str))
              s = s .. ' ' .. str
            end
          end

          table.insert(lines, s)
          line_idx = line_idx + 1
        end

        local right = current_review.layout.right
        local left = current_review.layout.left
        local extra_info = { left:abbrev() .. '..' .. right:abbrev() }
        table.insert(lines, '')
        line_idx = line_idx + 1

        s = 'Showing changes for:'
        add_hl('DiffviewFilePanelTitle', line_idx, 0, #s)
        table.insert(lines, s)
        line_idx = line_idx + 1

        for _, arg in ipairs(extra_info) do
          s = arg
          add_hl('DiffviewFilePanelPath', line_idx, 0, #s)
          table.insert(lines, s)
          line_idx = line_idx + 1
        end
      end
    end

    local snacks = require 'snacks'

    if vim.g.octo_review_mode then
      vim.api.nvim_set_hl(0, 'DiffAdd', { bg = '#1a3a2a' })
      vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#3a1a1a' })
      vim.api.nvim_set_hl(0, 'DiffChange', { bg = 'NONE' })
      vim.api.nvim_set_hl(0, 'DiffText', { bg = '#2a4a3a' })
      vim.api.nvim_set_hl(0, 'OctoDim', { fg = '#6c7086', italic = true })
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
      local octo_utils = require 'octo.utils'

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
      local result = vim.fn.system {
        'gh',
        'pr',
        'view',
        pr,
        '--repo',
        repo,
        '--json',
        'baseRefOid,headRefOid',
        '--jq',
        '.baseRefOid + "\t" + .headRefOid',
      }

      if vim.v.shell_error ~= 0 or not result or result == '' then
        return nil, 'Could not fetch PR base/head SHAs'
      end

      result = vim.trim(result)
      local base_sha, head_sha = result:match '^([^\t]+)\t(.+)$'
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
        ctx.repo,
        ctx.path,
        ctx.base_sha,
        ctx.repo,
        ctx.path,
        ctx.head_sha
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
      local url = line:match 'src%s*=%s*"(https?://[^"]+)"'
      if url then
        return url
      end

      url = line:match "src%s*=%s*'(https?://[^']+)'"
      if url then
        return url
      end

      url = line:match '!%b[]%((https?://[^)%s]+)'
      if url then
        return url
      end

      url = line:match '(https?://%S+)'
      if not url then
        return nil
      end

      return (url:gsub('[)>"\']+$', ''))
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
      local reviews = require 'octo.reviews'
      local layout = reviews.get_current_layout()
      if not layout then
        return
      end

      local picker_preview = require 'snacks.picker.preview'

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
          ft = vim.filetype.match { filename = file.path } or '',
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

      snacks.picker {
        title = 'PR Changed Files',
        items = items,
        preview = file_preview,
        confirm = function(picker, item)
          picker:close()
          if item and item._file_entry then
            layout:set_current_file(item._file_entry)
          end
        end,
      }
    end

    local open_pr_grep_picker = function()
      local reviews = require 'octo.reviews'
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
                  ft = vim.filetype.match { filename = file.path } or '',
                  loc = true,
                },
              }
            end
          end
        end

        snacks.picker {
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
              local win = item._file_entry:get_win 'right'
              if not win or not vim.api.nvim_win_is_valid(win) then
                return
              end
              vim.api.nvim_set_current_win(win)
              local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
              vim.api.nvim_win_set_cursor(win, { math.min(item.lnum, line_count), 0 })
            end)
          end,
        }
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
      timer:start(
        200,
        200,
        vim.schedule_wrap(function()
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
        end)
      )
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
          new_timer:start(
            150,
            0,
            vim.schedule_wrap(function()
              local reviews = require 'octo.reviews'
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
            end)
          )
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
        local ufo = require 'ufo'
        ufo.detach(args.buf)
        ufo.attach(args.buf)

        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(args.buf) then
            return
          end
          vim.keymap.set('n', '<C-r>', function()
            local bufnr = vim.api.nvim_get_current_buf()
            local done = false
            local notif_id = 'octo_refresh_' .. bufnr
            local frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
            local frame = 0
            local spinner_timer = vim.uv.new_timer()
            local timeout_timer = vim.uv.new_timer()

            local function finish(success)
              if done then
                return
              end
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
            spinner_timer:start(
              80,
              80,
              vim.schedule_wrap(function()
                frame = (frame + 1) % #frames
                vim.notify('Refreshing PR…', vim.log.levels.INFO, { id = notif_id, timeout = false, icon = frames[frame + 1] })
              end)
            )

            vim.api.nvim_create_autocmd('TextChanged', {
              buffer = bufnr,
              once = true,
              callback = function()
                finish(true)
              end,
            })

            timeout_timer:start(
              30000,
              0,
              vim.schedule_wrap(function()
                finish(false)
              end)
            )

            require('octo.commands').reload()
          end, { buffer = args.buf, desc = 'Refresh PR with spinner' })
        end)
      end,
    })

    vim.api.nvim_create_autocmd('BufEnter', {
      callback = function(args)
        local reviews = require 'octo.reviews'
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
    vim.keymap.set('n', '<leader>oy', function()
      -- In a diff buffer, get_current_buffer() returns nil because diff buffers
      -- are not registered in octo_buffers. Fall back to the current review's PR URL.
      local buf = utils.get_current_buffer()
      if buf then
        vim.cmd 'Octo comment url'
        return
      end
      local review = require('octo.reviews').get_current_review()
      if review then
        utils.copy_url(review.pull_request.url)
        return
      end
      utils.copy_url(utils.get_remote_url())
    end, { desc = 'Octo copy comment/PR URL to clipboard' })
    vim.keymap.set('n', '<leader>oY', function()
      -- In a diff buffer, get_current_buffer() returns nil because diff buffers
      -- are not registered in octo_buffers. Fall back to the current review's PR URL.
      local buf = utils.get_current_buffer()
      if buf then
        utils.copy_url(buf.node.url)
        return
      end
      local review = require('octo.reviews').get_current_review()
      if review then
        utils.copy_url(review.pull_request.url)
        return
      end
      utils.copy_url(utils.get_remote_url())
    end, { desc = 'Octo copy PR URL to clipboard' })
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
      snacks.picker.grep { args = { '--fixed-strings' } }
    end, { desc = '[S]earch by [G]rep' })
  end,
}
