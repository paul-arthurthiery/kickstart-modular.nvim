return {
  'pmizio/typescript-tools.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  ft = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
  opts = {
    settings = {
      tsserver_file_preferences = {
        includeCompletionsForModuleExports = true,
      },
      complete_function_calls = true,
    },
  },
}
