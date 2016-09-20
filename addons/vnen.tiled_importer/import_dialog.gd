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
var import_plugin

var initialized = false

func configure(plugin, tgt_path, metadata):
	import_plugin = plugin
	if (metadata):
		assert(metadata.get_source_count() > 0)

		var src_path = import_plugin.expand_source_path(metadata.get_source_path(0))
		get_node("MainDialog/Origin/Path").set_text(src_path)
		get_node("MainDialog/Target/Path").set_text(tgt_path)

		for opt_code in options:
			var opt = options[opt_code]
			if opt.type == TreeItem.CELL_MODE_CHECK:
				opt.item.set_checked(1, metadata.get_option(opt_code))
			elif opt.type == TreeItem.CELL_MODE_STRING:
				opt.item.set_text(1, metadata.get_option(opt_code))

func _ready():

	if initialized:
		return
	else:
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
		}
	}

	create_options_tree()

	origin_fd = FileDialog.new()
	origin_fd.set_mode(FileDialog.MODE_OPEN_FILE)
	origin_fd.set_access(FileDialog.ACCESS_FILESYSTEM)
	origin_fd.add_filter("*.json;Tiled JSON Map")
	origin_fd.add_filter("*.tmx;Tiled XML Map")
	origin_fd.connect("file_selected", self, "_on_origin_selected")
	add_child(origin_fd)

	target_fd = FileDialog.new()
	target_fd.set_mode(FileDialog.MODE_SAVE_FILE)
	target_fd.set_access(FileDialog.ACCESS_RESOURCES)
	target_fd.add_filter("*.scn;Scene")
	target_fd.connect("file_selected", self, "_on_target_selected")
	add_child(target_fd)


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

		if opt.type == TreeItem.CELL_MODE_CHECK:
			item.set_checked(1, opt.default)
		elif opt.type == TreeItem.CELL_MODE_STRING:
			item.set_text(1, opt.default)

		# Save the item for easy reference later
		options[opt_code].item = item

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

func _on_origin_browse_pressed():
	origin_fd.popup_centered_ratio()

func _on_target_browse_pressed():
	target_fd.popup_centered_ratio()

func _on_origin_selected(path):
	get_node("MainDialog/Origin/Path").set_text(path)

func _on_target_selected(path):
	get_node("MainDialog/Target/Path").set_text(path)


func _on_ImportTilemap_confirmed():
	var alert = get_node("ErrorAlert")
	var valid = validate_options()
	if valid != "OK":
		alert.set_text(valid)
		alert.popup_centered_minsize()
		return

	var imd = ResourceImportMetadata.new()
	imd.add_source(get_node("MainDialog/Origin/Path").get_text())

	for opt_code in options:
		var opt = options[opt_code]
		if opt.type == TreeItem.CELL_MODE_CHECK:
			imd.set_option(opt_code, opt.item.is_checked(1))
		elif opt.type == TreeItem.CELL_MODE_STRING:
			imd.set_option(opt_code, opt.item.get_text(1))

	var f = File.new()
	imd.set_source_md5(0, f.get_md5(imd.get_source_path(0)))

	var err = import_plugin.import(get_node("MainDialog/Target/Path").get_text(), imd)

	if err != "OK":
		alert.set_text("Error when importing:\n%s" % [err])
		alert.popup_centered_minsize()
		return

	hide()
