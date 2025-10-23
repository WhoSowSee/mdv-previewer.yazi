<h1 align="center">🗒️mdv-previewer.yazi</h1>
<p align="center">
  <b>Быстрый и настраиваемый Markdown-просмотрщик для терминала</b><br>
  <i>Просматривайте Markdown, не выходя из yazi</i>
</p>

> [!TIP]
> **Английская версия:** [README.md](README.md)

> [!IMPORTANT]
> Необходим Yazi v25.5.28+\
> Необходим [`mdv`](https://github.com/WhoSowSee/mdv) в `PATH`

https://github.com/user-attachments/assets/c985d2cb-1bc6-43cb-aef7-0596949d1f29

## Установка

```sh
ya pkg add WhoSowSee/mdv-previewer
```

```sh
# Ручная установка

# Linux / macOS
git clone https://github.com/WhoSowSee/mdv-previewer.yazi.git ~/.config/yazi/plugins/mdv-previewer.yazi

# Windows
git clone https://github.com/WhoSowSee/mdv-previewer.yazi.git "$env:APPDATA\yazi\config\plugins\mdv-previewer.yazi"
```

## Использование

### Регистрация превьюера

Добавьте плагин в `yazi.toml` (при необходимости скорректируйте маски):

```toml
[[plugin.prepend_previewers]]
name = "*.{md,markdown,txt}"
run = "mdv-previewer"

[[plugin.prepend_preloaders]]
name = "*.{md,markdown,txt}"
run = "mdv-previewer"
```

### Настройка (опционально)

Пример блока в `init.lua`:

```lua
require("mdv-previewer"):setup({
  theme = "kanagawa",
  code_theme = "tokyonight",

  -- Если не указано, используются встроенные безопасные параметры.
  -- Невозможно использовать --monitor и --config-file
  -- Приоритет custom_args выше, чем theme и code_theme
  -- Если не указана -c/--cols, то берется ширина превью панели
  custom_args = "--style-code-block simple --wrap char --link-style inline",

  -- Количество строк на один шаг прокрутки. Может принимать "auto", чтобы использовать значение по умолчанию
  scroll_step = 3,
})
```
