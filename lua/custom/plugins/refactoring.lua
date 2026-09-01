return {
  { 'lewis6991/async.nvim', lazy = true },
  {
    'ThePrimeagen/refactoring.nvim',
    dependencies = { 'lewis6991/async.nvim' },
    config = function()
      -- Both refactoring.nvim (needs async.run/wrap/await) and nvim-ufo (needs
      -- async() callable via __call) do require("async"), but different packages
      -- win the runtimepath race depending on load order.
      -- Build a unified proxy that satisfies both, and permanently install it.
      if not package.loaded['async'] or not package.loaded['async'].run then
        local lewis_async = loadfile(vim.fn.stdpath('data') .. '/lazy/async.nvim/lua/async.lua')()
        local promise_async = package.loaded['async']

        -- Merge lewis_async (run/wrap/await) and promise_async (sync/wait + __call)
        -- into a unified table so both refactoring.nvim and nvim-ufo are satisfied.
        local unified = {}
        if promise_async then
          for k, v in pairs(promise_async) do unified[k] = v end
        end
        for k, v in pairs(lewis_async) do unified[k] = v end
        setmetatable(unified, {
          __index = lewis_async,
          __call = promise_async and getmetatable(promise_async) and getmetatable(promise_async).__call or nil,
        })

        package.loaded['async'] = unified
      end

      require('refactoring').setup({})
    end,
    keys = {
      {
        '<leader>rs',
        function()
          return require('refactoring').select_refactor()
        end,
        mode = { 'n', 'x' },
        desc = 'Select Refactor',
      },
    },
  },
}
