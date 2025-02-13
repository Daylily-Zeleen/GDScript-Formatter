![Static Badge](https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine&labelColor=white)

# GDScript Formatter

![icon](icon.png)

点此查看[中文说明](README.zh.md).

A Godot Editor (4.x) addon for formatting GDScript automatically.

## Features

- Format with **shortcut**
  - Defaults to **Shift+Alt+F**
- Format on save
  - Off by default, can be enabled by [editing the preferences in EditorSettings](#editing-preferences)
- Format through **tool menu**
  - **Project -> Tool -> GDScript Formatter: Format script**
- Format through **command palette**
  - Open the command palette (Default **Ctrl+Shift+P**) and run command `Format GDScript`

## Installation

**GDScript Formatter** relies on [**GDToolkit**](https://github.com/Scony/godot-gdscript-toolkit) which uses Python and Pip package manager. You need to install them in order to use the addon.

1. Install Python (if you do not have it already)
   - Download installer from [https://www.python.org/downloads/]
   - Make sure to enable "Add python.exe to PATH" when installing
      - If you forget you can [add python.exe to PATH after installation](https://realpython.com/add-python-to-path/)
   - Pip is included with python
2. Install the Godot plugin
   - In Godot editor, click "AssetLib" and search "GDScript Formatter"
   - Install the plugin
   - Enable the plugin through **Project -> Project Settings -> Plugins**
3. Install GDToolkit
   - **Project -> Tool -> GDScript Formatter: Install/Update gdtoolkit**

    **Note: if your python is not install for all users, you might need to change the command by [editing the preference](# Editing Preferences)**

## Editing Preferences

You can edit GDScript Formatter's behavior through the **Editor -> Editor Settings -> General -> GDScript Formatter**. You can change whether files are formatted on save, the gdformat command, line length, shortcut, and other values.
If you need to change preference for specific project, you can check `GDScript_Formatter/custom_settings_enabled` and modify settings in **Project -> Project Settings -> General -> GDScript Formatter**.

## Others

If this plugin can help you, please consider to [buy me a coffee](https://afdian.com/a/Daylily-Zeleen), I would try my best to release more plugins and maintain old plugins.
