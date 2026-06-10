local M = {}

function M.open_from_env()
  local repo = vim.env.OCTO_REPO
  local pr = vim.env.OCTO_PR

  if not repo or repo == '' or not pr or pr == '' then
    vim.notify('Missing OCTO_REPO/OCTO_PR env vars', vim.log.levels.ERROR)
    return
  end

  -- Wait for VimEnter if called too early
  if vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        vim.schedule(function()
          M.open_from_env()
        end)
      end,
    })
    return
  end

  -- Directly edit the octo:// URI
  local octo_uri = string.format('octo://%s/pull/%s', repo, pr)
  vim.cmd.edit(octo_uri)
end

return M
