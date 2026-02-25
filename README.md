# Issue From Comment

A Neovim plugin that allows you to create GitHub issues directly from comments. Simply position your cursor on a comment line, run the command via a custom keybind or by typing ":GHIssueFromComment", and the plugin will extract the comment text as an issue title, open a buffer to edit details, create the issue, and update the original comment with the issue number.

![](https://github.com/OwlfaceGames/issue-from-comment/blob/master/issue%20from%20comment%20example.gif?raw=true)

## Features

- Create GitHub issues without leaving Neovim
- Extract issue titles from code comments
- Customize title, description, labels, and assignees before creating the issue
- Support for default labels to speed up issue creation
- Automatically add the issue number to your code comment
- Works with multiple comment styles (//, #, --)
- Automatically cleans up TODO/FIXME prefixes
- Only keeps text after colons for clear issue titles
- Custom keybindings for opening the issue buffer, closing the buffer and creating the issue


## Requirements

- Neovim 0.5.0 or higher
- curl (for GitHub API access)
- A GitHub Personal Access Token with the `repo` scope
- Internet connectivity to reach the GitHub API

## Installation

### Using lazy.nvim

```lua
return {
  "OwlfaceGames/issue-from-comment.nvim",
  config = function()
    require("issue_from_comment").setup({
      github_owner = "your-github-username", -- Owner of the target repo
      github_repo = "your-repository-name",  -- Name of the target repo
      default_labels = {"bug", "enhancement"}, -- Optional default labels
      default_assignees = {"your-username", "colleague-username"}, -- Optional default assignees
      create_key = '<Leader>gc', -- Optional custom key to create the issue
      cancel_key = 'q',          -- Optional custom key to cancel
      
      -- Authentication (one of these is required)
      github_token = os.getenv("GITHUB_TOKEN"),  -- GitHub token (default: from env var)
    })
    
    -- Optional keymapping to trigger issue creation
    vim.keymap.set("n", "<Leader>gi", ":GHIssueFromComment<CR>", { noremap = true, silent = true })
  end,
}
```
**IMPORTANT:** Note that this is also where you create your custom keybinds and defaults.
If you don't want to set a default keybind or label etc. just omit it by deleting the line.

Should also be be noted that "github_owner" and "github_repo" refers to the repo where you want to create issues.

Also if you don't have an env var for your gh token you can just write it as a string instead.

### Using packer.nvim

```lua
use {
  'OwlfaceGames/issue-from-comment.nvim',
  config = function()
    require('issue_from_comment').setup({
      github_owner = "your-github-username",
      github_repo = "your-repository-name",
      default_labels = {"bug", "enhancement"},
      default_assignees = {"your-username", "colleague-username"}, -- Optional default assignees
      create_key = '<Leader>gc', -- Optional custom key to create the issue
      cancel_key = 'q',          -- Optional custom key to cancel

      -- Authentication (one of these is required)
      github_token = os.getenv("GITHUB_TOKEN"),  -- GitHub token (default: from env var)
    })
    
    -- Optional keymapping
    vim.keymap.set("n", "<Leader>gi", ":GHIssueFromComment<CR>", { noremap = true, silent = true })
  end
}
```

### Using vim-plug

```vim
" In init.vim or .vimrc
Plug 'OwlfaceGames/issue-from-comment.nvim'

" Then in your config:
lua << EOF
require('issue_from_comment').setup({
  github_owner = "your-github-username",
  github_repo = "your-repository-name",
  default_labels = {"bug", "enhancement"},
  default_assignees = {"your-username", "colleague-username"}, -- Optional default assignees
  create_key = '<Leader>gc', -- Optional custom key to create the issue
  cancel_key = 'q',          -- Optional custom key to cancel

  -- Authentication (one of these is required)
  github_token = os.getenv("GITHUB_TOKEN"),  -- GitHub token (default: from env var)
})

-- Optional keymapping
vim.keymap.set("n", "<Leader>gi", ":GHIssueFromComment<CR>", { noremap = true, silent = true })
EOF
```

### Manual Installation

```bash
# Create the plugin directory
mkdir -p ~/.local/share/nvim/site/pack/plugins/start/issue-from-comment.nvim

# Clone the repository
git clone https://github.com/OwlfaceGames/issue-from-comment.nvim.git \
  ~/.local/share/nvim/site/pack/plugins/start/issue-from-comment.nvim

# Then in your init.lua:
require('issue_from_comment').setup({
  github_owner = "your-github-username",
  github_repo = "your-repository-name",
  -- Additional configuration...
})
```

## Setting Up GitHub Authentication

This plugin requires a GitHub Personal Access Token with the `repo` scope:

1. Go to [GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)](https://github.com/settings/tokens)
2. Click "Generate new token" and select "Generate new token (classic)"
3. Give it a descriptive name like "Neovim issue-from-comment plugin"
4. Select the `repo` scope (or `public_repo` for public repositories only)
5. Click "Generate token" and copy the token

Then, set the token in one of these ways:

### Option 1: Environment Variable (Recommended)

Add this to your shell configuration (`.bashrc`, `.zshrc`, etc.):

```bash
export GITHUB_TOKEN="your-token-here"
```

### Option 2: Direct Configuration

Add the token directly in your Neovim config (less secure):

```lua
require('issue_from_comment').setup({
  github_owner = "your-github-username",
  github_repo = "your-repository-name",
  github_token = "your-token-here",
})
```

## Configuration

All configuration options with their defaults:

```lua
require('issue_from_comment').setup({
  -- Required settings
  github_owner = nil,           -- GitHub username or organization (required)
  github_repo = nil,            -- Repository name (required)
  
  -- Authentication (one of these is required)
  github_token = os.getenv("GITHUB_TOKEN"),  -- GitHub token (default: from env var)
  
  -- Optional settings
  default_labels = {},          -- Default labels for all issues
  default_assignees = {},       -- Default assignees for all issues
  create_key = '<Leader>gc',    -- Key to create issue from buffer
  cancel_key = 'q',             -- Key to cancel and close buffer
})
```

### Configuration Options Explained

| Option | Type | Description | Default |
|--------|------|-------------|---------|
| `github_owner` | string | Owner of the GitHub repository where issues will be created (username or organization) | `nil` (required) |
| `github_repo` | string | Name of the GitHub repository where issues will be created | `nil` (required) |
| `github_token` | string | GitHub Personal Access Token with repo scope | From `GITHUB_TOKEN` env var |
| `default_labels` | table | Array of default labels to apply to new issues | `{}` |
| `default_assignees` | table | Array of default assignees for new issues | `{}` |
| `create_key` | string | Key to press to create the issue from the buffer | `<Leader>gc` |
| `cancel_key` | string | Key to press to cancel and close the buffer | `q` |

### Example Configuration with All Options

```lua
require('issue_from_comment').setup({
  -- Required settings
  github_owner = "octocat",
  github_repo = "Hello-World",
  
  -- Optional settings with non-default values
  default_labels = {"bug", "documentation", "good first issue"},
  default_assignees = {"octocat"},
  create_key = '<Leader>cc',
  cancel_key = '<Esc>',
})

-- Keymapping to trigger issue creation
vim.keymap.set("n", "<Leader>gi", ":GHIssueFromComment<CR>", { noremap = true, silent = true })
```

## Usage

### Basic Workflow

1. Navigate to a line with a comment in your code (e.g., `// TODO: Implement this feature`)
2. Run the `:GHIssueFromComment` command or use your keybinding
3. A split buffer will open with the issue form pre-populated with the comment text
4. Edit the title, add a description, modify labels, or add assignees
5. Press the create key (default: `<Leader>gc`) to create the issue
6. The issue will be created on GitHub and the comment will be updated with the issue number: `// TODO: Implement this feature #42`

### Comment Extraction

The plugin automatically extracts and cleans the comment text:

```
// TODO: Fix alignment bug    →  "Fix alignment bug"
# Add documentation           →  "Add documentation"
-- FIXME: Users can't login   →  "Users can't login"
// Important: Rewrite this    →  "Rewrite this"
```

If a comment contains a colon (`:`), only the text after the colon is used for the title.

### Issue Buffer

The issue creation buffer has four sections:

1. **Title**: The extracted comment text (editable)
2. **Description**: Where you can add details about the issue
3. **Labels**: Comma-separated list of labels (pre-populated with defaults if set)
4. **Assignees**: Comma-separated list of GitHub usernames

Use the create key (default: `<Leader>gc`) to submit the issue or the cancel key (default: `q`) to close the buffer without creating an issue.

## How It Works

1. **Comment Extraction**: The plugin analyzes the current line to find and extract comment text
2. **Buffer Creation**: A new split buffer is created with a form for editing issue details
3. **API Integration**: When you submit, the plugin uses the GitHub API to create the issue
4. **Comment Update**: After successful creation, the original comment is updated with the issue number

## Troubleshooting

### Common Issues

1. **Authentication Errors**:
   - Ensure your GitHub token has the `repo` scope
   - Check that the token is correctly set up (environment variable or config)
   - Verify that the token hasn't expired

2. **Repository Access**:
   - Confirm that you have permission to create issues in the target repository
   - Verify the owner and repo name are correctly specified in your config


### Debugging

If you encounter issues, you can enable more detailed error messages:

```lua
vim.g.issue_from_comment_debug = true
```
## Support
If you like my work, consider supporting me through [GitHub Sponsors](https://github.com/sponsors/OwlfaceGames)🩷


## License

Distributed under the MIT License. See `LICENSE` for more information.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
