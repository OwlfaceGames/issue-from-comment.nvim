-- lua/issue_from_comment/init.lua
local M = {}

-- Configuration variables
M.config = {
        github_token = os.getenv("GITHUB_TOKEN"),
        github_owner = nil,
        github_repo = nil,
        default_labels = {},
        default_assignees = {},
        create_key = '<Leader>gc',
        cancel_key = 'q',
}

-- Set up the plugin with user config
function M.setup(opts)
        M.config = vim.tbl_deep_extend("force", M.config, opts or {})

        vim.api.nvim_create_user_command("GHIssueFromComment", function()
                M.create_issue_from_comment()
        end, {})
end

-- Main function
function M.create_issue_from_comment()
        local line = vim.api.nvim_get_current_line()

        local comment_text = nil

        comment_text = line:match("^%s*//+%s*(.+)$")
        if not comment_text then
                comment_text = line:match("^%s*#+%s*(.+)$")
        end
        if not comment_text then
                comment_text = line:match("^%s*%-%-+%s*(.+)$")
        end

        if not comment_text then
                vim.notify("No comment found on the current line", vim.log.levels.ERROR)
                return
        end

        local post_colon = comment_text:match(":(.+)$")
        if post_colon then
                comment_text = post_colon
        end

        comment_text = vim.trim(comment_text)

        vim.notify("Extracted title: " .. comment_text, vim.log.levels.INFO)

        M.open_issue_buffer(comment_text, line)
end

-- Open a new buffer for editing issue details
function M.open_issue_buffer(title, original_line)
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(bufnr, "GitHub Issue")

        local default_labels = ""
        if M.config.default_labels and #M.config.default_labels > 0 then
                default_labels = table.concat(M.config.default_labels, ", ")
        end

        local default_assignees = ""
        if M.config.default_assignees and #M.config.default_assignees > 0 then
                default_assignees = table.concat(M.config.default_assignees, ", ")
        end

        local create_key = M.config.create_key or '<Leader>gc'
        local cancel_key = M.config.cancel_key or 'q'

        local lines = {
                "GitHub Issue Creation:",
                "",
                "Repo (leave blank to use default):",
                "",
                "Title:",
                title or "",
                "",
                "Description:",
                "",
                "Labels (comma-separated):",
                default_labels or "",
                "",
                "Assignees (comma-separated):",
                default_assignees or "",
                "",
                string.format("Press %s to create the issue or %s to cancel", create_key, cancel_key)
        }

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

        vim.api.nvim_buf_set_keymap(bufnr, 'n', create_key,
        string.format(":lua require('issue_from_comment').submit_issue(%d, %d)<CR>",
        bufnr, vim.api.nvim_get_current_buf()),
        { noremap = true, silent = true })

        vim.api.nvim_buf_set_keymap(bufnr, 'n', cancel_key,
        string.format(":lua vim.api.nvim_buf_delete(%d, {force = true})<CR>", bufnr),
        { noremap = true, silent = true })

        vim.api.nvim_buf_set_var(bufnr, "original_line", original_line)
        vim.api.nvim_buf_set_var(bufnr, "original_bufnr", vim.api.nvim_get_current_buf())
        vim.api.nvim_buf_set_var(bufnr, "original_line_nr", vim.api.nvim_win_get_cursor(0)[1] - 1)

        vim.cmd("vsplit")
        vim.api.nvim_win_set_buf(0, bufnr)

        vim.bo[bufnr].filetype = "markdown"
        vim.bo[bufnr].buftype = "nofile"
        vim.bo[bufnr].swapfile = false

        -- Put cursor in repo section
        vim.api.nvim_win_set_cursor(0, { 4, 0 })
end

-- Create GitHub issue via API
function M.create_github_issue(title, description, labels, assignees, issue_bufnr, owner, repo_name)
        vim.fn.jobstart("which curl", {
                on_exit = function(_, code)
                        if code ~= 0 then
                                vim.notify("curl is not available. Please install curl.", vim.log.levels.ERROR)
                                return
                        end

                        if not M.config.github_token or M.config.github_token == "" then
                                vim.notify("GitHub token is not set. Please set it via GITHUB_TOKEN environment variable or in your config.",
                                vim.log.levels.ERROR)
                                return
                        end

                        if not owner or not repo_name then
                                vim.notify("GitHub owner or repo is not set. Please configure them in your setup.", vim.log.levels.ERROR)
                                return
                        end

                        local payload = vim.fn.json_encode({
                                title = title,
                                body = vim.trim(description),
                                labels = labels,
                                assignees = assignees
                        })

                        local url = string.format("https://api.github.com/repos/%s/%s/issues", owner, repo_name)

                        vim.notify(string.format("Creating issue in %s/%s...", owner, repo_name))

                        local cmd = string.format(
                                'curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d \'%s\' %s',
                                payload:gsub("'", "'\\''"),
                                url
                        )

                        vim.fn.jobstart(cmd, {
                                env = { GITHUB_TOKEN = M.config.github_token },
                                on_stdout = function(_, data)
                                        if data and #data > 1 then
                                                local response = table.concat(data, "\n")
                                                local success, json = pcall(vim.fn.json_decode, response)

                                                if success and json.number then
                                                        M.update_original_comment(issue_bufnr, json.number)
                                                        vim.notify(string.format("Issue #%d created successfully!", json.number), vim.log.levels.INFO)
                                                        vim.api.nvim_buf_delete(issue_bufnr, { force = true })
                                                else
                                                        vim.notify("Failed to parse GitHub response: " .. response, vim.log.levels.ERROR)
                                                end
                                        end
                                end,
                                on_stderr = function(_, data)
                                        if data and #data > 1 then
                                                vim.notify("GitHub API error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
                                        end
                                end,
                                on_exit = function(_, code)
                                        if code ~= 0 then
                                                vim.notify("Failed to create GitHub issue. Exit code: " .. code, vim.log.levels.ERROR)
                                        end
                                end
                        })
                end
        })
end

-- Submit the issue to GitHub
function M.submit_issue(issue_bufnr)
        local lines = vim.api.nvim_buf_get_lines(issue_bufnr, 0, -1, false)

        local title = ""
        local description = ""
        local labels = {}
        local assignees = {}
        local repo = ""

        local current_section = nil

        for _, line in ipairs(lines) do
                if line:match("^Repo") then
                        current_section = "repo"
                elseif line:match("^Title") then
                        current_section = "title"
                elseif line:match("^Description") then
                        current_section = "description"
                elseif line:match("^Labels") then
                        current_section = "labels"
                elseif line:match("^Assignees") then
                        current_section = "assignees"
                elseif line:match("^Press") or line:match("^GitHub Issue Creation") then
                        -- skip UI lines
                elseif current_section == "repo" and line ~= "" then
                        repo = line
                elseif current_section == "title" and line ~= "" then
                        title = line
                elseif current_section == "description" and line ~= "" then
                        description = description .. line .. "\n"
                elseif current_section == "labels" and line ~= "" then
                        for label in line:gmatch("([^,]+)") do
                                local trimmed = vim.trim(label)
                                if trimmed ~= "" then
                                        table.insert(labels, trimmed)
                                end
                        end
                elseif current_section == "assignees" and line ~= "" then
                        for assignee in line:gmatch("([^,]+)") do
                                local trimmed = vim.trim(assignee)
                                if trimmed ~= "" then
                                        table.insert(assignees, trimmed)
                                end
                        end
                end
        end

        if title == "" then
                vim.notify("Issue title cannot be empty", vim.log.levels.ERROR)
                return
        end

        local owner, repo_name
        if repo ~= "" then
                owner, repo_name = repo:match("^([^/]+)/(.+)$")
                if not owner or not repo_name then
                        vim.notify("Repo must be in owner/repo format", vim.log.levels.ERROR)
                        return
                end
        else
                owner = M.config.github_owner
                repo_name = M.config.github_repo
        end

        M.create_github_issue(title, description, labels, assignees, issue_bufnr, owner, repo_name)
end

-- Update the original comment with the issue number
function M.update_original_comment(issue_bufnr, issue_number)
        local original_bufnr = vim.api.nvim_buf_get_var(issue_bufnr, "original_bufnr")
        local line_nr = vim.api.nvim_buf_get_var(issue_bufnr, "original_line_nr")
        local line = vim.api.nvim_buf_get_lines(original_bufnr, line_nr, line_nr + 1, false)[1]

        local updated_line = line .. " #" .. issue_number
        vim.api.nvim_buf_set_lines(original_bufnr, line_nr, line_nr + 1, false, { updated_line })
end

return M
