# Indentify

A neovim plugin for fast indent range calculation and indent guides rendering using `nvim_set_decoration_provider`, providing highlights for scopes.

It doesn't rely on tree-sitter or LSP.

<img width="1847" height="1497" alt="20260713-21h29m01sniri" src="https://github.com/user-attachments/assets/f715bb8c-e2ba-47de-af95-1986fd46c563" />

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
