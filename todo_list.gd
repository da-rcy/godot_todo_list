@tool
class_name TodoList
extends EditorPlugin

var dock: Control
var list: VBoxContainer
var save_path: String = "user://todo_list.json"

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Todo"
	
	var scroll = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(scroll)
	
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	
	var add_button := Button.new()
	add_button.text = "+ Add New Item"
	add_button.pressed.connect(_add_item)
	dock.add_child(add_button)
	
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	
	_load_todos()

func _exit_tree() -> void:
	_save_todos()
	remove_control_from_docks(dock)
	dock.free()

func _add_item(text: String = "New Task") -> void:
	var item = _create_item(text)
	list.add_child(item)

func _create_item(text: String, is_done: bool = false) -> Control:
	var container = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label := RichTextLabel.new()
	label.text = text
	label.bbcode_enabled = true
	label.fit_content = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.set_meta("done", false)
	label.set_meta("raw_text", text)
	container.add_child(label)
	
	var menu := PopupMenu.new()
	menu.add_item("Edit")
	menu.add_item("Mark Complete")
	menu.add_item("Delete")
	container.add_child(menu)
	
	container.gui_input.connect(func(event)->void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			menu.position = get_viewport().get_mouse_position()
			menu.popup()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_edit_item(container, label)
	)
	
	menu.id_pressed.connect(func(id)->void:
		match id:
			0: _edit_item(container, label)
			1: _mark_done(label)
			2: container.queue_free()
	)
	
	return container

func _edit_item(container: HBoxContainer, label: RichTextLabel) -> void:
	var current_text = label.get_meta("raw_text", label.text)
	
	label.visible = false
	
	var le := LineEdit.new()
	le.text = current_text
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(le)
	container.move_child(le, 0)
	
	le.grab_focus()
	le.select_all()
	
	var finish_edit = func(new_text: String) -> void:
		if new_text.strip_edges() != "":
			label.text = new_text
			label.set_meta("raw_text", new_text)
			
			if label.get_meta("done", false):
				label.clear()
				label.append_text("[i][s]" + new_text + "[/s][/i]")
			_save_todos()
		label.visible = true
		le.queue_free()
	
	le.text_submitted.connect(finish_edit)
	le.focus_exited.connect(func() -> void:
		finish_edit.call(le.text)
	)
	
func _mark_done(label: RichTextLabel) -> void:
	var is_done = label.get_meta("done", false)
	
	if is_done:
		label.clear()
		label.append_text(label.get_meta("raw_text", ""))
		label.set_meta("done", false)
	else:
		var raw := label.text
		label.clear()
		label.append_text("[i][s]" + raw + "[/s][/i]")
		label.set_meta("raw_text", raw)
		label.set_meta("done", true)

func _save_todos() -> void:
	var todos = []
	for child in list.get_children():
		if child is HBoxContainer:
			var label = child.get_child(0) as RichTextLabel
			if label:
				todos.append({
					"text": label.get_meta("raw_text", label.text),
					"done": label.get_meta("done", false)
				})
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(todos))
		file.close()

func _load_todos() -> void:
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var todos = json.data
			if todos is Array:
				for todo in todos:
					if todo is Dictionary and todo.has("text"):
						var item = _create_item(todo.get("text", ""), todo.get("done", false))
						list.add_child(item)
