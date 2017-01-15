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
extends EditorImportPlugin

const TiledMap = preload("tiled_map.gd")
const PLUGIN_NAME = "org.vnen.tiled_importer"
var dialog = null

func get_name():
	return PLUGIN_NAME

func get_visible_name():
	return "TileMap from Tiled Editor"

func config(base_control):
	dialog = preload("import_dialog.tscn").instance()
	base_control.add_child(dialog)

func import_dialog(path):

	var meta = null
	if (path != ""):
		meta = ResourceLoader.load_import_metadata(path)

	dialog.configure(self, path, meta)
	dialog.popup_centered()


func import(path, metadata):
	if metadata.get_source_count() != 1:
		return "Invalid number of sources (should be 1)."

	var src = metadata.get_source_path(0)

	var tiled_map = TiledMap.new()

	var options = {
		"single_tileset": metadata.get_option("single_tileset"),
		"embed": metadata.get_option("embed"),
		"rel_path": metadata.get_option("rel_path"),
		"image_flags": metadata.get_option("image_flags"),
		"separate_img_dir": metadata.get_option("separate_img_dir"),
		"custom_properties": metadata.get_option("custom_properties"),
		"post_script": str(metadata.get_option("post_script")).strip_edges(),
		"target": path,
	}

	tiled_map.init(src, options)

	var tiled_data = tiled_map.get_data()

	if typeof(tiled_data) == TYPE_STRING:
		# If is string then it's an error message
		return tiled_data

	var dir = Directory.new()
	dir.make_dir_recursive(path.get_base_dir().plus_file(options.rel_path.substr(0, options.rel_path.length() - 1)))

	var err = tiled_map.build()

	var f = File.new()
	metadata.set_editor(PLUGIN_NAME)
	metadata.set_source_md5(0, f.get_md5(src))

	if err != "OK":
		printerr(err)
		if f.file_exists(path):
			var res = ResourceLoader.load(path)
			res.set_import_metadata(metadata)
			ResourceSaver.save(path, res, ResourceSaver.FLAG_CHANGE_PATH)
		return err
	var scene = tiled_map.get_scene()

	if not options["post_script"].empty():

		var script = load(options["post_script"])
		if not script or not script extends GDScript:
			return "Error loading post import script"

		script = script.new()
		if not script.has_method("post_import"):
			return 'Script doesn\'t have "post_import" method'

		scene = script.post_import(scene)

		if scene == null or not scene extends Node2D:
			return "Invalid scene returned from post import script"

	var packed_scene = PackedScene.new()
	err = packed_scene.pack(scene)
	if err != OK:
		return "Error packing scene"

	packed_scene.set_import_metadata(metadata)

	err = ResourceSaver.save(path, packed_scene, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		return "Error saving scene"

	return "OK"
