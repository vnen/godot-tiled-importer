# The MIT License (MIT)
#
# Copyright (c) 2017 George Marques
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

var base_plugin = null

func config(base):
	base_plugin = base

func get_importer_name():
	return PLUGIN_NAME

func get_visible_name():
	return "Tiled Map to Scene"

func get_recognized_extensions():
	return ["tmx", "json"]

func get_save_extension():
	return "scn"

func get_resource_type():
	return "PackedScene"

func get_option_visibility(option, options):
	return true

func get_preset_count():
	return 1

func get_preset_name(preset):
	# There is only one preset, so we will only return that one ever
	return "Default"

func get_import_options(preset):
	var options =  [
		{
			name = "post_scripts",
			default_value = [],
			#hint_string = "Post-Import Scripts",
			#usage = "The importer will call post_import(scene) on each script file in the array. post_import() has to return the changed scene. (optional)",
		},
		{
			name = "custom_properties",
			default_value = true,
			#hint_string = "Custom properties",
			#usage = "Whether to import custom properties as meta data. Custom properties set as a dictionary in the tileset's meta data as 'tile_meta', indexed by the unique tile IDs.",
		},
		{
			name = "bundle_tilesets",
			default_value = false,
			#hint_string = "Bundle TileSets into one",
			#usage = "Mix all Tiled TileSets into a single Godot resource named after the map. Needed if your layers uses more than one tileset each. If false, each tileset will be saved individually using its Tiled name.",
		},
		{
			name = "save_tilesets",
			default_value = true,
			#hint_string = "Save TileSets inside res://",
			#usage = "Save the generated TileSet .res files directly inside the project folder instead of only embedding them inside the generated scene.",
		},
		{
			name = "tileset_directory",
			default_value = "res://.import/tilesets/",
			#hint_string = "Tileset Directory",
			#usage = "The absolute directory inside the project where all TileSet resources generated during TileMap import are saved. Only used if 'Save Tilesets' is true.",
		},
	]
	
	return options


func import(src, path, import_options, r_platform_variants, r_gen_files):
	var tiled_map = TiledMap.new()

	var options = {}
	for key in import_options:
		options[key] = import_options[key]

	options["target"] = path
	print(options.tileset_directory)
	if options.tileset_directory != "":
		if options.tileset_directory.is_abs_path():
			if options.tileset_directory[-1] != "/":
				options.tileset_directory = options.tileset_directory + "/"
		else:
			print("Cannot find tileset directory, tilesets will not be saved.")
			options.save_tilesets = false
	print(options.tileset_directory)

	tiled_map.init(src, options)

	var tiled_data = tiled_map.get_data()

	if typeof(tiled_data) == TYPE_STRING:
		# If it's a string then it's an error message
		print(tiled_data)
		return FAILED

	if options.save_tilesets:
		var dir = Directory.new()
		dir.make_dir_recursive(options.tileset_directory)

	var err = tiled_map.build()
	if err != "OK":
		return FAILED

	var scene = tiled_map.get_scene()

	for script_path in options["post_scripts"]:
		if typeof(script_path) != TYPE_STRING:
			continue
		
		script_path = script_path.strip_edges()
		
		var script = load(script_path)
		if not script or not script is GDScript:
			print("Error loading post import script %s" % [script_path])
			return FAILED

		script = script.new()
		if not script.has_method("post_import"):
			print('Script %s doesn\'t have "post_import" method' % script_path)
			return FAILED

		scene = script.post_import(scene)

		if scene == null or not scene is Node2D:
			print("Invalid scene returned from post import script %s" % script_path)
			return FAILED

	var packed_scene = PackedScene.new()
	err = packed_scene.pack(scene)
	if err != OK:
		print("Error packing scene")
		return FAILED

	err = ResourceSaver.save("res://.import/prototype_tilemap.tmx-1fbab38439605f9c3c861b178197d792.scn", packed_scene)
	if err != OK:
		print("Error saving scene")
		return FAILED

	if base_plugin != null:
		base_plugin.reload_scene(src)

	return OK
