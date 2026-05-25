-- Highlight branch ref annotations added by git-rebase-editor
vim.fn.matchadd("DiagnosticHint", [[\s# \[.*\]$]])
-- Dim the "onto" context line
vim.fn.matchadd("Comment", [[^# onto:.*]])
