# Tiled Map Importer

This is a plugin for [Godot Engine](https://godotengine.org) to import
`TileMap`s and `TileSet`s from the [Tiled Map Editor](http://www.mapeditor.org).

**Note: This is compatible only with Godot 3.0 or later. For Godot 2.x, use the [1.x branch](https://github.com/vnen/godot-tiled-importer/tree/1.x).**

<img src="https://user-images.githubusercontent.com/5599796/35366974-29dd3a98-0163-11e8-844b-fcae103b3aa6.png" width="300">
<img src="https://user-images.githubusercontent.com/5599796/35366991-33a8acf6-0163-11e8-8515-1d457bf68d2b.png" width="300">
<img src="https://user-images.githubusercontent.com/5599796/35366983-2d69967a-0163-11e8-87e1-32a2b26a76e8.png" width="300">
<img src="https://user-images.githubusercontent.com/5599796/35366992-369c0cf0-0163-11e8-8008-b8dad1fb5d7f.png" width="300">

## Installation

Simply download it from Godot Asset Library: https://godotengine.org/asset-library/asset/25.

Alternatively, download or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder.

Then enable the plugin on the Project Settings.

## Features

* Import Tiled file as a Godot scene. Each layer in Tiled is a TileMap in Godot.
* Import TileSets from Tiled standalone tileset files.
* Both `.tmx` (XML) and `.json` formats for maps.
* Both `.tsx` (XML) and `.json` formats for tilesets.
* Support for Base64 encoded map.
* Support for layer compression, both `zlib` and `gzip` are supported.
* Orthogonal, isometric, and staggered (odd-indexed only) maps.
* Import visibility and opacity from layers.
* Import collision/occluder/navigation shapes (based on Tiled object type).
* Custom import options, such as whether to enable UV clip.
* Support for image layers.
* Support for object layers, which are imported as StaticBody2D, Area2D or LightOccluder2D
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

Note that if you are using external tilesets, note that they will also be imported,
which may increase the final export size of your project. To mitigate that, you can
exclude those files from the export or put them in a folder alongside a `.gdignore`
file so they are not even imported.

**Note:** If you have other `.json` files in your project, this plugin will try to
import them and fail. Consider putting those files in a folder alongside a
`.gdignore` file so Godot won't try to import them.

## Caveats on Tiled maps

* Godot TileSets only have on collision shape, so the last found will overwrite
  the others.

* The same goes for navigation/occluder polygons.

* There's no Ellipse shape in Godot. If you use it as a collision object, it
  will be converted to a capsule shape, which may be imprecise. However, if the
  Tiled ellipse is a perfect circle, a CircleShape2D will be used instead.

* Set the type of the object to `area`, `navigation` or `occluder` to use it as such.

* Objects in object layer cannot be set as `navigation`.

* Only polygons can be used as occluder/navigation. For those, you can make a
  polygon or polyline in Tiled. Rectangles will be converted to polygons, but
  ellipses are not accepted.

* Occluder shapes are set as closed if a polygon is used and as open if it is
  a polyline.

* For isometric staggered maps, only odd-indexed is supported. For even-indexed
it would require some extra tricks during import. This may be available in the
future.

## Import system caveats

* If you are embedding images, changing them won't trigger a reimport.

* If you are using external tile sets in Tiled, changing the tile set won't
trigger a reimport.

* Essentially, every change you do that doesn't directly change the source Tiled
map, won't trigger the automatic reimport.

## Options (Maps and TileSets)

There are two import presets: `Default` and `Pixel Art`. The difference is that
the `Pixel Art` preset don't use any flag for the texture, disabling filter,
mipmaps, and repeat.

Because it overrides the image flags, it also embed internal images by default,
otherwise it won't make a difference. If you want to avoid that, use the Default
preset and import your images without flags.

Note that you can set a different default preset on Godot.

### Custom Properties

**Default: `On`**

Whether or not to save the custom properties as metadata in the nodes and resources.

### Tile Metadata

**Default: `Off`**

Whether or not to save the tile metadata into the TileSet resource. It will be set
as a dictionary named `tile_meta` where the key is the tile global id (the same id
used in the Godot TileMap).

### Clip Uv (Map only)

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

The `post_import` method will receive the built scene (or TileSet) and **must**
return the changed scene (or TileSet).

## License

[MIT License](LICENSE). Copyright (c) 2018 George Marques.
