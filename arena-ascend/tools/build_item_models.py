# Builds stylized equipment models for Arena Ascend (Blender 4.2 Python).
#   Weapons.glb  30 meshes named "<WeaponId>_<Blade|Staff|Bow>", in studs.
#   Armor.glb    one mesh per armored body part, named "<ArmorId>_<R15 part>",
#                modelled around Roblox's default blocky R15 part sizes.
#   items.json   sizes, grips and offsets the game needs to place them.
# Blender axes: X width, Y depth (front +Y), Z up. Roblox axes: (x, z, -y).
import bpy, bmesh, math, json, sys, os
import numpy as np
from mathutils import Vector

OUT = sys.argv[-1]
os.makedirs(OUT, exist_ok=True)

def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)

def to_roblox(v):
    return (round(v[0], 4), round(v[2], 4), round(-v[1], 4))

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# ------------------------------------------------------------------ palette
CELL = 16

class Palette:
    def __init__(self, name, entries):
        self.keys = list(entries)
        self.grid = 16
        size = CELL * self.grid
        color = np.zeros((size, size, 4), dtype=np.float32); color[..., 3] = 1
        mr = np.zeros((size, size, 4), dtype=np.float32); mr[..., 3] = 1
        for i, key in enumerate(self.keys):
            (r, g, b), metal, rough = entries[key]
            cx, cy = i % self.grid, i // self.grid
            sl = (slice(cy * CELL, cy * CELL + CELL), slice(cx * CELL, cx * CELL + CELL))
            color[sl] = (r, g, b, 1)
            mr[sl] = (0, rough, metal, 1)
        self.material = bpy.data.materials.new(name)
        self.material.use_nodes = True
        nt = self.material.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = self._image(name + "_Color", color, True); tc.interpolation = "Closest"
        tm = nt.nodes.new("ShaderNodeTexImage"); tm.image = self._image(name + "_MetalRough", mr, False); tm.interpolation = "Closest"
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tm.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])

    def _image(self, name, px, srgb):
        size = CELL * self.grid
        img = bpy.data.images.new(name, size, size, alpha=False)
        img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
        img.pixels.foreach_set(px.ravel())
        img.file_format = "PNG"
        img.pack()
        return img

    def uv(self, key):
        i = self.keys.index(key)
        return ((i % self.grid + 0.5) / self.grid, (i // self.grid + 0.5) / self.grid)

SHARED = {
    "gold": (rgb(255, 196, 80), 1, 0.22), "goldDark": (rgb(190, 130, 40), 1, 0.3),
    "steel": (rgb(200, 204, 214), 1, 0.2), "steelDark": (rgb(110, 114, 124), 1, 0.3),
    "iron": (rgb(150, 150, 156), 1, 0.35), "dark": (rgb(30, 30, 36), 0.4, 0.4),
    "leather": (rgb(122, 80, 48), 0, 0.55), "leatherDark": (rgb(72, 46, 28), 0, 0.6),
    "wood": (rgb(150, 104, 62), 0, 0.7), "woodDark": (rgb(96, 64, 38), 0, 0.75),
    "cloth": (rgb(160, 138, 104), 0, 0.85), "rope": (rgb(190, 160, 110), 0, 0.9),
    "white": (rgb(245, 244, 240), 0, 0.4), "marble": (rgb(236, 232, 245), 0, 0.3),
    "ice": (rgb(150, 225, 255), 0.1, 0.08), "ember": (rgb(255, 120, 40), 0, 0.3),
    "storm": (rgb(255, 238, 110), 0.2, 0.2), "void": (rgb(170, 80, 255), 0.1, 0.15),
    "ruin": (rgb(255, 40, 70), 0.1, 0.2), "radiant": (rgb(255, 226, 140), 0.6, 0.1),
    "jade": (rgb(90, 210, 150), 0.1, 0.2), "sapphire": (rgb(70, 130, 255), 0.2, 0.1),
    "emerald": (rgb(60, 200, 110), 0.2, 0.1), "bone": (rgb(230, 222, 200), 0, 0.6),
    "grey": (rgb(120, 124, 132), 0, 0.6), "red": (rgb(160, 30, 40), 0, 0.6),
}

# ------------------------------------------------------------------ geometry helpers
class Maker:
    def __init__(self, pal):
        self.pal = pal
        self.objs = []

    def _link(self, obj):
        bpy.context.scene.collection.objects.link(obj)
        return obj

    def finish(self, obj, key, bevel=0.0, segments=2):
        bpy.context.view_layer.objects.active = obj
        if bevel > 0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel; mod.segments = segments; mod.limit_method = "ANGLE"
            mod.harden_normals = False
            bpy.ops.object.modifier_apply(modifier=mod.name)
        me = obj.data
        if not me.uv_layers:
            me.uv_layers.new()
        u, v = self.pal.uv(key)
        for loop in me.uv_layers.active.data:
            loop.uv = (u, v)
        self.objs.append(obj)
        return obj

    def prism(self, pts, thick, key, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.02, segments=2, y=0.0):
        """Extrudes a 2D outline in the XZ plane by `thick` along Y."""
        bm = bmesh.new()
        verts = [bm.verts.new((x, y - thick / 2, z)) for x, z in pts]
        face = bm.faces.new(verts)
        ext = bmesh.ops.extrude_face_region(bm, geom=[face])
        moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=(0, thick, 0), verts=moved)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("prism"); bm.to_mesh(me); bm.free()
        obj = self._link(bpy.data.objects.new("prism", me))
        obj.location = loc
        obj.rotation_euler = [math.radians(a) for a in rot]
        return self.finish(obj, key, min(bevel, thick * 0.4), segments)

    def box(self, key, center, size, bevel=0.02, rot=(0, 0, 0), segments=2):
        bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=[math.radians(a) for a in rot])
        obj = bpy.context.active_object
        obj.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return self.finish(obj, key, min(bevel, min(size) * 0.45), segments)

    def cyl(self, key, center, r, depth, rot=(0, 0, 0), verts=12, bevel=0.01):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=center,
                                            rotation=[math.radians(a) for a in rot])
        return self.finish(bpy.context.active_object, key, min(bevel, r * 0.4, depth * 0.4))

    def cone(self, key, center, r1, r2, depth, rot=(0, 0, 0), verts=8):
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=center,
                                        rotation=[math.radians(a) for a in rot])
        return self.finish(bpy.context.active_object, key)

    def ball(self, key, center, r, scale=(1, 1, 1), seg=10):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(4, seg // 2), radius=r, location=center)
        obj = bpy.context.active_object
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return self.finish(obj, key)

    def gem(self, key, center, r, scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=center)
        obj = bpy.context.active_object
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return self.finish(obj, key)

    def torus(self, key, center, R, r, rot=(0, 0, 0), seg=20):
        bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=6,
                                         location=center, rotation=[math.radians(a) for a in rot])
        return self.finish(bpy.context.active_object, key)

    def strip(self, key, p0, p1, width, thick):
        """A flat bar between two XZ points, poking through both faces of a blade."""
        (x0, z0), (x1, z1) = p0, p1
        length = math.hypot(x1 - x0, z1 - z0)
        angle = math.degrees(math.atan2(x1 - x0, z1 - z0))
        return self.box(key, ((x0 + x1) / 2, 0, (z0 + z1) / 2), (width, thick, length), bevel=0.006, rot=(0, angle, 0))

    def join(self, name):
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objs[0]
        if len(self.objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.active_object
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.name = name; obj.data.name = name
        obj.data.materials.clear(); obj.data.materials.append(self.pal.material)
        for poly in obj.data.polygons:
            poly.use_smooth = False
        self.objs = []
        return obj

def mirror_x(pts):
    return [(-x, z) for x, z in reversed(pts)]

# ------------------------------------------------------------------ weapon data (mirrors Shared/Items.lua)
WEAPONS = [
    # id, blade rgb, hilt rgb, glow rgb|None, length, width, blade finish (metal, rough), theme
    ("WoodenSword", rgb(160, 116, 72), rgb(92, 64, 40), None, 3.0, 0.5, (0, 0.7), "wood"),
    ("IronBlade", rgb(170, 174, 182), rgb(60, 60, 66), None, 3.2, 0.5, (1, 0.3), "iron"),
    ("SteelLongsword", rgb(205, 212, 222), rgb(40, 60, 110), None, 3.8, 0.5, (1, 0.18), "steel"),
    ("TwinFang", rgb(120, 220, 170), rgb(30, 40, 38), None, 2.0, 0.4, (0.3, 0.15), "fang"),
    ("Frostbite", rgb(170, 225, 255), rgb(40, 70, 110), rgb(120, 210, 255), 4.0, 0.55, (0.1, 0.06), "frost"),
    ("Emberbrand", rgb(60, 36, 30), rgb(120, 40, 20), rgb(255, 110, 40), 4.0, 0.6, (0, 0.55), "ember"),
    ("Stormcaller", rgb(230, 236, 255), rgb(40, 40, 80), rgb(255, 240, 120), 4.4, 0.6, (1, 0.15), "storm"),
    ("Voidreaver", rgb(24, 16, 40), rgb(70, 30, 110), rgb(170, 80, 255), 4.8, 0.7, (0.3, 0.1), "void"),
    ("CrownOfRuin", rgb(40, 8, 12), rgb(200, 150, 40), rgb(255, 40, 70), 5.6, 0.9, (0.2, 0.4), "ruin"),
    ("AscendantBlade", rgb(255, 250, 235), rgb(255, 200, 60), rgb(255, 215, 110), 5.2, 0.75, (0.5, 0.12), "radiant"),
]
THEME_GLOW = {"frost": "ice", "ember": "ember", "storm": "storm", "void": "void", "ruin": "ruin", "radiant": "radiant",
              "fang": "jade", "steel": "sapphire", "iron": "steelDark", "wood": "woodDark"}
THEME_METAL = {"wood": "woodDark", "iron": "steelDark", "steel": "steel", "fang": "dark", "frost": "steel",
               "ember": "dark", "storm": "gold", "void": "dark", "ruin": "gold", "radiant": "gold"}

def weapon_palette():
    entries = dict(SHARED)
    for wid, blade, hilt, glow, *_ in WEAPONS:
        finish = next(w for w in WEAPONS if w[0] == wid)[6]
        entries[wid + "_blade"] = (blade, finish[0], finish[1])
        entries[wid + "_hilt"] = (hilt, 0.3, 0.5)
    return Palette("Weapons", entries)

# ---- blade ------------------------------------------------------------------
def blade_outline(theme, L, w, z0):
    h = w / 2
    if theme == "wood":
        pts = [(h, z0), (h, z0 + L - h)]
        pts += [(h * math.cos(a), z0 + L - h + h * math.sin(a)) for a in [math.pi * i / 8 for i in range(1, 8)]]
        return pts + [(-h, z0 + L - h), (-h, z0)]
    if theme == "fang":
        right, left = [], []
        for i in range(13):
            t = i / 12
            cx = 0.35 * t * t
            half = h * (1 - 0.85 * t)
            right.append((cx + half, z0 + L * t)); left.append((cx - half, z0 + L * t))
        return right + [(0.35 + 0.02, z0 + L + 0.12)] + list(reversed(left))
    if theme == "frost":
        right = [(h, z0)]
        for i in range(1, 7):
            z = z0 + L * i / 7.5
            right += [(h * 1.25, z - 0.12), (h, z)]
        right += [(h * 0.9, z0 + L * 0.88), (0, z0 + L)]
        return right + mirror_x(right)[1:-1] + [(-h, z0)]
    if theme == "ember":
        right = [(h * (1 + 0.14 * math.sin(i * 1.3)), z0 + L * 0.82 * i / 10) for i in range(11)]
        return right + [(0, z0 + L)] + mirror_x(right)
    if theme == "void":
        right = [(h, z0), (h * 1.2, z0 + L * 0.6), (h * 0.9, z0 + L * 0.85), (0, z0 + L)]
        left = [(-h * 0.7, z0 + L * 0.8), (-h * 1.5, z0 + L * 0.7), (-h * 0.9, z0 + L * 0.62), (-h, z0)]
        return right + left
    if theme == "ruin":
        right = [(h * 0.8, z0), (h * 0.8, z0 + 0.35), (h, z0 + 0.45), (h, z0 + L * 0.85), (0, z0 + L)]
        return right + mirror_x(right)
    if theme == "radiant":
        right = [(h * 0.8, z0), (h * 1.15, z0 + L * 0.55), (h * 0.9, z0 + L * 0.82), (0, z0 + L)]
        return right + mirror_x(right)
    right = [(h, z0), (h, z0 + L - w * 1.2), (0, z0 + L)]  # iron, steel, storm
    return right + mirror_x(right)[1:]

def build_blade(m, wid, blade_key, hilt_key, theme, L, w):
    glow = THEME_GLOW[theme]
    metal = THEME_METAL[theme]
    great = theme == "ruin"
    grip_len = 1.5 if great else 1.1
    thick = 0.14 if theme != "ruin" else 0.18
    z_guard = 0.0
    # blade
    m.prism(blade_outline(theme, L, w, z_guard + 0.1), thick, blade_key, bevel=0.035)
    top = z_guard + 0.1 + L
    # blade details
    if theme == "iron":
        m.strip("steelDark", (0, 0.35), (0, L * 0.65), w * 0.18, thick + 0.012)
    elif theme == "steel":
        m.strip("steel", (0, 0.3), (0, L * 0.8), w * 0.1, thick + 0.016)
    elif theme == "frost":
        m.strip(glow, (0, 0.3), (0, L * 0.85), w * 0.16, thick + 0.012)
    elif theme == "ember":
        for (a, b) in [((0, 0.3), (0.06, 1.2)), ((0.06, 1.2), (-0.08, 2.1)), ((-0.08, 2.1), (0.04, 3.0)),
                       ((0.06, 1.2), (0.2, 1.6)), ((-0.08, 2.1), (-0.2, 2.5))]:
            m.strip(glow, a, b, 0.06, thick + 0.012)
    elif theme == "storm":
        zz = [(0, 0.4), (0.12, 1.2), (-0.1, 1.9), (0.1, 2.7), (-0.06, 3.4)]
        for a, b in zip(zz, zz[1:]):
            m.strip(glow, a, b, 0.08, thick + 0.012)
    elif theme == "void":
        m.prism(blade_outline(theme, L * 0.9, w * 0.6, 0.2), thick + 0.02, glow, bevel=0.01)
    elif theme == "ruin":
        for i in range(5):
            z = 0.8 + i * 0.85
            m.box(glow, (0, 0, z), (0.16, thick + 0.012, 0.3), bevel=0.01)
            m.box(glow, (0, 0, z + 0.2), (0.3, thick + 0.012, 0.06), bevel=0.01)
    elif theme == "radiant":
        m.strip("gold", (0, 0.3), (0, L * 0.85), w * 0.14, thick + 0.016)
    # guard
    gw = w * 2.6
    if theme in ("wood", "iron"):
        m.box(hilt_key if theme == "wood" else metal, (0, 0, z_guard), (gw, 0.24, 0.18), bevel=0.04)
        if theme == "iron":
            for sx in (-gw / 2, gw / 2):
                m.ball(metal, (sx, 0, z_guard), 0.1)
    elif theme == "steel":
        right = [(0, -0.09), (gw * 0.4, -0.09), (gw * 0.55, 0.12), (gw * 0.5, 0.16), (gw * 0.35, 0.07), (0, 0.09)]
        m.prism(right + mirror_x(right)[1:-1], 0.24, "steel", loc=(0, 0, z_guard), bevel=0.03)
        m.gem("sapphire", (0, 0.13, z_guard), 0.07)
    elif theme == "fang":
        m.box("dark", (0, 0, z_guard), (gw * 0.7, 0.22, 0.14), bevel=0.03)
        for sx in (-1, 1):
            m.cone("bone", (sx * gw * 0.42, 0, z_guard - 0.12), 0.07, 0.0, 0.3, rot=(0, sx * -35, 0), verts=6)
        # the second "twin" fang along the blade
        m.prism([(0.08, 0.15), (0.3, 0.3), (0.24, 0.9), (0.12, 0.35)], 0.1, blade_key, loc=(-0.02, 0, z_guard), bevel=0.02)
    elif theme == "frost":
        m.box(metal, (0, 0, z_guard), (gw * 0.8, 0.26, 0.16), bevel=0.03)
        for sx in (-1, 1):
            m.cone("ice", (sx * gw * 0.5, 0, z_guard + 0.08), 0.1, 0.0, 0.45, rot=(0, sx * 55, 0), verts=5)
        m.gem("ice", (0, 0.14, z_guard), 0.09)
    elif theme == "ember":
        right = [(0, -0.1), (gw * 0.5, -0.1), (gw * 0.55, 0.25), (gw * 0.4, 0.06), (gw * 0.32, 0.3), (gw * 0.2, 0.08), (0, 0.12)]
        m.prism(right + mirror_x(right)[1:-1], 0.26, hilt_key, loc=(0, 0, z_guard), bevel=0.025)
        m.gem("ember", (0, 0.15, z_guard), 0.09)
    elif theme in ("storm", "radiant"):
        span = 1.2 if theme == "storm" else 1.45
        for sx in (-1, 1):
            feathers = [(0.1, -0.1), (span * 0.5, 0.0), (span * 0.95, 0.35), (span * 0.8, 0.3), (span * 0.85, 0.5),
                        (span * 0.6, 0.35), (span * 0.6, 0.52), (span * 0.35, 0.3), (0.1, 0.14)]
            pts = feathers if sx > 0 else mirror_x(feathers)
            m.prism(pts, 0.2, "gold", loc=(0, 0, z_guard - 0.05), bevel=0.02)
        m.gem("storm" if theme == "storm" else "radiant", (0, 0.13, z_guard + 0.02), 0.11)
        if theme == "radiant":
            m.torus("radiant", (0, 0, z_guard + 0.55), w * 0.9, 0.035, rot=(0, 0, 0))
    elif theme == "void":
        right = [(0, -0.1), (gw * 0.45, -0.1), (gw * 0.65, -0.35), (gw * 0.55, 0.05), (gw * 0.7, 0.35), (gw * 0.3, 0.1), (0, 0.12)]
        m.prism(right + mirror_x(right)[1:-1], 0.24, hilt_key, loc=(0, 0, z_guard), bevel=0.02)
        m.gem("void", (0, 0.14, z_guard), 0.1)
    elif theme == "ruin":
        band = [(-gw * 0.55, -0.12), (gw * 0.55, -0.12), (gw * 0.55, 0.12), (-gw * 0.55, 0.12)]
        m.prism(band, 0.3, "gold", loc=(0, 0, z_guard), bevel=0.03)
        for i, sx in enumerate((-0.5, -0.25, 0, 0.25, 0.5)):
            hgt = 0.55 if sx == 0 else (0.4 if abs(sx) < 0.3 else 0.3)
            m.prism([(-0.1, 0), (0.1, 0), (0, hgt)], 0.2, "gold", loc=(sx * gw, 0, z_guard + 0.1), bevel=0.02)
            m.gem("ruin", (sx * gw, 0.14, z_guard), 0.06)
    # grip
    grip_center = z_guard - 0.09 - grip_len / 2
    m.cyl(hilt_key, (0, 0, grip_center), 0.12, grip_len, verts=10)
    for i in range(4 if not great else 5):
        z = z_guard - 0.2 - i * (grip_len - 0.2) / (3 if not great else 4)
        m.cyl(metal if theme not in ("wood",) else "leatherDark", (0, 0, z), 0.135, 0.05, verts=10)
    # pommel
    zp = z_guard - 0.09 - grip_len - 0.08
    if theme in ("wood", "iron", "fang"):
        m.ball(metal if theme != "wood" else hilt_key, (0, 0, zp), 0.15)
    elif theme in ("frost", "void", "ruin", "ember"):
        m.gem(glow, (0, 0, zp - 0.04), 0.16, scale=(1, 1, 1.3))
    else:
        m.ball("gold" if theme != "steel" else "steel", (0, 0, zp), 0.15)
        m.gem(glow, (0, 0, zp - 0.16), 0.08)
    return {"grip": (0, 0, grip_center), "tip": (0, 0, top), "base": (0, 0, z_guard + 0.15)}

# ---- staff ------------------------------------------------------------------
def build_staff(m, wid, blade_key, hilt_key, theme, L, w):
    glow = THEME_GLOW[theme]
    metal = THEME_METAL[theme]
    length = 3.4 + L * 0.4
    top = length
    shaft_key = hilt_key if theme not in ("iron",) else "iron"
    m.cone(shaft_key, (0, 0, length * 0.43), 0.1, 0.13, length * 0.86, verts=10)
    m.cone(metal, (0, 0, 0.08), 0.06, 0.12, 0.16, verts=8)
    for z in (length * 0.3, length * 0.46, length * 0.8):
        m.cyl("gold" if theme in ("storm", "ruin", "radiant") else ("leatherDark" if theme == "wood" else metal),
              (0, 0, z), 0.15, 0.06, verts=10)
    h = length * 0.86
    if theme == "wood":
        m.ball(hilt_key, (0, 0, h + 0.18), 0.24)
        m.prism([(0, 0), (0.25, 0.15), (0.3, 0.4), (0.1, 0.25)], 0.05, "emerald", loc=(0.08, 0, h + 0.1), bevel=0.01)
        top = h + 0.42
    elif theme == "iron":
        m.box("iron", (0, 0, h + 0.2), (0.36, 0.36, 0.4), bevel=0.05)
        m.box("steelDark", (0, 0, h + 0.2), (0.4, 0.4, 0.1), bevel=0.02)
        top = h + 0.4
    elif theme == "steel":
        m.torus("steel", (0, 0, h + 0.38), 0.32, 0.05, rot=(90, 0, 0))
        m.ball("sapphire", (0, 0, h + 0.38), 0.2)
        top = h + 0.72
    elif theme == "fang":
        for sx in (-1, 1):
            curve = [(sx * 0.08, 0), (sx * 0.3, 0.2), (sx * 0.32, 0.5), (sx * 0.12, 0.72), (sx * 0.22, 0.46), (sx * 0.2, 0.2)]
            m.prism(curve if sx > 0 else list(reversed(curve)), 0.08, "bone", loc=(0, 0, h), bevel=0.015)
        m.ball("jade", (0, 0, h + 0.35), 0.17)
        top = h + 0.75
    elif theme == "frost":
        for ang, hgt, off in ((0, 0.9, 0), (-28, 0.6, -0.14), (28, 0.6, 0.14), (0, 0.5, 0)):
            m.cone("ice", (off, 0, h + hgt / 2 + 0.05), 0.12, 0.0, hgt, rot=(0, ang, 0), verts=6)
            m.cone("ice", (off, 0, h + 0.05), 0.0, 0.12, 0.16, rot=(0, ang, 0), verts=6)
        top = h + 0.95
    elif theme == "ember":
        for sx in (-1, 0, 1):
            m.prism([(-0.09, 0), (0.09, 0), (0.04, 0.35), (0.1, 0.5), (0, 0.75), (-0.06, 0.45)], 0.1,
                    hilt_key, loc=(sx * 0.2, 0, h), rot=(0, sx * -20, 0), bevel=0.015)
        m.ball("ember", (0, 0, h + 0.3), 0.18)
        top = h + 0.8
    elif theme == "storm":
        for sx in (-1, 1):
            wing = [(0.05, 0), (0.5, 0.25), (0.6, 0.6), (0.4, 0.45), (0.38, 0.62), (0.2, 0.4), (0.05, 0.3)]
            m.prism(wing if sx > 0 else mirror_x(wing), 0.08, "gold", loc=(0, 0, h + 0.05), bevel=0.015)
        m.ball("storm", (0, 0, h + 0.4), 0.18)
        zz = [(0, 0.6), (0.1, 0.78), (-0.06, 0.9), (0.05, 1.05)]
        for a, b in zip(zz, zz[1:]):
            m.strip("storm", (a[0], h + a[1]), (b[0], h + b[1]), 0.07, 0.07)
        top = h + 1.08
    elif theme == "void":
        arc = [(0.6 * math.sin(a), 0.6 - 0.6 * math.cos(a)) for a in [i * math.pi / 10 - math.pi / 2 for i in range(11)]]
        inner = [(0.45 * math.sin(a), 0.6 - 0.45 * math.cos(a)) for a in [i * math.pi / 10 - math.pi / 2 for i in range(11)]]
        crescent = [(x, z) for x, z in arc] + list(reversed([(x, z) for x, z in inner]))
        m.prism(crescent, 0.1, hilt_key, loc=(0, 0, h + 0.02), bevel=0.015)
        m.ball("void", (0, 0, h + 0.4), 0.2)
        top = h + 0.65
    elif theme == "ruin":
        m.cyl("gold", (0, 0, h + 0.08), 0.26, 0.16, verts=12)
        for i in range(5):
            ang = i / 5 * math.pi * 2
            m.cone("gold", (math.cos(ang) * 0.22, math.sin(ang) * 0.22, h + 0.35), 0.06, 0.0, 0.4, verts=5)
        m.gem("ruin", (0, 0, h + 0.45), 0.24, scale=(1, 1, 1.3))
        top = h + 0.8
    else:  # radiant
        for sx in (-1, 1):
            wing = [(0.05, 0), (0.6, 0.2), (0.75, 0.6), (0.55, 0.48), (0.55, 0.7), (0.3, 0.5), (0.25, 0.65), (0.05, 0.35)]
            m.prism(wing if sx > 0 else mirror_x(wing), 0.08, "gold", loc=(0, 0, h + 0.05), bevel=0.015)
        m.torus("radiant", (0, 0, h + 0.5), 0.34, 0.035, rot=(90, 0, 0))
        m.gem("white", (0, 0, h + 0.5), 0.2)
        top = h + 0.9
    return {"grip": (0, 0, length * 0.38), "tip": (0, 0, top), "base": (0, 0, h)}

# ---- bow --------------------------------------------------------------------
def build_bow(m, wid, blade_key, hilt_key, theme, L, w):
    glow = THEME_GLOW[theme]
    metal = THEME_METAL[theme]
    half = 1.7 + L * 0.12
    k = 0.55
    right, left = [], []
    for i in range(25):
        z = -half + 2 * half * i / 24
        t = abs(z) / half
        x = -k * (1 - t * t)  # grip bows back toward -X; tips at x = 0
        thick = 0.2 - 0.1 * t
        right.append((x + thick / 2, z)); left.append((x - thick / 2, z))
    limb_key = blade_key if theme not in ("iron",) else "wood"
    m.prism(right + list(reversed(left)), 0.16, limb_key, bevel=0.02)
    # string
    m.box("white" if theme not in ("frost", "void", "ruin", "storm", "radiant", "ember") else glow,
          (0.02, 0, 0), (0.03, 0.03, 2 * half), bevel=0.0)
    # grip wrap + arrow rest
    m.box(hilt_key, (-k, 0, 0), (0.26, 0.24, 0.7), bevel=0.05)
    for z in (-0.3, -0.1, 0.1, 0.3):
        m.box("leatherDark" if theme in ("wood", "iron") else metal, (-k, 0, z), (0.28, 0.26, 0.04), bevel=0.01)
    m.box(metal, (-k + 0.16, 0, 0.4), (0.08, 0.1, 0.06), bevel=0.01)
    tips = [(0, half), (0, -half)]
    if theme in ("iron", "steel"):
        for x, z in tips:
            m.box(metal, (x - 0.04, 0, z + (0.08 if z > 0 else -0.08)), (0.16, 0.18, 0.2), bevel=0.03)
    elif theme == "fang":
        for x, z in tips:
            s = 1 if z > 0 else -1
            m.cone("bone", (x + 0.1, 0, z + s * 0.12), 0.07, 0.0, 0.34, rot=(0, 30 * s, 0) if s > 0 else (0, 150, 0), verts=6)
    elif theme == "frost":
        for x, z in tips:
            s = 1 if z > 0 else -1
            m.cone("ice", (x, 0, z + s * 0.2), 0.09, 0.0, 0.5, rot=(0, 0, 0) if s > 0 else (180, 0, 0), verts=6)
        m.gem("ice", (-k - 0.14, 0, 0), 0.1)
    elif theme == "ember":
        for s in (-1, 1):
            m.strip("ember", (-k * 0.75, s * 0.5), (-k * 0.2, s * 1.2), 0.05, 0.18)
        m.gem("ember", (-k - 0.14, 0, 0), 0.1)
    elif theme in ("storm", "radiant"):
        for s in (-1, 1):
            wing = [(0, 0), (-0.55, s * 0.25), (-0.8, s * 0.65), (-0.55, s * 0.5), (-0.6, s * 0.75), (-0.3, s * 0.45), (-0.05, s * 0.3)]
            m.prism(wing if s < 0 else list(reversed(wing)), 0.08, "gold", loc=(-k - 0.05, 0, s * 0.3), bevel=0.012)
        m.gem("storm" if theme == "storm" else "radiant", (-k - 0.15, 0, 0), 0.11)
        if theme == "radiant":
            m.torus("radiant", (-k, 0, 0), 0.3, 0.03, rot=(0, 90, 0))
    elif theme == "void":
        for s in (-1, 1):
            for i in range(3):
                z = s * (0.55 + i * 0.4)
                t = abs(z) / half
                x = -k * (1 - t * t)
                m.prism([(0, -0.1), (0, 0.1), (-0.3, 0.02 * s)], 0.06, "void", loc=(x - 0.06, 0, z), bevel=0.01)
        m.gem("void", (-k - 0.14, 0, 0), 0.1)
    elif theme == "ruin":
        for i, dz in enumerate((-0.25, 0, 0.25)):
            m.cone("gold", (-k - 0.18, 0, dz), 0.06, 0.0, 0.3, rot=(0, -90, 0), verts=5)
        m.gem("ruin", (-k - 0.14, 0.14, 0), 0.1)
        for x, z in tips:
            m.gem("ruin", (x, 0, z + (0.08 if z > 0 else -0.08)), 0.09)
    return {"grip": (-k, 0, 0), "tip": (0, 0, half), "base": (-k, 0, 0)}

BUILDERS = {"Blade": build_blade, "Staff": build_staff, "Bow": build_bow}

def bbox(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx

def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, use_selection=True,
                              export_materials="EXPORT", export_animations=False)

def build_weapons():
    reset()
    pal = weapon_palette()
    rigs, objs = {}, []
    for row, style in enumerate(("Blade", "Staff", "Bow")):
        for col, (wid, blade, hilt, glow, L, w, finish, theme) in enumerate(WEAPONS):
            m = Maker(pal)
            marks = BUILDERS[style](m, wid, wid + "_blade", wid + "_hilt", theme, L, w)
            obj = m.join(f"{wid}_{style}")
            mn, mx = bbox(obj)
            centre = (mn + mx) / 2
            size = mx - mn
            rigs[obj.name] = {
                "Size": to_roblox((size.x, -size.y, size.z)),
                "Grip": to_roblox(Vector(marks["grip"]) - centre),
                "Tip": to_roblox(Vector(marks["tip"]) - centre),
                "Base": to_roblox(Vector(marks["base"]) - centre),
                "Tris": sum(len(p.vertices) - 2 for p in obj.data.polygons),
            }
            # lay out for the preview render / tidy import
            obj.location = (col * 2.0, 0, (0, -9.2, -12.8)[row])
            objs.append(obj)
    export(objs, os.path.join(OUT, "Weapons.glb"))
    return rigs, objs

# ------------------------------------------------------------------ armor
# Roblox default blocky R15 part sizes, in Blender axes (x, depth, height).
REF = {
    "UpperTorso": (2, 1, 1.6), "LowerTorso": (2, 1, 0.4), "Head": (1.2, 1.2, 1.2),
    "LeftUpperArm": (1, 1, 1.169), "RightUpperArm": (1, 1, 1.169),
    "LeftLowerArm": (1, 1, 1.052), "RightLowerArm": (1, 1, 1.052),
    "LeftHand": (1, 1, 0.3), "RightHand": (1, 1, 0.3),
    "LeftUpperLeg": (1, 1, 1.217), "RightUpperLeg": (1, 1, 1.217),
    "LeftLowerLeg": (1, 1, 1.193), "RightLowerLeg": (1, 1, 1.193),
    "LeftFoot": (1, 1, 0.3), "RightFoot": (1, 1, 0.3),
}
# Where each part's centre sits on a standing default body (feet on z=0).
BODY = {
    "LeftFoot": (-0.5, 0, 0.15), "RightFoot": (0.5, 0, 0.15),
    "LeftLowerLeg": (-0.5, 0, 0.8965), "RightLowerLeg": (0.5, 0, 0.8965),
    "LeftUpperLeg": (-0.5, 0, 2.1015), "RightUpperLeg": (0.5, 0, 2.1015),
    "LowerTorso": (0, 0, 2.91), "UpperTorso": (0, 0, 3.91), "Head": (0, 0, 5.31),
    "LeftUpperArm": (-1.5, 0, 4.1255), "RightUpperArm": (1.5, 0, 4.1255),
    "LeftLowerArm": (-1.5, 0, 3.015), "RightLowerArm": (1.5, 0, 3.015),
    "LeftHand": (-1.5, 0, 2.339), "RightHand": (1.5, 0, 2.339),
}

ARMOR = [
    ("ClothTunic", rgb(150, 130, 100), None, "cloth"),
    ("LeatherGuard", rgb(120, 78, 46), None, "leather"),
    ("Chainmail", rgb(150, 156, 166), None, "chain"),
    ("KnightPlate", rgb(196, 202, 214), rgb(76, 156, 255), "plate"),
    ("Dragonscale", rgb(40, 110, 70), rgb(255, 176, 48), "dragon"),
    ("CelestialAegis", rgb(245, 240, 255), rgb(255, 215, 110), "celestial"),
]

def armor_palette():
    entries = dict(SHARED)
    finishes = {"cloth": (0, 0.85), "leather": (0, 0.55), "chain": (1, 0.45), "plate": (1, 0.18),
                "dragon": (0.3, 0.35), "celestial": (0.2, 0.2)}
    for aid, color, trim, style in ARMOR:
        entries[aid + "_main"] = (color, *finishes[style])
        if trim:
            entries[aid + "_trim"] = (trim, 1 if style != "celestial" else 0.9, 0.2)
    return Palette("Armor", entries)

def sides():
    return (("Left", -1), ("Right", 1))

def armor_pieces(m, aid, style):
    """Returns {part: [objects]} built around each reference part's centre."""
    main = aid + "_main"
    trim = aid + "_trim" if style in ("plate", "dragon", "celestial") else ("gold" if style == "leather" else "steelDark")
    pieces = {}

    def piece(part, fn):
        start = len(m.objs)
        fn()
        pieces.setdefault(part, []).extend(m.objs[start:])

    if style == "cloth":
        piece("LowerTorso", lambda: (m.box("rope", (0, 0, 0.02), (2.08, 1.08, 0.16), bevel=0.05),
                                     m.box("rope", (0.45, 0.56, -0.12), (0.12, 0.08, 0.35), bevel=0.03)))
        for side, s in sides():
            piece(side + "LowerArm", lambda s=s: (m.box("cloth", (0, 0, -0.3), (1.06, 1.06, 0.18), bevel=0.04),
                                                 m.box("cloth", (0, 0, -0.08), (1.06, 1.06, 0.14), bevel=0.04)))
        return pieces

    # --- chest
    def chest():
        if style == "leather":
            m.box(main, (0, 0.03, 0.02), (2.08, 1.1, 1.5), bevel=0.08)
            m.box("leatherDark", (0, 0.57, 0.05), (0.16, 0.04, 1.62), bevel=0.02, rot=(0, 35, 0))
            m.box("gold", (0.22, 0.58, 0.32), (0.16, 0.05, 0.16), bevel=0.02)
        elif style == "chain":
            m.box(main, (0, 0, 0.03), (2.1, 1.1, 1.6), bevel=0.06)
            for i in range(7):
                m.box("steelDark", (0, 0, -0.66 + i * 0.2), (2.12, 1.12, 0.03), bevel=0.01)
            m.box("steel", (0, 0, 0.76), (1.2, 1.14, 0.16), bevel=0.05)
        elif style == "plate":
            m.box(main, (0, 0.02, 0.05), (2.14, 1.14, 1.56), bevel=0.1)
            m.box(main, (0, 0.6, 0.12), (1.3, 0.1, 1.1), bevel=0.06)
            m.box(trim, (0, 0.66, 0.12), (0.12, 0.05, 1.1), bevel=0.02)
            m.box(trim, (0, 0, -0.66), (2.18, 1.18, 0.1), bevel=0.03)
            m.box(trim, (0, 0, 0.78), (1.3, 1.18, 0.12), bevel=0.03)
            m.gem("sapphire", (0, 0.68, 0.45), 0.12)
        elif style == "dragon":
            m.box(main, (0, 0.02, 0.05), (2.12, 1.12, 1.56), bevel=0.08)
            for row in range(4):
                for col in range(6):
                    x = -0.75 + col * 0.3 + (0.15 if row % 2 else 0)
                    if abs(x) > 0.9:
                        continue
                    for face in (1, -1):
                        m.box(main, (x, face * 0.585, 0.45 - row * 0.3), (0.28, 0.06, 0.24), bevel=0.04,
                              rot=(face * 18, 0, 0), segments=1)
            m.box(trim, (0, 0, -0.66), (2.16, 1.16, 0.1), bevel=0.03)
            m.box(trim, (0, 0, 0.78), (1.3, 1.16, 0.12), bevel=0.03)
            m.gem("ember", (0, 0.64, 0.62), 0.12, scale=(1, 0.6, 1.3))
        elif style == "celestial":
            m.box("marble", (0, 0.02, 0.05), (2.14, 1.14, 1.56), bevel=0.1)
            m.box(trim, (0, 0.6, 0.1), (1.2, 0.08, 0.1), bevel=0.02)
            m.box(trim, (0, 0.6, 0.1), (0.1, 0.08, 1.2), bevel=0.02)
            m.box(trim, (0, 0, -0.66), (2.18, 1.18, 0.1), bevel=0.03)
            m.box(trim, (0, 0, 0.78), (1.3, 1.18, 0.12), bevel=0.03)
            m.gem("radiant", (0, 0.66, 0.1), 0.17)
            m.torus(trim, (0, 0.64, 0.1), 0.24, 0.035, rot=(90, 0, 0))
    piece("UpperTorso", chest)

    # --- waist
    def waist():
        belt = "leatherDark" if style in ("leather", "chain") else trim
        m.box(belt, (0, 0, 0.02), (2.1, 1.1, 0.24), bevel=0.05)
        m.box("gold" if style != "chain" else "steel", (0, 0.56, 0.02), (0.3, 0.06, 0.2), bevel=0.03)
        if style == "leather":
            m.box("leather", (0.62, 0.52, -0.16), (0.36, 0.2, 0.3), bevel=0.05)
        elif style == "chain":
            m.box(main, (0, 0, -0.32), (2.12, 1.12, 0.5), bevel=0.05)
        else:
            plate = "marble" if style == "celestial" else main
            for x, y, w, d in ((-0.5, 0.52, 0.8, 0.08), (0.5, 0.52, 0.8, 0.08), (0, -0.52, 1.8, 0.08),
                               (-1.02, 0, 0.08, 0.8), (1.02, 0, 0.08, 0.8)):
                m.box(plate, (x, y, -0.4), (w, d, 0.6), bevel=0.03)
                m.box(trim, (x, y * 1.02, -0.68), (w + 0.02, d + 0.02, 0.07), bevel=0.02)
    piece("LowerTorso", waist)

    for side, s in sides():
        def shoulder(s=s):
            if style == "leather":
                m.box(main, (s * 0.06, 0, 0.5), (1.24, 1.2, 0.34), bevel=0.08, rot=(0, s * 12, 0))
            elif style == "chain":
                m.box(main, (s * 0.04, 0, 0.42), (1.14, 1.14, 0.46), bevel=0.06)
                m.box("steel", (s * 0.06, 0, 0.62), (1.22, 1.2, 0.14), bevel=0.04, rot=(0, s * 10, 0))
            else:
                plate = "marble" if style == "celestial" else main
                for i, (z, sz) in enumerate(((0.62, 1.42), (0.4, 1.3), (0.2, 1.2))):
                    m.box(plate, (s * (0.12 + i * 0.03), 0, z), (sz, sz * 0.95, 0.24), bevel=0.06, rot=(0, s * 18, 0))
                    m.box(trim, (s * (0.12 + i * 0.03), 0, z - 0.11), (sz + 0.02, sz * 0.95 + 0.02, 0.05), bevel=0.015,
                          rot=(0, s * 18, 0))
                if style == "dragon":
                    for dx in (-0.25, 0.1, 0.4):
                        m.cone("bone", (s * (0.3 + dx * 0.6), dx * 0.3, 0.9), 0.1, 0.0, 0.45, rot=(0, s * 25, 0), verts=6)
                if style == "celestial":
                    for i, ang in enumerate((10, 35, 60)):
                        feather = [(0, -0.1), (1.0 - i * 0.15, -0.05), (1.1 - i * 0.15, 0.05), (0, 0.1)]
                        pts = feather if s > 0 else mirror_x(feather)
                        m.prism(pts, 0.06, trim if i != 1 else "white", loc=(s * 0.45, -0.35, 0.7),
                                rot=(0, -s * ang, 0), bevel=0.015)
        piece(side + "UpperArm", shoulder)

        def bracer(s=s):
            key = "leather" if style == "leather" else ("steel" if style == "chain" else ("marble" if style == "celestial" else main))
            m.box(key, (0, 0, -0.14), (1.1, 1.1, 0.66), bevel=0.06)
            m.box(trim if style != "leather" else "leatherDark", (0, 0, 0.18), (1.14, 1.14, 0.08), bevel=0.02)
            if style == "dragon":
                for dx in (-0.3, 0, 0.3):
                    m.cone("bone", (s * 0.56, dx, -0.1), 0.06, 0.0, 0.28, rot=(0, s * 90, 0), verts=5)
        piece(side + "LowerArm", bracer)

        if style == "dragon":
            piece(side + "Hand", lambda s=s: [m.cone("bone", (dx, 0.35, -0.22), 0.05, 0.0, 0.22, rot=(180, 0, 0), verts=5)
                                             for dx in (-0.3, 0, 0.3)])

        def greave(s=s):
            key = "leather" if style == "leather" else ("steel" if style == "chain" else ("marble" if style == "celestial" else main))
            if style == "leather":
                m.box(key, (0, 0.44, 0.35), (0.7, 0.16, 0.5), bevel=0.06)
                return
            m.box(key, (0, 0, -0.12), (1.1, 1.1, 0.8), bevel=0.06)
            m.box(trim, (0, 0, 0.3), (1.14, 1.14, 0.07), bevel=0.02)
            m.ball(key if style != "celestial" else trim, (0, 0.5, 0.42), 0.26, scale=(1.1, 0.7, 1))
        piece(side + "LowerLeg", greave)

        if style in ("plate", "dragon", "celestial"):
            def boot(s=s):
                key = "marble" if style == "celestial" else main
                m.box(key, (0, 0.05, 0.04), (1.1, 1.18, 0.38), bevel=0.06)
                m.box(trim, (0, 0.05, 0.2), (1.12, 1.2, 0.06), bevel=0.02)
            piece(side + "Foot", boot)
    return pieces

def build_armor():
    reset()
    pal = armor_palette()
    rigs, objs, mannequins = {}, [], []
    for col, (aid, color, trim, style) in enumerate(ARMOR):
        m = Maker(pal)
        pieces = armor_pieces(m, aid, style)
        rigs[aid] = {}
        for part, parts in pieces.items():
            m.objs = parts
            obj = m.join(f"{aid}_{part}")
            mn, mx = bbox(obj)
            centre = (mn + mx) / 2
            size = mx - mn
            rigs[aid][part] = {"Size": to_roblox((size.x, -size.y, size.z)), "Offset": to_roblox(centre),
                               "Tris": sum(len(p.vertices) - 2 for p in obj.data.polygons)}
            # dress a preview mannequin: move the piece onto its part of body #col
            bx, by, bz = BODY[part]
            obj.location = (bx + col * 4.5, by, bz)
            objs.append(obj)
    export(objs, os.path.join(OUT, "Armor.glb"))
    # plain grey mannequins for the preview only (not exported)
    grey = bpy.data.materials.new("mannequin")
    grey.use_nodes = True
    grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.055, 0.07, 1)
    for col in range(len(ARMOR)):
        for part, (bx, by, bz) in BODY.items():
            sx, sy, sz = REF[part]
            bpy.ops.mesh.primitive_cube_add(size=1, location=(bx + col * 4.5, by, bz))
            o = bpy.context.active_object
            o.scale = (sx * 0.98, sy * 0.98, sz * 0.98)
            o.data.materials.append(grey)
    return rigs

# ------------------------------------------------------------------ preview renders
def render(path, cam_loc, cam_rot, ortho, res, suns):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 24; sc.cycles.use_denoising = False
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = True
    world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.7, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = ortho
    cam.location = cam_loc; cam.rotation_euler = [math.radians(a) for a in cam_rot]
    sc.camera = cam
    for rot, energy in suns:
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
        sun.rotation_euler = [math.radians(a) for a in rot]; sun.data.energy = energy
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

weapon_rigs, _ = build_weapons()
render(os.path.join(OUT, "weapons.png"), (9, -30, -4.5), (90, 0, 0), 22, (2000, 2200),
       (((55, 0, -25), 4.0), ((70, 0, 150), 1.2)))
armor_rigs = build_armor()
render(os.path.join(OUT, "armor.png"), (11.25, 30, 6.5), (82, 0, 180), 30, (2400, 860),
       (((-55, 0, 25), 4.0), ((-70, 0, -150), 1.2)))

with open(os.path.join(OUT, "items.json"), "w") as f:
    json.dump({"Weapons": weapon_rigs, "Armor": armor_rigs}, f, indent=1)
worst = max(r["Tris"] for r in weapon_rigs.values())
worst_armor = max(p["Tris"] for a in armor_rigs.values() for p in a.values())
print("BUILT weapons", len(weapon_rigs), "max tris", worst, "| armor pieces",
      sum(len(a) for a in armor_rigs.values()), "max tris", worst_armor)
