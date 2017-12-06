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
extends Reference

# Constants for tile flipping
# http://doc.mapeditor.org/reference/tmx-map-format/#tile-flipping
const FLIPPED_HORIZONTALLY_FLAG = 0x80000000
const FLIPPED_VERTICALLY_FLAG   = 0x40000000
const FLIPPED_DIAGONALLY_FLAG   = 0x20000000

# Main function
# Reads a source file and gives back a full PackedScene
func build(source_path, options):
	var map = read_file(source_path)
	if typeof(map) == TYPE_INT:
		return map
	if typeof(map) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA

	var err = validate_map(map)
	if err != OK:
		return err

	var map_size = Vector2(int(map.width), int(map.height))
	var cell_size = Vector2(int(map.tilewidth), int(map.tileheight))
	var map_mode = TileMap.MODE_SQUARE
	if "orientation" in map:
		match map.orientation:
			"isometric": map_mode = TileMap.MODE_ISOMETRIC
			# TODO: staggered and hexagonal orientations

	var tileset = build_tileset(map.tilesets, source_path)
	if typeof(tileset) != TYPE_OBJECT:
		# Error happened
		return tileset

	var root = Node2D.new()
	root.set_name(source_path.get_basename())

	for layer in map.layers:
		err = validate_layer(layer)
		if err != OK:
			return err

		var opacity = float(layer.opacity) if "opacity" in layer else 1.0
		var visible = bool(layer.visible) if "visible" in layer else false

		if layer.type == "tilelayer":
			var layer_data = layer.data

			var tilemap = TileMap.new()
			tilemap.set_name(layer.name)
			tilemap.cell_size = cell_size
			tilemap.self_modulate = Color(1.0, 1.0, 1.0, opacity);
			tilemap.visible = visible
			tilemap.mode = map_mode

			var offset = Vector2()
			if "offsetx" in layer:
				offset.x = int(layer.offsetx)
			if "offsety" in layer:
				offset.y = int(layer.offsety)

			tilemap.position = offset
			tilemap.tile_set = tileset

			var count = 0
			for tile_id in layer_data:
				var int_id = int(str(tile_id))

				if int_id == 0:
					count += 1
					continue

				var flipped_h = bool(int_id & FLIPPED_HORIZONTALLY_FLAG)
				var flipped_v = bool(int_id & FLIPPED_VERTICALLY_FLAG)
				var flipped_d = bool(int_id & FLIPPED_DIAGONALLY_FLAG)

				var gid = int_id & 0xFFFFFFFF & ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

				var cell_pos = Vector2(count % int(map_size.x), int(count / map_size.x))
				tilemap.set_cellv(cell_pos, gid, flipped_h, flipped_v, flipped_d)

				count += 1

			root.add_child(tilemap)
			tilemap.set_owner(root)

	var scene = PackedScene.new()
	scene.pack(root)
	return scene

# Make a tileset from a array of tilesets data
# Since Godot supports only one TileSet per TileMap, all tilesets from Tiled are combined
func build_tileset(tilesets, source_path):
	var result = TileSet.new()

	for ts in tilesets:
		var err = validate_tileset(ts)
		if err != OK:
			return err

		var spacing = int(ts.spacing) if "spacing" in ts and str(ts.spacing).is_valid_integer() else 0
		var margin = int(ts.margin) if "margin" in ts and str(ts.margin).is_valid_integer() else 0
		var firstgid = int(ts.firstgid)
		var image = load_image(ts.image, source_path)
		if typeof(image) != TYPE_OBJECT:
			# Error happened
			return image
		var imagesize = Vector2(int(ts.imagewidth), int(ts.imageheight))

		var tilesize = Vector2(int(ts.tilewidth), int(ts.tileheight))
		var tilecount = int(ts.tilecount)

		var gid = firstgid

		var x = margin
		var y = margin

		var i = 0
		while i < tilecount:
			var tilepos = Vector2(x, y)
			var region = Rect2(tilepos, tilesize)

			var rel_id = str(gid - firstgid)

			result.create_tile(gid)
			result.tile_set_texture(gid, image)
			result.tile_set_region(gid, region)

			gid += 1
			i += 1
			x += int(tilesize.x) + spacing
			if x >= int(imagesize.x) - margin:
				x = margin
				y += int(tilesize.y) + spacing

		if str(ts.name) != "":
			result.resource_name = ts.name

	return result


func load_image(rel_path, source_path):
	var total_path = rel_path if rel_path.is_abs_path() else source_path.get_base_dir().plus_file(rel_path)
	var dir = Directory.new()
	if not dir.file_exists(total_path):
		printerr("Image not found: %s" % [total_path])
		return ERR_FILE_NOT_FOUND

	var image = ImageTexture.new()
	image.load(total_path)
	image.set_flags(Texture.FLAGS_DEFAULT)

	return image


# Reads a file and returns its contents as a dictionary
# Returns an error code if fails
func read_file(path):
	var file = File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		return err

	var content = JSON.parse(file.get_as_text())
	if content.error != OK:
		printerr("Error parsing JSON: ", content.error_string)
		return content.error

	return content.result

# Validates the map dictionary content for missing or invalid keys
# Returns an error code
func validate_map(map):
	if not "type" in map or map.type != "map":
		printerr("Missing or invalid type property.")
		return ERR_INVALID_DATA
	elif not "version" in map or int(map.version) != 1:
		printerr("Missing or invalid map version.")
		return ERR_INVALID_DATA
	elif not "height" in map or not str(map.height).is_valid_integer():
		printerr("Missing or invalid height property.")
		return ERR_INVALID_DATA
	elif not "width" in map or not str(map.width).is_valid_integer():
		printerr("Missing or invalid width property.")
		return ERR_INVALID_DATA
	elif not "tileheight" in map or not str(map.tileheight).is_valid_integer():
		printerr("Missing or invalid tileheight property.")
		return ERR_INVALID_DATA
	elif not "tilewidth" in map or not str(map.tilewidth).is_valid_integer():
		printerr("Missing or invalid tilewidth property.")
		return ERR_INVALID_DATA
	elif not "layers" in map or typeof(map.layers) != TYPE_ARRAY:
		printerr("Missing or invalid layers property.")
		return ERR_INVALID_DATA
	elif not "tilesets" in map or typeof(map.tilesets) != TYPE_ARRAY:
		printerr("Missing or invalid tilesets property.")
		return ERR_INVALID_DATA
	return OK

# Validates the tileset dictionary content for missing or invalid keys
# Returns an error code
func validate_tileset(tileset):
	if not "firstgid" in tileset or not str(tileset.firstgid).is_valid_integer():
		printerr("Missing or invalid firstgid tileset property.")
		return ERR_INVALID_DATA
	elif not "tilewidth" in tileset or not str(tileset.tilewidth).is_valid_integer():
		printerr("Missing or invalid tilewidth tileset property.")
		return ERR_INVALID_DATA
	elif not "tileheight" in tileset or not str(tileset.tileheight).is_valid_integer():
		printerr("Missing or invalid tileheight tileset property.")
		return ERR_INVALID_DATA
	elif not "tilecount" in tileset or not str(tileset.tilecount).is_valid_integer():
		printerr("Missing or invalid tilecount tileset property.")
		return ERR_INVALID_DATA
	elif not "image" in tileset:
		printerr("Missing or invalid image tileset property.")
		return ERR_INVALID_DATA
	elif not "imagewidth" in tileset or not str(tileset.imagewidth).is_valid_integer():
		printerr("Missing or invalid imagewidth tileset property.")
		return ERR_INVALID_DATA
	elif not "imageheight" in tileset or not str(tileset.imageheight).is_valid_integer():
		printerr("Missing or invalid imageheight tileset property.")
		return ERR_INVALID_DATA
	return OK

# Validates the layer dictionary content for missing or invalid keys
# Returns an error code
func validate_layer(layer):
	if not "type" in layer:
		printerr("Missing or invalid type layer property.")
		return ERR_INVALID_DATA
	elif not "name" in layer:
		printerr("Missing or invalid name layer property.")
		return ERR_INVALID_DATA
	if layer.type == "tilelayer":
		if not "data" in layer or typeof(layer.data) != TYPE_ARRAY:
			printerr("Missing or invalid data layer property.")
			return ERR_INVALID_DATA
	return OK