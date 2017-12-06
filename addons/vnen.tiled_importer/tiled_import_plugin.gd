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

var TiledMapReader = preload("tiled_map_reader.gd")

func get_importer_name():
	return "vnen.tiled_importer"

func get_visible_name():
	return "Scene"

func get_recognized_extensions():
	return ["json", "tmx"]

func get_save_extension():
	return "scn"

func get_resource_type():
	return "PackedScene"

func get_preset_count():
	return 1

func get_preset_name(preset):
	match preset:
		0: return "Default"

func get_import_options(preset):
	return []

func import(source_file, save_path, options, r_platform_variants, r_gen_files):
	print(source_file)
	var map_reader = TiledMapReader.new()

	var scene = map_reader.build(source_file, options)

	if typeof(scene) != TYPE_OBJECT:
		# Error happened
		return scene

	return ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], scene, ResourceSaver.FLAG_BUNDLE_RESOURCES)

func get_option_visibility(option, options):
	return true
