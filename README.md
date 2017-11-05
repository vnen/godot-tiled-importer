# Tiled Map Importer

This is a plugin for [Godot Engine](https://godotengine.org) to import
`TileMap`s and `TileSet`s from the [Tiled Map Editor](http://www.mapeditor.org).

![](https://i.imgur.com/iRgqhlK.png)

## Installation

Simply download it from Godot Asset Library: https://godotengine.org/asset-library/asset/25.

Alternatively, download or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder.

Then enable the plugin in the Project Settings' Plugins tab.

## Features

* Import Tiled file as a Godot scene. Each layer in Tiled is a TileMap in Godot.
* Both `.tmx` (XML) and `.json` formats.
* Support for Base64 encoded map.
* Orthogonal and isometric maps.
* Import visibility and opacity from layers.
* Import collision/occluder/navigation shapes (based on Tiled object type).
* Custom import options, such as whether to embed the TileSet resource into the scene.
* Support for image layers.
* Support for object layers, which are imported as StaticBody2D or LightOccluder2D
  for shapes (depending on the `type` property) and as Sprite for tiles.
* Custom properties for maps, layers, tilesets, and objects are imported as
  metadata.
* Custom properties for tiles are imported as a dictionary into the tileset's `tile_meta` metadata.
* Support for post-import scripts.

## Usage

While the plugin is active, all .tmx files in the project directory will be automatically converted.
To change a TileMap's import settings, select it in the FileSystem dock and check out the Import dock.

The TileSets will either be embedded into the resulting Scene or saved inside the specified directory.
Source images are not moved, references are kept where they were.

## Caveats on Tiled maps

* Godot TileSet tiles only have one collision shape, so the last collision object found will overwrite
  the others.

* The same goes for navigation/occluder polygons.

* There's no Ellipse shape in Godot. If you use it as a collision object, it
  will be converted to a capsule shape, which may be imprecise. However, if the
  Tiled ellipse is a perfect circle, a CircleShape2D will be used instead.

* Set the type of the object to `navigation` or `occluder` to use it as such.

* Objects in object layer cannot be set as `navigation`.

* Only polygons can be used as occluder/navigation. For those, you can make a
  polygon or polyline in Tiled. Rectangles will be converted to polygons, but
  ellipses are not accepted.

* Occluder shapes are set as closed if a polygon is used and as open if it is
  a polyline.

* Godot has no decompression function (yet). So don't save the Tiled Map with
  any compressed format. "Base64 (uncompressed)" is also valid. You'll receive
  an error message if compressed data is detected.

## Options

### Post Scripts

All script files specified in the Array will have their `post_import(scene)`
method runs. This enables you to change the generated scene automatically
upon each reimport.

The `post_import` methods on each script file will receive the built scene
as an argument and **must** return the changed scene. The scripts are ran
in the order they are in the Array.

### Single TileSet

Save all Tiled tilesets a single Godot resource. If any of your layers uses
more than one tileset image, this is required otherwise it won't be generated
properly.

### Custom properties

Whether or not to save the custom properties as metadata in the nodes and resources.

### Bundle Tilesets

Whether all tilesets used in Tiled should be bundled up into a single TileSet
resource.
This is needed when a layer in the TileMap uses 2 or more Tiled TileSets at the same
time, as Godot only supports one TileSet per TileMap layer.
The advantage to not using this setting is that every Tiled TileSet will only be
imported once and all imported Scenes using the same Tiled TileSet will reference
the same files, however this only works if TileSets are saved using the
`Save Tilesets` option.

### Save Tilesets

Whether or not to save the TileSet resources generated during Tiled map import to the
project directory instead of embedding them directly into the generated Scene file.
Useful to save space if TileSets are shared between different Tiled maps, but only
if they are not bundled using `Bundle Tilesets`.

### Tileset Directory

The absolute path to the directory that TileSets are saved to when `Save Tilesets`
is enabled. The default is inside the `.import` directory that the Tiled maps are
stored inside of, but this can be set to any directory outside of `.import` as well.



## License

[MIT License](LICENSE). Copyright (c) 2016 George Marques.
