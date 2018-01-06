# Tiled Map Importer

This is a plugin for [Godot Engine](https://godotengine.org) to import
`TileMap`s and `TileSet`s from the [Tiled Map Editor](http://www.mapeditor.org).

**Note: This is compatible only with Godot 3.0 or later. For Godot 2.x, use the [1.x branch](https://github.com/vnen/godot-tiled-importer/tree/1.x).**

## Installation

Simply download it from Godot Asset Library: https://godotengine.org/asset-library/asset/25.

Alternatively, download or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder.

Then enable the plugin on the Project Settings.

## Features

* Import Tiled file as a Godot scene. Each layer in Tiled is a TileMap in Godot.
* Both `.tmx` (XML) and `.json` formats.
* Support for Base64 encoded map.
* Support for layer compression, both `zlib` and `gzip` are supported.
* Orthogonal, isometric, and staggered (odd-indexed only) maps.
* Import visibility and opacity from layers.
* Import collision/occluder/navigation shapes (based on Tiled object type).
* Custom import options, such as whether to embed the resources into the scene.
* Support for image layers
* Support for object layers, which are imported as StaticBody2D or LightOccluder2D
  for shapes (depending on the `type` property) and as Sprite for tiles.
* Support for group layers, which are imported as `Node2D`s.
* Custom properties for maps, layers, tilesets, and objects are imported as
  metadata. Custom properties on tiles can be imported into the TileSet resource.
* Support for post-import script.

## Usage (once the plugin is enabled)

1. Place your maps inside your project.
2. Watch Godot import it automatically.

The map file can be used as if it were a scene, but you can not edit it in Godot.
If you need to make changes, create an inherited scene or instance the map in
another scene.

Whenever you make a change to the map in Tiled, Godot will reimport the scene and
update it in the editor if it's open.

If the file can't be imported, an error message will be generated in the output.
Please check the output if you are having an issue.

**Note:** If you have an external tileset or any other `.json` file in your project,
this plugin will try to import it and fail. Consider putting those files in a folder
alongside a `.gdignore` file so Godot won't try to import them.

## Caveats on Tiled maps

* Godot TileSets only have on collision shape, so the last found will overwrite
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

## Options

There are two import presets: `Default` and `Pixel Art`. The difference is that
the `Pixel Art` preset don't use any flag for the texture, disabling filter,
mipmaps, and repeat. Note that you can set a different default preset on Godot.

### Custom Properties

**Default: `On`**

Whether or not to save the custom properties as metadata in the nodes and resources.

### TIle Metadata

**Default: `Off`**

Whether or not to save the tile metadata into the TileSet resource. It will be set
as a dictionary named `tile_meta` where the key is the tile global id (the same id
used in the Godot TileMap).

### Clip Uv

**Default: `On`**

Enable the Clip Uv (Filter Clip on Sprites) to avoid image bleeding on tiles.

### Image Flags

**Default: `Mipmaps, Repeat, Filter`** (Note: this is set as `Texture.FLAGS_DEFAULT`)

The image flags to apply to all imported TileSet images. This will only work if images
are embedded, otherwise they will use the flags from their own import settings.

### Embed Internal Images

**Default: `Off`**

By default, if an image is inside the project, it won't be reimported. If this option
is enabled, the images will be embedded into the imported scene. This is useful if you
need to use the image somewhere else with different import settings.

### Save Tiled Properties

**Default: `Off`**

Save the regular properties from Tiled inside the objects as metadata. They will be
placed alongside the custom properties.

**Note:** Not *all* properties from the file are saved, only the ones you can see on
Tiled interface.

### Post-import script

**Default: `None`**

The selected script will have it's `post_import(scene)` method run. This
enables you to change the generated scene automatically upon each reimport.

The `post_import` method will receive the built scene and **must** return the
changed scene.

## License

[MIT License](LICENSE). Copyright (c) 2018 George Marques.
