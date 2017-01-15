# The MIT License (MIT)
#
# Copyright (c) 2016 George Marques
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

tool
extends ConfirmationDialog

var options
var origin_fd
var target_fd
var script_fd
var popup_menu
var import_plugin

var initialized = false

func configure(plugin, tgt_path, metadata):
	import_plugin = plugin
	if (metadata):
		assert(metadata.get_source_count() > 0)

		var src_path = import_plugin.expand_source_path(metadata.get_source_path(0))
		get_node("MainDialog/Origin/Path").set_text(src_path)
		get_node("MainDialog/Target/Path").set_text(tgt_path)
		get_node("MainDialog/PostImportScript/Path").set_text(str(metadata.get_option("post_script")))

		for opt_code in options:
			var opt = options[opt_code]
			if opt.type == TreeItem.CELL_MODE_CHECK:
				opt.item.set_checked(1, metadata.get_option(opt_code))
			elif opt.type == TreeItem.CELL_MODE_STRING:
				opt.item.set_text(1, metadata.get_option(opt_code))
			elif opt.type == TreeItem.CELL_MODE_CUSTOM:
				opt.item.set_metadata(1, metadata.get_option(opt_code))
				opt.item.set_text(1, flags_text(metadata.get_option(opt_code), options[opt_code].flags))

func _ready():

	if initialized:
		return

	initialized = true

	options = {
		"single_tileset": {
			"name": "Single TileSet",
			"tooltip": "Mix all Tiled TileSets into a single Godot resource. Needed if your layers uses more than one tileset each.",
			"type": TreeItem.CELL_MODE_CHECK,
			"text": "On",
			"default": true,
		},
		"embed": {
			"name": "Embed resources",
			"tooltip": "Save the resources (images, tilesets) embedded in the scene, as opposed to saving as external files.",
			"type": TreeItem.CELL_MODE_CHECK,
			"text": "On",
			"default": false,
		},
		"rel_path": {
			"name": "Relative resource path",
			"tooltip": "Relative path to save the resources (images, tilesets), based on the target scene directory.",
			"type": TreeItem.CELL_MODE_STRING,
			"text": "",
			"default": "tilesets/",
		},
		"separate_img_dir": {
			"name": "Create separate image directories",
			"tooltip": "Create a directory per TileSet when using image collection sets.",
			"type": TreeItem.CELL_MODE_CHECK,
			"text": "On",
			"default": false,
		},
		"image_flags": {
			"name": "Image flags",
			"tooltip": "Flags to apply to the imported TileSet image.",
			"type": TreeItem.CELL_MODE_CUSTOM,
			"text": "",
			"flags": "Mipmaps,Repeat,Filter,Anistropic,sRGB,Mirrored Repeat",
			"default": 0,
		},
		"custom_properties": {
			"name": "Custom properties",
			"tooltip": "Whether to import custom properties as meta data.",
			"type": TreeItem.CELL_MODE_CHECK,
			"text": "On",
			"default": true,
		}
	}

	create_options_tree()

	origin_fd = EditorFileDialog.new()
	origin_fd.set_mode(EditorFileDialog.MODE_OPEN_FILE)
	origin_fd.set_access(EditorFileDialog.ACCESS_FILESYSTEM)
	origin_fd.add_filter("*.json;Tiled JSON Map")
	origin_fd.add_filter("*.tmx;Tiled XML Map")
	origin_fd.connect("file_selected", self, "_on_origin_selected")
	add_child(origin_fd)

	target_fd = EditorFileDialog.new()
	target_fd.set_mode(EditorFileDialog.MODE_SAVE_FILE)
	target_fd.set_access(EditorFileDialog.ACCESS_RESOURCES)
	target_fd.add_filter("*.scn;Scene")
	target_fd.connect("file_selected", self, "_on_target_selected")
	add_child(target_fd)

	script_fd = EditorFileDialog.new()
	script_fd.set_mode(EditorFileDialog.MODE_OPEN_FILE)
	script_fd.set_access(EditorFileDialog.ACCESS_RESOURCES)
	script_fd.add_filter("*.gd;GDScript")
	script_fd.connect("file_selected", self, "_on_script_selected")
	add_child(script_fd)

	popup_menu = PopupMenu.new()
	popup_menu.connect("item_pressed", self, "_on_popup_item_pressed")
	add_child(popup_menu)


func create_options_tree():

	var tree = get_node("MainDialog/Options")
	tree.set_hide_root(true)
	tree.set_columns(2)
	var root = tree.create_item()

	for opt_code in options:

		var opt = options[opt_code]

		var item = tree.create_item(root)
		item.set_text(0, opt.name)
		item.set_cell_mode(1, opt.type)
		item.set_editable(1, true)
		item.set_text(1, opt.text)
		item.set_tooltip(0, opt.tooltip)
		item.set_tooltip(1, opt.tooltip)
		item.set_metadata(0, opt_code)

		if opt.type == TreeItem.CELL_MODE_CHECK:
			item.set_checked(1, opt.default)
		elif opt.type == TreeItem.CELL_MODE_STRING:
			item.set_text(1, opt.default)
		elif opt.type == TreeItem.CELL_MODE_CUSTOM:
			item.set_editable(1, true)
			item.set_metadata(1, opt.default)
			item.set_text(1, flags_text(opt.default, opt.flags))

		# Save the item for easy reference later
		options[opt_code].item = item


func flags_text(value, flags):
	var arr_flags = flags.split(',', false)
	var text = ""

	for i in range(arr_flags.size()):
		if value & (1 << i):
			if text != "":
				text += ", "
			text += arr_flags[i]

	if text == "":
		return "None"

	return text


func validate_options():
	var dir = Directory.new()
	var origin_path = get_node("MainDialog/Origin/Path").get_text()
	var target_path = get_node("MainDialog/Target/Path").get_text()
	var rel_res_path = options.rel_path.item.get_text(1)

	if not origin_path.is_abs_path():
		return "Origin path must be absolute."
	if not (origin_path.to_lower().ends_with(".json") or \
	        origin_path.to_lower().ends_with(".tmx")):
		return "Origin must be a JSON or TMX file."
	if not dir.file_exists(origin_path):
		return "Origin file does not exist."

	if not target_path.is_abs_path():
		return "Target path must be absolute."
	if not target_path.to_lower().begins_with("res://"):
		return "Target must be inside the res:// path."
	if not target_path.to_lower().ends_with(".scn"):
		return "Target must be a .scn scene file."

	if options.embed.item.is_checked(1) and (
			not rel_res_path.is_rel_path()
			or not rel_res_path.ends_with("/")
		):
		return "Relative resource path must be relative and end with a slash."

	return "OK"


func _on_Options_custom_popup_edited( arrow_clicked ):

	var item = get_node("MainDialog/Options").get_edited()
	if item.get_cell_mode(1) != TreeItem.CELL_MODE_CUSTOM:
		return

	popup_menu.clear()

	var pop_place = get_node("MainDialog/Options").get_custom_popup_rect()

	var opt = options[item.get_metadata(0)]
	var flags = opt.flags.split(',', false)
	var value = item.get_metadata(1)
	for i in range(flags.size()):
		popup_menu.add_check_item(flags[i], i)
		if value & (1 << i):
			popup_menu.set_item_checked(i, true)

	popup_menu.set_pos(pop_place.pos)
	popup_menu.popup()


func _on_popup_item_pressed(id):

	var item = get_node("MainDialog/Options").get_edited()
	var value = item.get_metadata(1)
	var new_value = 0

	if value & (1 << id):
		new_value = value & ~(1 << id)
	else:
		new_value = value | (1 << id)

	item.set_metadata(1, new_value)
	item.set_text(1, flags_text(new_value, options[item.get_metadata(0)].flags))


func _on_origin_browse_pressed():
	origin_fd.popup_centered_ratio()

func _on_target_browse_pressed():
	target_fd.popup_centered_ratio()

func _on_script_browse_pressed():
	script_fd.popup_centered_ratio()

func _on_origin_selected(path):
	get_node("MainDialog/Origin/Path").set_text(path)

func _on_target_selected(path):
	get_node("MainDialog/Target/Path").set_text(path)

func _on_script_selected(path):
	get_node("MainDialog/PostImportScript/Path").set_text(path)


func _on_ImportTilemap_confirmed():
	var alert = get_node("ErrorAlert")
	var valid = validate_options()
	if valid != "OK":
		alert.set_text(valid)
		alert.popup_centered_minsize()
		return

	var imd = ResourceImportMetadata.new()
	imd.add_source(get_node("MainDialog/Origin/Path").get_text())
	imd.set_option("post_script", get_node("MainDialog/PostImportScript/Path").get_text().strip_edges())

	for opt_code in options:
		var opt = options[opt_code]
		if opt.type == TreeItem.CELL_MODE_CHECK:
			imd.set_option(opt_code, opt.item.is_checked(1))
		elif opt.type == TreeItem.CELL_MODE_STRING:
			imd.set_option(opt_code, opt.item.get_text(1))
		elif opt.type == TreeItem.CELL_MODE_CUSTOM:
			imd.set_option(opt_code, opt.item.get_metadata(1))

	var f = File.new()
	imd.set_source_md5(0, f.get_md5(imd.get_source_path(0)))

	var err = import_plugin.import(get_node("MainDialog/Target/Path").get_text(), imd)

	if err != "OK":
		alert.set_text("Error when importing:\n%s" % [err])
		alert.popup_centered_minsize()
		return

	hide()
