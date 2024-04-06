@tool
extends EditorPlugin

var _preference: Resource
var _shortcut: Shortcut
var _has_format_tool_item: bool = false
var _has_install_update_tool_item: bool = false
var _install_task_id: int = -1
var _connection_list: Array[Resource] = []

const _PREFERENCE_SCRIPT = """@tool
extends Resource
## How many characters per line to allow.
@export var line_length := 100:
	set(v):
		line_length = v
		emit_changed()

## If true, will skip safety checks.
@export var fast_but_unsafe := false:
	set(v):
		fast_but_unsafe = v
		emit_changed()

## If true, will format on save.
@export var format_on_save := false:
	set(v):
		format_on_save = v
		emit_changed()

## The gdformat command to use in command line.
## Default is "gdformat".
@export var gdformat_command := "gdformat":
	set(v):
		gdformat_command = v
		emit_changed()

## The pip command to use in command line.
## Default is "pip".
@export var pip_command := "pip":
	set(v):
		pip_command = v
		emit_changed()
"""


func _init() -> void:
	var shortcur_res_file := (get_script() as Resource).resource_path.get_base_dir().path_join(
		"format_shortcut.tres"
	)
	if FileAccess.file_exists(shortcur_res_file):
		_shortcut = load(shortcur_res_file)
	if not is_instance_valid(_shortcut):
		var default_shortcut := InputEventKey.new()
		default_shortcut.echo = false
		default_shortcut.pressed = true
		default_shortcut.keycode = KEY_F
		default_shortcut.shift_pressed = true
		default_shortcut.alt_pressed = true

		_shortcut = Shortcut.new()
		_shortcut.events.push_back(default_shortcut)
		ResourceSaver.save(_shortcut, shortcur_res_file)

	_shortcut.changed.connect(update_shortcut)

	var preference_res_file = shortcur_res_file.get_base_dir().path_join("format_preference.tres")
	if not FileAccess.file_exists(preference_res_file):
		_preference = Resource.new()
		var script = GDScript.new()
		script.source_code = _PREFERENCE_SCRIPT
		_preference.set_script(script)
		ResourceSaver.save(_preference, preference_res_file)

	_preference = ResourceLoader.load(preference_res_file, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Update script for plugin updating, then reload it.
	(_preference.get_script() as GDScript).source_code = _PREFERENCE_SCRIPT
	ResourceSaver.save(_preference, preference_res_file)
	_preference = load(preference_res_file)

	_preference.changed.connect(_on_preference_changed)
	_on_preference_changed()


func _enter_tree() -> void:
	if not _has_command(_get_gdformat_command()):
		print_rich(
			(
				'[color=yellow]GDScript Formatter: The command "%s" can\'t be found in your envrionment.[/color]'
				% _get_gdformat_command()
			)
		)
	else:
		_add_format_tool_item()
		EditorInterface.get_command_palette().add_command(
			"Format GDScript",
			"GDScript Formatter/Format GDScript",
			Callable(self, "format_script"),
			_shortcut.get_as_text()
		)

	if not _has_command(_get_pip_command()):
		print_rich(
			'[color=yellow]Installs gdtoolkit is required "%s".[/color]' % _get_pip_command()
		)
		print_rich(
			"\t[color=yellow]Please install it and ensure it can be found in your envrionment.[/color]"
		)
	else:
		add_tool_menu_item(
			"GDScriptFormatter: Install/Update gdtoolkit", install_or_update_gdtoolkit
		)
		_has_install_update_tool_item = true

	update_shortcut()


func _exit_tree() -> void:
	(
		EditorInterface
		. get_command_palette()
		. remove_command(
			"GDScript Formatter/Format GDScript",
		)
	)
	if _has_format_tool_item:
		remove_tool_menu_item("GDScriptFormatter: Format script")
	if _has_install_update_tool_item:
		remove_tool_menu_item("GDScriptFormatter: Install/Update gdtoolkit")


func _shortcut_input(event: InputEvent) -> void:
	if _shortcut.matches_event(event) and event.is_pressed() and not event.is_echo():
		if format_script():
			get_tree().root.set_input_as_handled()


func format_script() -> bool:
	if not EditorInterface.get_script_editor().is_visible_in_tree():
		return false
	var current_script = EditorInterface.get_script_editor().get_current_script()
	if not is_instance_valid(current_script) or not current_script is GDScript:
		return false
	var code_edit: CodeEdit = (
		EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	)

	var formatted := []
	if not _format_code(code_edit.text, formatted):
		printerr("Format GDScript failed: ", current_script.resource_path)
		return false

	_reload_code_edit(code_edit, formatted.back())
	return true


func install_or_update_gdtoolkit() -> void:
	if _install_task_id >= 0:
		print_rich("Already installing or updating gdformat, please be patient.")
		return
	if not _has_command(_get_pip_command()):
		printerr(
			(
				'Install GDScript Formatter Failed: command "%s" is required, please ensure it can be found in your environment.'
				% _get_pip_command()
			)
		)
		return
	_install_task_id = WorkerThreadPool.add_task(
		_install_or_update_gdtoolkit, true, "Install or update gdtoolkit."
	)
	while _install_task_id >= 0:
		if not WorkerThreadPool.is_task_completed(_install_task_id):
			await get_tree().process_frame
		else:
			_install_task_id = -1


func update_shortcut() -> void:
	for obj in _connection_list:
		obj.changed.disconnect(update_shortcut)

	_connection_list.clear()

	for event in _shortcut.events:
		event = event as InputEvent
		if is_instance_valid(event):
			event.changed.connect(update_shortcut)
			_connection_list.push_back(event)

	(
		EditorInterface
		. get_command_palette()
		. remove_command(
			"GDScript Formatter/Format GDScript",
		)
	)

	EditorInterface.get_command_palette().add_command(
		"Format GDScript",
		"GDScript Formatter/Format GDScript",
		format_script,
		_shortcut.get_as_text()
	)


func _on_preference_changed() -> void:
	if _preference.format_on_save and not resource_saved.is_connected(_on_resource_saved):
		resource_saved.connect(_on_resource_saved)
	elif not _preference.format_on_save and resource_saved.is_connected(_on_resource_saved):
		resource_saved.disconnect(_on_resource_saved)


func _on_resource_saved(resource: Resource) -> void:
	var gds := resource as GDScript

	if resource == get_script():
		return

	if not _has_format_tool_item or not is_instance_valid(gds):
		return

	var formatted := []
	if not _format_code(gds.source_code, formatted):
		printerr("Format GDScript failed: ", gds.resource_path)
		return

	gds.source_code = formatted.back()
	ResourceSaver.save(gds)
	gds.reload()

	var script_editor := get_editor_interface().get_script_editor()
	var open_script_editors := script_editor.get_open_script_editors()
	var open_scripts := script_editor.get_open_scripts()

	if not open_scripts.has(gds):
		return

	if script_editor.get_current_script() == gds:
		_reload_code_edit(
			script_editor.get_current_editor().get_base_editor(), formatted.back(), true
		)
	elif open_scripts.size() == open_script_editors.size():
		for i in range(open_scripts.size()):
			if open_scripts[i] == gds:
				_reload_code_edit(open_script_editors[i].get_base_editor(), formatted.back(), true)
				return
	else:
		printerr(
			"GDScript Formatter error: Unkonwn situation, can't reload code editor in Editor. Please repoert an issue."
		)


func _install_or_update_gdtoolkit():
	var has_gdformat = _has_command(_get_gdformat_command())
	if has_gdformat:
		print("-- Begin update gdtoolkit.")
	else:
		print("-- Begin install gdtoolkit.")
	var output := []
	var err := OS.execute(_get_pip_command(), ["install", "gdtoolkit"], output)
	if err == OK:
		if has_gdformat:
			print("-- Update gdtoolkit successfully.")
		else:
			print("-- Install gdtoolkit successfully.")
		if not _has_format_tool_item:
			_add_format_tool_item()
	else:
		if has_gdformat:
			printerr("-- Update gdtoolkit failed, exit code: ", err)
		else:
			printerr("-- Install gdtoolkit failed, exit code: ", err)
		printerr("\tPlease check below for more details.")
		print("\n".join(output))


func _add_format_tool_item() -> void:
	add_tool_menu_item("GDScriptFormatter: Format script", format_script)
	_has_format_tool_item = true


func _has_command(command: String) -> bool:
	var output := []
	var err := OS.execute(command, ["--version"], output)
	return err == OK


func _reload_code_edit(code_edit: CodeEdit, new_text: String, tag_saved: bool = false) -> void:
	var column := code_edit.get_caret_column()
	var line := code_edit.get_caret_line()
	var scroll_hor := code_edit.scroll_horizontal
	var scroll_ver := code_edit.scroll_vertical

	code_edit.text = new_text
	if tag_saved:
		code_edit.tag_saved_version()

	code_edit.set_caret_column(column)
	code_edit.set_caret_line(line)
	code_edit.scroll_horizontal = scroll_hor
	code_edit.scroll_vertical = scroll_ver


func _format_code(code: String, formated: Array) -> bool:
	const tmp_file = "res://addons/gdscript_formatter/.tmp.gd"
	var f = FileAccess.open(tmp_file, FileAccess.WRITE)
	if not is_instance_valid(f):
		printerr("GDScript Formatter Error: can't create tmp file.")
		return false
	f.store_string(code)
	f.close()

	var output := []
	var args := [
		ProjectSettings.globalize_path(tmp_file), "--line-length=%d" % _preference.line_length
	]
	if _preference.fast_but_unsafe:
		args.push_back("--fast")
	var err = OS.execute(_get_gdformat_command(), args, output)
	if err == OK:
		f = FileAccess.open(tmp_file, FileAccess.READ)
		formated.push_back(f.get_as_text())
		f.close()
	else:
		printerr("\tExit code: ", err)

	DirAccess.remove_absolute(tmp_file)
	return err == OK


func _get_gdformat_command() -> String:
	return _preference.gdformat_command


func _get_pip_command() -> String:
	return _preference.pip_command
