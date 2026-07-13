# Indentify

A neovim plugin for fast indent range calculation and indent guides rendering using `nvim_set_decoration_provider`, providing highlights for scopes.

It doesn't rely on tree-sitter or LSP.

## Install

```lua
vim.pack.add { 'https://github.com/d-itu/indentify' }
```

## Configure

```lua
require "indentify".setup {
    char = "▏",
    -- return false to prevent rendering for a buffer
    filter = function(win, buf) end,
}
```

## Highlights


| Name |
| - |
| IndentifyInactive |
| IndentifyActive |
