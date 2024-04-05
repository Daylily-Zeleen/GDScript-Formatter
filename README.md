# GDScript-Formatter

![icon](icon.png)

An addons of Godot Editor(4.x) for formatting GDScript.


## Feature:
1. Install/Update "gdtoolkit": Project-> Tool-> GDScript Formatter: Install/Update gdtoolkit
2. Formatting:
   - By shortcut, default is: Shift+Alt+F
   - By tool menue item: Project-> Tool-> GDScript Formatter: Format script
   - By Command palette: pop up cammand palette (default by Ctrl+Shift+P), and comfire command "Format GDScript".
3. Format on save: default is disabled, turn on it by changing preference (refer below for more detail).
4. Preference:
   You can modify **shortcut** and **formatting preference** by editing resource which are localed at "res://addons/gdscript_formatter/".
   You can change **gdformat** and **pip** command by editing \"res://addons/gdscript_formatter/format_preference.tres\" (if these commands can't be found but are installed).



## Requirements:
1. For formatting: "gdtoolkit"
2. For install/update "gdtoolkit": "pip"

Please ensure these requirements can be found in your environment.
