# Texture sources

All textures in this folder are CC0 1.0 (public domain): free for any use, commercial included, no attribution required. See https://www.texturecan.com/terms/ (TextureCan) and https://docs.ambientcg.com/license/ (ambientCG).

| Folder | Source | Original pack | Used maps |
|---|---|---|---|
| `ceiling_tiles/` | TextureCan, "Office Ceiling Tiles (Tiles 0013)" — https://www.texturecan.com/details/131/ | `tiles_0013_1k` | color, normal (OpenGL), roughness, ao |
| `carpet/` | TextureCan, "Blue Office Carpet Texture (Fabric 0009)" — https://www.texturecan.com/details/66/ | `fabric_0009_1k` | color, normal (OpenGL), roughness, ao |
| `manor/earth_moss/` | ambientCG, Ground037 — https://ambientcg.com/view?id=Ground037 | `Ground037_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/earth_dirt/` | ambientCG, Ground042 — https://ambientcg.com/view?id=Ground042 | `Ground042_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/gravel/` | ambientCG, Gravel040 — https://ambientcg.com/view?id=Gravel040 | `Gravel040_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/stone_old/` | ambientCG, Bricks075B — https://ambientcg.com/view?id=Bricks075B | `Bricks075B_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/stone_dressed/` | ambientCG, Bricks076A — https://ambientcg.com/view?id=Bricks076A | `Bricks076A_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/slate/` | ambientCG, RoofingTiles003 — https://ambientcg.com/view?id=RoofingTiles003 | `RoofingTiles003_1K-JPG` | color, normal (OpenGL), roughness |
| `manor/planks/` | ambientCG, Planks023A — https://ambientcg.com/view?id=Planks023A | `Planks023A_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/wood/` | ambientCG, Wood035 — https://ambientcg.com/view?id=Wood035 | `Wood035_1K-JPG` | color, normal (OpenGL), roughness |
| `manor/bark/` | ambientCG, Bark006 — https://ambientcg.com/view?id=Bark006 | `Bark006_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/rock/` | ambientCG, Rock063 — https://ambientcg.com/view?id=Rock063 | `Rock063_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/leaves/` | ambientCG, ScatteredLeaves009 — https://ambientcg.com/view?id=ScatteredLeaves009 | `ScatteredLeaves009_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/plaster_painted/` | ambientCG, PaintedPlaster016 — https://ambientcg.com/view?id=PaintedPlaster016 | `PaintedPlaster016_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/plaster/` | ambientCG, Plaster007 — https://ambientcg.com/view?id=Plaster007 | `Plaster007_1K-JPG` | color, normal (OpenGL), roughness, ao |
| `manor/rust/` | ambientCG, Metal041B — https://ambientcg.com/view?id=Metal041B | `Metal041B_1K-JPG` | color, normal (OpenGL), roughness (metalness left out) |
| `manor/rug/` | ambientCG, Fabric028 — https://ambientcg.com/view?id=Fabric028 | `Fabric028_1K-JPG` | color, normal (OpenGL), roughness |
| `manor/cloth/` | ambientCG, Fabric001 — https://ambientcg.com/view?id=Fabric001 | `Fabric001_1K-JPG` | color, normal (OpenGL), roughness |

The carpet is recoloured from blue to mustard in `src/levels/level_kit.gd` (`CARPET_SHADER`). The manor sets are mapped in world space by `src/levels/level_kit.gd` (`MANOR_EARTH_SHADER`, `MANOR_PBR_SHADER`, `MANOR_WALL_SHADER`: the painted plaster's paint is recoloured as the mansion's wallpaper over wood wainscot), each darkened to its surface's night colour, and laid under the sculpted props' painted colours by `src/fx/sculpt.gd` (`detail`, chosen per prop in `ManorMeshes.DETAIL`); the hedges use the leaf litter set tinted dark green. Import settings: VRAM compressed with mipmaps; the normal maps are imported as normal maps.
