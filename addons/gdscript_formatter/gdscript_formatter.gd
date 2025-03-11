'''
	MIT License

	Copyright (c) 2024-present 忘忧の (Daylily Zeleen) - <daylily-zeleen@foxmail.com>

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
'''

@tool
extends EditorPlugin

## How many characters per line to allow.
## 每行允许的最大字符数量。
const SETTING_LINE_LENGTH = "GDScript_Formatter/line_length"
const DEFAULT_LINE_LENGTH = 175

## If true, will format on save.
## 如果开启，将在脚本保存时进行格式化。
const SETTING_FORMAT_ON_SAVE = "GDScript_Formatter/format_on_save"
const DEFAULT_FORMAT_ON_SAVE = false

## The shortcut for formatting script.
## Default is "Shift+Alt+F"。
## 格式化脚本所使用的快捷键。
## 默认为"Shift+Alt+F"。
const SETTING_SHORTCUT = "GDScript_Formatter/shortcut"

## If true, will skip safety checks.
## 如果开启，则跳过安全检查。
const SETTING_FAST_BUT_UNSAFE = "GDScript_Formatter/fast_but_unsafe"
const DEFAULT_FAST_BUT_UNSAFE = false

## The gdformat command to use on the command line, you might need to modify this option if the "gdformat" is not installed for all users.
## 用于格式化的gdformat命令，如果你的gdformat不是为所有用户安装时可能需要修改该选项。
const SETTING_GDFORMAT_COMMAND = "GDScript_Formatter/gdformat_command"
const DEFAULT_GDFORMAT_COMMAND = "gdformat"

## The pip command to use on the command line, you might need to modify this option if the "python/pip" is not installed for all users.
## 用于安装/更新gdformat而使用的pip命令，如果你的python/pip不是为所有用户安装时可能需要修改该选项。
const SETTING_PIP_COMMAND = "GDScript_Formatter/pip_command"
const DEFAULT_PIP_COMMAND = "pip"

const _SETTING_CUSTOM_SETTINGS_ENABLED = "GDScript_Formatter/custom_settings_enabled"
const _PROJECT_SPECIFIC_SETTINGS = ".preference"

var _has_format_tool_item: bool = false
var _has_install_update_tool_item: bool = false
var _install_task_id: int = -1
var _connection_list: Array[Resource] = []


func _init() -> void:
	var editor_settings := _get_editor_interface().get_editor_settings()
	if not editor_settings.has_setting(SETTING_LINE_LENGTH):
		editor_settings.set_setting(SETTING_LINE_LENGTH, DEFAULT_LINE_LENGTH)
	if not editor_settings.has_setting(SETTING_FORMAT_ON_SAVE):
		editor_settings.set_setting(SETTING_FORMAT_ON_SAVE, DEFAULT_FORMAT_ON_SAVE)
	if not editor_settings.has_setting(SETTING_SHORTCUT):
		editor_settings.set_setting(SETTING_SHORTCUT, _create_default_shortcut())
	if not editor_settings.has_setting(SETTING_FAST_BUT_UNSAFE):
		editor_settings.set_setting(SETTING_FAST_BUT_UNSAFE, DEFAULT_FAST_BUT_UNSAFE)
	if not editor_settings.has_setting(SETTING_GDFORMAT_COMMAND):
		editor_settings.set_setting(SETTING_GDFORMAT_COMMAND, DEFAULT_GDFORMAT_COMMAND)
	if not editor_settings.has_setting(SETTING_PIP_COMMAND):
		editor_settings.set_setting(SETTING_PIP_COMMAND, DEFAULT_PIP_COMMAND)

	# For compatibility, load preference from "format_preference.tres".
	var preference_res_file := (get_script() as Resource).resource_path.get_base_dir().path_join("format_preference.tres")
	if ResourceLoader.exists(preference_res_file):
		var old_preference := ResourceLoader.load(preference_res_file, "", ResourceLoader.CACHE_MODE_IGNORE)
		if "line_length" in old_preference:
			editor_settings.set_setting(SETTING_LINE_LENGTH, old_preference.get("line_length"))
		if "format_on_save" in old_preference:
			editor_settings.set_setting(SETTING_FORMAT_ON_SAVE, old_preference.get("format_on_save"))
		if "shortcut" in old_preference:
			editor_settings.set_setting(SETTING_SHORTCUT, old_preference.get("shortcut"))
		if "fast_but_unsafe" in old_preference:
			editor_settings.set_setting(SETTING_FAST_BUT_UNSAFE, old_preference.get("fast_but_unsafe"))
		if "gdformat_command" in old_preference:
			editor_settings.set_setting(SETTING_GDFORMAT_COMMAND, old_preference.get("gdformat_command"))
		if "pip_command" in old_preference:
			editor_settings.set_setting(SETTING_PIP_COMMAND, old_preference.get("pip_command"))
		old_preference.unreference()

		# Remove old files.
		DirAccess.remove_absolute(preference_res_file)
		var scripts_dir := (get_script() as Resource).resource_path.get_base_dir().path_join("scripts")
		if DirAccess.dir_exists_absolute(scripts_dir):
			var old_preference_script := scripts_dir.path_join("preference.gd")
			if FileAccess.file_exists(old_preference_script):
				DirAccess.remove_absolute(old_preference_script)
			DirAccess.remove_absolute(scripts_dir)


func _enter_tree() -> void:
	_add_format_tool_item_and_command()

	if not _has_command(_get_pip_command()):
		_print_warning('"%s" is required for installing "gdtoolkit".' % _get_pip_command())
		_print_warning("\tPlease install it and ensure it can be found in your environment.")
	else:
		add_tool_menu_item("GDScriptFormatter: Install/Update gdtoolkit", install_or_update_gdtoolkit)
		_has_install_update_tool_item = true

	update_shortcut()

	# Add settings for project specific.
	var settings := _get_project_specific_settings()
	if not ProjectSettings.has_setting(_SETTING_CUSTOM_SETTINGS_ENABLED):
		ProjectSettings.set_setting(_SETTING_CUSTOM_SETTINGS_ENABLED, settings.get(_SETTING_CUSTOM_SETTINGS_ENABLED))
		ProjectSettings.set_initial_value(_SETTING_CUSTOM_SETTINGS_ENABLED, false)

	if not ProjectSettings.has_setting(SETTING_LINE_LENGTH):
		ProjectSettings.set_setting(SETTING_LINE_LENGTH, settings.get(SETTING_LINE_LENGTH))
		ProjectSettings.set_initial_value(SETTING_LINE_LENGTH, DEFAULT_LINE_LENGTH)
	if not ProjectSettings.has_setting(SETTING_FORMAT_ON_SAVE):
		ProjectSettings.set_setting(SETTING_FORMAT_ON_SAVE, settings.get(SETTING_FORMAT_ON_SAVE))
		ProjectSettings.set_initial_value(SETTING_FORMAT_ON_SAVE, DEFAULT_FORMAT_ON_SAVE)
	if not ProjectSettings.has_setting(SETTING_FAST_BUT_UNSAFE):
		ProjectSettings.set_setting(SETTING_FAST_BUT_UNSAFE, settings.get(SETTING_FAST_BUT_UNSAFE))
		ProjectSettings.set_initial_value(SETTING_FAST_BUT_UNSAFE, DEFAULT_FAST_BUT_UNSAFE)

	project_settings_changed.connect(_on_project_settings_changed)
	resource_saved.connect(_on_resource_saved)


func _exit_tree() -> void:
	resource_saved.disconnect(_on_resource_saved)

	_remove_format_tool_item_and_command()
	if _has_install_update_tool_item:
		remove_tool_menu_item("GDScriptFormatter: Install/Update gdtoolkit")

	project_settings_changed.disconnect(_on_project_settings_changed)

	# Remove settings for project specific.
	if ProjectSettings.has_setting(_SETTING_CUSTOM_SETTINGS_ENABLED):
		ProjectSettings.set_setting(_SETTING_CUSTOM_SETTINGS_ENABLED, null)
	if ProjectSettings.has_setting(SETTING_LINE_LENGTH):
		ProjectSettings.set_setting(SETTING_LINE_LENGTH, null)
	if ProjectSettings.has_setting(SETTING_FORMAT_ON_SAVE):
		ProjectSettings.set_setting(SETTING_FORMAT_ON_SAVE, null)
	if ProjectSettings.has_setting(SETTING_FAST_BUT_UNSAFE):
		ProjectSettings.set_setting(SETTING_FAST_BUT_UNSAFE, null)


func _create_default_shortcut() -> Shortcut:
	var default_shortcut := InputEventKey.new()
	default_shortcut.echo = false
	default_shortcut.pressed = true
	default_shortcut.keycode = KEY_F
	default_shortcut.shift_pressed = true
	default_shortcut.alt_pressed = true

	var shortcut := Shortcut.new()
	shortcut.events.push_back(default_shortcut)

	return shortcut


func _shortcut_input(event: InputEvent) -> void:
	if not _has_format_tool_item:
		return
	var shortcut := _get_shortcut()
	if not is_instance_valid(shortcut):
		return
	if shortcut.matches_event(event) and event.is_pressed() and not event.is_echo():
		if format_script():
			get_tree().root.set_input_as_handled()


func format_script() -> bool:
	if not _get_editor_interface().get_script_editor().is_visible_in_tree():
		return false
	var current_script := _get_editor_interface().get_script_editor().get_current_script()
	if not is_instance_valid(current_script) or not current_script is GDScript:
		return false
	var code_edit: CodeEdit = _get_editor_interface().get_script_editor().get_current_editor().get_base_editor()

	var formatted := []
	if not _format_code(current_script.resource_path, code_edit.text, formatted):
		return false

	_reload_code_edit(code_edit, formatted.back())
	return true


func install_or_update_gdtoolkit() -> void:
	if _install_task_id >= 0:
		_print_warning("Installing or updating gdformat, please be patient.")
		return
	if not _has_command(_get_pip_command()):
		printerr('Installation of GDScript Formatter failed: Command "%s" is required, please ensure it can be found in your environment.' % _get_pip_command())
		return
	_install_task_id = WorkerThreadPool.add_task(_install_or_update_gdtoolkit, true, "Install or update gdtoolkit.")
	while _install_task_id >= 0:
		if not WorkerThreadPool.is_task_completed(_install_task_id):
			await get_tree().process_frame
		else:
			_install_task_id = -1


func update_shortcut() -> void:
	for obj in _connection_list:
		obj.changed.disconnect(update_shortcut)

	_connection_list.clear()

	var shortcut := _get_shortcut()
	if is_instance_valid(shortcut):
		for event in shortcut.events:
			event = event as InputEvent
			if is_instance_valid(event):
				event.changed.connect(update_shortcut)
				_connection_list.push_back(event)

	_remove_format_tool_item_and_command()
	_add_format_tool_item_and_command()


func _on_project_settings_changed() -> void:
	var prev := _get_project_specific_settings().get(_SETTING_CUSTOM_SETTINGS_ENABLED, false) as bool
	var curr := ProjectSettings.get_setting(_SETTING_CUSTOM_SETTINGS_ENABLED) if ProjectSettings.has_setting(_SETTING_CUSTOM_SETTINGS_ENABLED) else false

	var settings := _get_project_specific_settings()
	# Update settings backup.
	if prev != curr:
		_update_project_specific_settings()
	else:
		var need_update := false
		for setting in [SETTING_LINE_LENGTH, SETTING_FORMAT_ON_SAVE, SETTING_FAST_BUT_UNSAFE]:
			if ProjectSettings.has_setting(setting):
				var backup_value := settings.get(setting, null)
				if backup_value == null or ProjectSettings.get_setting(setting) != backup_value:
					_update_project_specific_settings()
		return

	if curr:
		for setting_key in PackedStringArray(["SETTING_LINE_LENGTH", "SETTING_FORMAT_ON_SAVE", "SETTING_FAST_BUT_UNSAFE"]):
			var setting := get(setting_key) as String
			if not ProjectSettings.has_setting(setting):
				var default_value := get("DEFAULT" + setting_key.trim_prefix("SETTING"))
				ProjectSettings.set_setting(setting, settings.get(setting, default_value))
				ProjectSettings.set_initial_value(setting, default_value)


func _get_project_specific_settings() -> Dictionary:
	var cfg := ConfigFile.new()

	var cfg_file_path := (get_script() as Resource).resource_path.get_base_dir().path_join(_PROJECT_SPECIFIC_SETTINGS)
	if FileAccess.file_exists(cfg_file_path):
		cfg.load(cfg_file_path)

	var ret := {}
	ret[_SETTING_CUSTOM_SETTINGS_ENABLED] = cfg.get_value("", _SETTING_CUSTOM_SETTINGS_ENABLED, false)
	ret[SETTING_LINE_LENGTH] = cfg.get_value("", SETTING_LINE_LENGTH, DEFAULT_LINE_LENGTH)
	ret[SETTING_FORMAT_ON_SAVE] = cfg.get_value("", SETTING_FORMAT_ON_SAVE, DEFAULT_FORMAT_ON_SAVE)
	ret[SETTING_FAST_BUT_UNSAFE] = cfg.get_value("", SETTING_FAST_BUT_UNSAFE, DEFAULT_FAST_BUT_UNSAFE)
	return ret


func _update_project_specific_settings() -> void:
	var cfg := ConfigFile.new()

	var cfg_file_path := (get_script() as Resource).resource_path.get_base_dir().path_join(_PROJECT_SPECIFIC_SETTINGS)
	if FileAccess.file_exists(cfg_file_path):
		cfg.load(cfg_file_path)

	if ProjectSettings.has_setting(_SETTING_CUSTOM_SETTINGS_ENABLED):
		cfg.set_value("", _SETTING_CUSTOM_SETTINGS_ENABLED, ProjectSettings.get_setting(_SETTING_CUSTOM_SETTINGS_ENABLED))

	if ProjectSettings.has_setting(SETTING_LINE_LENGTH):
		cfg.set_value("", SETTING_LINE_LENGTH, ProjectSettings.get_setting(SETTING_LINE_LENGTH))
	if ProjectSettings.has_setting(SETTING_FORMAT_ON_SAVE):
		cfg.set_value("", SETTING_FORMAT_ON_SAVE, ProjectSettings.get_setting(SETTING_FORMAT_ON_SAVE))
	if ProjectSettings.has_setting(SETTING_FAST_BUT_UNSAFE):
		cfg.set_value("", SETTING_FAST_BUT_UNSAFE, ProjectSettings.get_setting(SETTING_FAST_BUT_UNSAFE))

	cfg.save(cfg_file_path)


func _on_resource_saved(resource: Resource) -> void:
	# Format on save
	if not _get_setting(SETTING_FORMAT_ON_SAVE, DEFAULT_FORMAT_ON_SAVE):
		return

	var gds := resource as GDScript
	if resource == get_script():
		return

	if not _has_format_tool_item or not is_instance_valid(gds):
		return

	var formatted := []
	if not _format_code(gds.resource_path, gds.source_code, formatted):
		return

	gds.source_code = formatted.back()
	ResourceSaver.save(gds)
	gds.reload()

	var script_editor := _get_editor_interface().get_script_editor()
	var open_script_editors := script_editor.get_open_script_editors()
	var open_scripts := script_editor.get_open_scripts()

	if not open_scripts.has(gds):
		return

	if script_editor.get_current_script() == gds:
		_reload_code_edit(script_editor.get_current_editor().get_base_editor(), formatted.back(), true)
	elif open_scripts.size() == open_script_editors.size():
		for i in range(open_scripts.size()):
			if open_scripts[i] == gds:
				_reload_code_edit(open_script_editors[i].get_base_editor(), formatted.back(), true)
				return
	else:
		printerr("GDScript Formatter error: Unknown situation, can't reload code editor in Editor. Please report this issue.")


func _install_or_update_gdtoolkit():
	var has_gdformat := _has_command(_get_gdformat_command())
	if has_gdformat:
		print("-- Beginning gdtoolkit update.")
	else:
		print("-- Beginning gdtoolkit installation.")

	var output := []
	var err := OS.execute(_get_pip_command(), ["install", "gdtoolkit"], output)
	if err == OK:
		if has_gdformat:
			print("-- Update of gdtoolkit successful.")
		else:
			print("-- Installation of gdtoolkit successful.")
		_add_format_tool_item_and_command()
	else:
		if has_gdformat:
			printerr("-- Update of gdtoolkit failed, exit code: ", err)
		else:
			printerr("-- Installation of gdtoolkit failed, exit code: ", err)
		printerr("\tPlease check below for more details.")
		print("\n".join(output))


func _add_format_tool_item_and_command() -> void:
	if _has_format_tool_item:
		return
	if not _has_command(_get_gdformat_command()):
		_print_warning('GDScript Formatter: The command "%s" can\'t be found in your environment.' % _get_gdformat_command())
		_print_warning('\tIf you have not installed "gdtoolkit", install it first.')
		_print_warning('\tIf you have installed "gdtoolkit", change "gdformat_command" to a valid command in the "GDScript Formatter" section in Editor Settings.')
		return
	add_tool_menu_item("GDScriptFormatter: Format script", format_script)
	var shortcut := _get_shortcut()
	_get_editor_interface().get_command_palette().add_command(
		"Format GDScript", "GDScript Formatter/Format GDScript", format_script, shortcut.get_as_text() if is_instance_valid(shortcut) else "None"
	)
	_has_format_tool_item = true


func _remove_format_tool_item_and_command() -> void:
	if not _has_format_tool_item:
		return
	_has_format_tool_item = false
	_get_editor_interface().get_command_palette().remove_command("GDScript Formatter/Format GDScript")
	remove_tool_menu_item("GDScriptFormatter: Format script")


func _has_command(command: String) -> bool:
	var output := []
	var err := OS.execute(command, ["--version"], output)

	return err == OK


func _reload_code_edit(code_edit: CodeEdit, new_text: String, tag_saved: bool = false) -> void:
	var caret_column := code_edit.get_caret_column()
	var caret_line := code_edit.get_caret_line()
	var scroll_hor := code_edit.scroll_horizontal
	var scroll_ver := code_edit.scroll_vertical

	# Breakpoints
	var breakpoints := _store_code_edit_info(code_edit.get_breakpointed_lines, code_edit.get_line)
	# Bookmarks
	var bookmarks := _store_code_edit_info(code_edit.get_bookmarked_lines, code_edit.get_line)
	# Folds
	var folds := _store_code_edit_info(code_edit.get_folded_lines, code_edit.get_line)

	# New text
	code_edit.text = new_text
	if tag_saved:
		code_edit.tag_saved_version()

	var new_text_line_count := code_edit.get_line_count()
	# Breakpoints
	_restore_code_edit_info(breakpoints, code_edit.get_line, code_edit.set_line_as_breakpoint, new_text_line_count)
	# Bookmarks
	_restore_code_edit_info(bookmarks, code_edit.get_line, code_edit.set_line_as_bookmarked, new_text_line_count)
	# Folds
	_restore_code_edit_info(folds, code_edit.get_line, func(line: int, _1: bool) -> void: code_edit.fold_line(line), new_text_line_count)

	code_edit.set_caret_column(caret_column)
	code_edit.set_caret_line(caret_line)
	code_edit.scroll_horizontal = scroll_hor
	code_edit.scroll_vertical = scroll_ver

	code_edit.update_minimum_size()

	code_edit.text_changed.emit()


func _store_code_edit_info(func_get_lines: Callable, func_get_line: Callable) -> Dictionary:
	var ret := {}
	for line in func_get_lines.call():
		ret[line] = func_get_line.call(line)
	return ret


func _restore_code_edit_info(prev_data: Dictionary, func_get_line: Callable, func_set_line: Callable, new_text_line_count: int) -> void:
	var prev_lines := PackedInt64Array(prev_data.keys())
	for idx in range(prev_lines.size()):
		var prev_line := prev_lines[idx] as int
		var prev_text := prev_data[prev_line] as String

		if func_get_line.call(prev_line).similarity(prev_text) > 0.9:
			func_set_line.call(prev_line, true)

		var up_line := prev_line - 1
		var down_line := prev_line + 1
		while up_line >= 0 or down_line < new_text_line_count:
			if down_line < new_text_line_count and func_get_line.call(down_line).similarity(prev_text) > 0.9:
				func_set_line.call(down_line, true)
				break
			if up_line >= 0 and func_get_line.call(up_line).similarity(prev_text) > 0.9:
				func_set_line.call(up_line, true)
				break

			up_line -= 1
			down_line += 1


func _get_setting(key: String, default: Variant) -> Variant:
	var settings := _get_project_specific_settings()
	if settings.get(_SETTING_CUSTOM_SETTINGS_ENABLED):
		return settings.get(key)
	var editor_settings := _get_editor_interface().get_editor_settings()
	if editor_settings.has_setting(key):
		return editor_settings.get_setting(key)
	return default


func _format_code(script_path: String, code: String, formatted: Array) -> bool:
	const tmp_file := "res://addons/gdscript_formatter/.tmp.gd"
	var f := FileAccess.open(tmp_file, FileAccess.WRITE)
	if not is_instance_valid(f):
		printerr("GDScript Formatter Error: Can't create tmp file.")
		return false
	f.store_string(code)
	f.close()

	var output := []
	var args := [ProjectSettings.globalize_path(tmp_file), "--line-length=%d" % _get_setting(SETTING_LINE_LENGTH, DEFAULT_LINE_LENGTH)]
	if _get_setting(SETTING_FAST_BUT_UNSAFE, DEFAULT_FAST_BUT_UNSAFE):
		args.push_back("--fast")
	var err := OS.execute(_get_gdformat_command(), args, output)
	if err == OK:
		f = FileAccess.open(tmp_file, FileAccess.READ)
		formatted.push_back(f.get_as_text())
		f.close()
	else:
		printerr("Format GDScript failed: ", script_path)
		printerr("\tExit code: ", err, " Output: ", output.front().strip_edges())
		printerr('\tIf your script does not have any syntax errors, this error is led by limitations of "gdtoolkit", e.g. multiline lambda.')

	DirAccess.remove_absolute(tmp_file)
	return err == OK


func _get_gdformat_command() -> String:
	return _get_editor_interface().get_editor_settings().get_setting(SETTING_GDFORMAT_COMMAND)


func _get_pip_command() -> String:
	return _get_editor_interface().get_editor_settings().get_setting(SETTING_PIP_COMMAND)


func _get_shortcut() -> Shortcut:
	return _get_editor_interface().get_editor_settings().get_setting(SETTING_SHORTCUT)


func _print_warning(str: String) -> void:
	print_rich("[color=orange]%s[/color]" % str)


func _get_editor_interface() -> EditorInterface:
	@warning_ignore("static_called_on_instance")  # 4.1 Compatible.
	return get_editor_interface()
