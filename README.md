<h1 align="center">🗒️mdv-previewer.yazi</h1>
<p align="center">
  <b>Fast, themeable Markdown viewer for the terminal</b><br>
  <i>View Markdown without leaving yazi</i>
</p>

> [!TIP]
> **Russian version:** [README-RU.md](README-RU.md)

> [!IMPORTANT]
> Requires Yazi v25.5.28+\
> Requires [`mdv`](https://github.com/WhoSowSee/mdv) in `PATH`

https://github.com/user-attachments/assets/f216e8d0-bde5-42a6-979e-f5620f779a47

## Installation

```sh
ya pkg add WhoSowSee/mdv-previewer
```

```sh
# Manual installation

# Linux / macOS
git clone https://github.com/WhoSowSee/mdv-previewer.yazi.git ~/.config/yazi/plugins/mdv-previewer.yazi

# Windows
git clone https://github.com/WhoSowSee/mdv-previewer.yazi.git "$env:APPDATA\yazi\config\plugins\mdv-previewer.yazi"
```

## Usage

### Register the previewer

Add the plugin to `yazi.toml` (adjust the masks if necessary):

```toml
[[plugin.prepend_previewers]]
url = "*.{md,markdown,txt}"
run = "mdv-previewer"

[[plugin.prepend_preloaders]]
url = "*.{md,markdown,txt}"
run = "mdv-previewer"
```

### Configure options (optional)

Example block in `init.lua`:

```lua
require("mdv-previewer"):setup({
  theme = "kanagawa",
  code_theme = "tokyonight",

  -- It is not recommended to use this parameter
  -- If not specified, uses the default safe arguments
  -- Cannot use --monitor and --config-file
  -- The priority of custom_args is higher than theme and code_theme
  custom_args = {
    "--cols", "64",
    "--custom-theme", "h1=173,22,124",
  },

  -- Number of lines per scroll step. Can take "auto" to use the default value
  scroll_step = 3,
})
```
