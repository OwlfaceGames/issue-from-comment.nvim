-- lua/issue_from_comment/init.lua
local M = {}

-- Configuration variables
M.config = {
        github_token = os.getenv("GITHUB_TOKEN"),
        create_key = '<Leader>gc',
        cancel_key = 'q',
}

-- Path to persist last used values
local data_path = vim.fn.stdpath("data") .. "/issue_from_comment.json"

-- Load last used values from disk
local function load_last_used()
        local f = io.open(data_path, "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        local ok, data = pcall(vim.fn.json_decode, content)
        if ok and data then return data end
        return nil
end

-- Save last used values to disk
local function save_last_used(owner, repo_name, labels, assignees)
        local data = vim.fn.json_encode({
                owner = owner,
                repo = repo_name,
                labels = labels,
                assignees = assignees,
        })
        local f = io.open(data_path, "w")
        if not f then
                vim.notify("Failed to save last used issue settings", vim.log.levels.WARN)
                return
        end
        f:write(data)
        f:close()
end

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

        local last = load_last_used()

        local default_owner = (last and last.owner) or ""
        local default_repo = (last and last.repo) or ""

        local default_labels = ""
        if last and last.labels and #last.labels > 0 then
                default_labels = table.concat(last.labels, ", ")
        end

        local default_assignees = ""
        if last and last.assignees and #last.assignees > 0 then
                default_assignees = table.concat(last.assignees, ", ")
        end

        local create_key = M.config.create_key or '<Leader>gc'
        local cancel_key = M.config.cancel_key or 'q'

        local lines = {
                "GitHub Issue Creation",
                "_____________________",
                "",
                "",
                "Repo Owner",
                "__________",
                default_owner,
                "",
                "",
                "Repo",
                "____",
                default_repo,
                "",
                "",
                "Title",
                "_____",
                title or "",
                "",
                "",
                "Description",
                "___________",
                "",
                "",
                "Labels (comma-separated)",
                "________________________",
                default_labels,
                "",
                "",
                "Assignees (comma-separated)",
                "___________________________",
                default_assignees,
                "",
                "",
                string.format("Press %s to create the issue or %s to cancel", create_key, cancel_key)
        }

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

        vim.api.nvim_buf_set_keymap(bufnr, 'n', create_key,
        string.format(":lua require('issue_from_comment').submit_issue(%d)<CR>", bufnr),
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

        -- Put cursor on repo owner field
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
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
                                vim.notify("GitHub owner or repo is not set.", vim.log.levels.ERROR)
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
                                                        save_last_used(owner, repo_name, labels, assignees)
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
        local owner = ""
        local repo_name = ""

        local current_section = nil

        for _, line in ipairs(lines) do
                if line:match("^Repo Owner") then
                        current_section = "repo_owner"
                elseif line:match("^Repo") then
                        current_section = "repo"
                elseif line:match("^Title") then
                        current_section = "title"
                elseif line:match("^Description") then
                        current_section = "description"
                elseif line:match("^Labels") then
                        current_section = "labels"
                elseif line:match("^Assignees") then
                        current_section = "assignees"
                elseif line:match("^─+") or line:match("^═+") or line:match("^Press") or line:match("^GitHub Issue Creation") then
                        -- skip UI lines
                elseif current_section == "repo_owner" and line ~= "" then
                        owner = line
                elseif current_section == "repo" and line ~= "" then
                        repo_name = line
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

        if not owner or owner == "" or not repo_name or repo_name == "" then
                vim.notify("Repo owner and repo name must be set", vim.log.levels.ERROR)
                return
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
