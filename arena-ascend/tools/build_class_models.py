# Builds Roblox R15-rigged class models.
#   Knight: the user's Meshy model, cut into the 15 R15 parts.
#   Ranger / Mage / Rogue / Cleric: generated in the same blocky, shiny style.
# Every model faces +Y with its right hand at +X (Roblox: faces -Z, right +X),
# is split into meshes named after R15 parts, and is skinned 1:1 to an R15 armature.
import bpy, bmesh, math, json, sys, os
import numpy as np
from mathutils import Vector, Matrix

OUT = sys.argv[-2]
KNIGHT_SRC = sys.argv[-1]
os.makedirs(OUT, exist_ok=True)

R15 = ["Head", "UpperTorso", "LowerTorso",
       "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
       "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
# bone -> (parent bone, joint name that places its head)
BONES = {
    "Root": (None, "ground"),
    "HumanoidRootNode": ("Root", "root"),
    "LowerTorso": ("HumanoidRootNode", "root"),
    "UpperTorso": ("LowerTorso", "waist"),
    "Head": ("UpperTorso", "neck"),
    "LeftUpperArm": ("UpperTorso", "LeftShoulder"), "LeftLowerArm": ("LeftUpperArm", "LeftElbow"), "LeftHand": ("LeftLowerArm", "LeftWrist"),
    "RightUpperArm": ("UpperTorso", "RightShoulder"), "RightLowerArm": ("RightUpperArm", "RightElbow"), "RightHand": ("RightLowerArm", "RightWrist"),
    "LeftUpperLeg": ("LowerTorso", "LeftHip"), "LeftLowerLeg": ("LeftUpperLeg", "LeftKnee"), "LeftFoot": ("LeftLowerLeg", "LeftAnkle"),
    "RightUpperLeg": ("LowerTorso", "RightHip"), "RightLowerLeg": ("RightUpperLeg", "RightKnee"), "RightFoot": ("RightLowerLeg", "RightAnkle"),
}

# Shared body layout for generated characters (front +Y, right +X, feet at z=-0.95).
GROUND = -0.95
J = {
    "ground": (0, 0, GROUND), "root": (0, 0, -0.17), "waist": (0, 0, -0.07), "neck": (0, 0, 0.48),
    "RightShoulder": (0.42, 0, 0.40), "RightElbow": (0.42, 0, 0.22), "RightWrist": (0.42, 0, -0.02),
    "LeftShoulder": (-0.42, 0, 0.40), "LeftElbow": (-0.42, 0, 0.22), "LeftWrist": (-0.42, 0, -0.02),
    "RightHip": (0.135, 0, -0.27), "RightKnee": (0.135, 0, -0.52), "RightAnkle": (0.135, 0, -0.80),
    "LeftHip": (-0.135, 0, -0.27), "LeftKnee": (-0.135, 0, -0.52), "LeftAnkle": (-0.135, 0, -0.80),
}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------------------------------------------------------- palette texture
CELL = 32
GRID = 8

class Palette:
    def __init__(self, name, entries):
        # entries: key -> (r, g, b) sRGB 0..1, metallic, roughness
        self.keys = list(entries)
        size = CELL * GRID
        color = np.zeros((size, size, 4), dtype=np.float32)
        mr = np.zeros((size, size, 4), dtype=np.float32)
        color[..., 3] = 1
        mr[..., 3] = 1
        for i, key in enumerate(self.keys):
            (r, g, b), metal, rough = entries[key]
            cx, cy = i % GRID, i // GRID
            sl = (slice(cy * CELL, cy * CELL + CELL), slice(cx * CELL, cx * CELL + CELL))
            color[sl] = (r, g, b, 1)
            mr[sl] = (0, rough, metal, 1)
        self.color = self._image(name + "_Color", color, True)
        self.mr = self._image(name + "_MetalRough", mr, False)
        self.material = self._material(name)

    def _image(self, name, pixels, srgb):
        size = CELL * GRID
        img = bpy.data.images.new(name, size, size, alpha=False)
        img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
        img.pixels.foreach_set(pixels.ravel())
        img.file_format = "PNG"
        img.pack()
        return img

    def _material(self, name):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = self.color; tc.interpolation = "Closest"
        tm = nt.nodes.new("ShaderNodeTexImage"); tm.image = self.mr; tm.interpolation = "Closest"
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tm.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        return mat

    def uv(self, key):
        i = self.keys.index(key)
        cx, cy = i % GRID, i // GRID
        # image rows start at the bottom in Blender UV space
        return ((cx + 0.5) / GRID, (cy + 0.5) / GRID)

# ---------------------------------------------------------------- shape helpers
class Builder:
    def __init__(self, palette):
        self.pal = palette
        self.parts = {name: [] for name in R15}

    def _finish(self, obj, part, key, bevel, segments=2):
        if bevel > 0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
        me = obj.data
        if not me.uv_layers:
            me.uv_layers.new()
        u, v = self.pal.uv(key)
        uvl = me.uv_layers.active.data
        for loop in uvl:
            loop.uv = (u, v)
        for poly in me.polygons:
            poly.use_smooth = False
        self.parts[part].append(obj)
        return obj

    def box(self, part, key, center, size, bevel=0.018, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=[math.radians(a) for a in rot])
        obj = bpy.context.active_object
        obj.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return self._finish(obj, part, key, min(bevel, min(size) * 0.45))

    def cyl(self, part, key, center, radius, depth, rot=(0, 0, 0), verts=16, bevel=0.01):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center,
                                            rotation=[math.radians(a) for a in rot])
        return self._finish(bpy.context.active_object, part, key, bevel)

    def cone(self, part, key, center, r1, r2, depth, rot=(0, 0, 0), verts=12):
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=center,
                                        rotation=[math.radians(a) for a in rot])
        return self._finish(bpy.context.active_object, part, key, 0)

    def ball(self, part, key, center, radius, seg=12):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=radius, location=center)
        obj = bpy.context.active_object
        return self._finish(obj, part, key, 0)

    # ---- body building blocks
    def face(self, eyes="eye", mouth=True, y=0.211):
        for sx in (-0.075, 0.075):
            self.box("Head", eyes, (sx, y, 0.72), (0.05, 0.02, 0.085), bevel=0.008)
            self.box("Head", "white", (sx + 0.012, y + 0.002, 0.74), (0.018, 0.02, 0.025), bevel=0.004)
        if mouth:
            self.box("Head", "mouth", (0, y, 0.61), (0.1, 0.02, 0.022), bevel=0.006)

    def head(self, key="skin"):
        self.box("Head", key, (0, 0, 0.695), (0.42, 0.42, 0.41), bevel=0.05)

    def torso(self, top, bottom=None):
        self.box("UpperTorso", top, (0, 0, 0.2), (0.56, 0.38, 0.54), bevel=0.03)
        self.box("LowerTorso", bottom or top, (0, 0, -0.17), (0.52, 0.35, 0.2), bevel=0.03)

    def arm(self, side, upper, lower, hand="skin", pad=None, cuff=None):
        x = J[side + "Shoulder"][0]
        self.box(side + "UpperArm", upper, (x, 0, 0.335), (0.25, 0.26, 0.27), bevel=0.03)
        self.box(side + "LowerArm", lower, (x, 0, 0.1), (0.24, 0.25, 0.24), bevel=0.03)
        self.box(side + "Hand", hand, (x, 0, -0.1), (0.2, 0.21, 0.16), bevel=0.035)
        if pad:
            out = 1 if x > 0 else -1
            self.box(side + "UpperArm", pad, (x + out * 0.02, 0, 0.45), (0.31, 0.32, 0.1), bevel=0.03)
        if cuff:
            self.box(side + "LowerArm", cuff, (x, 0, 0.0), (0.27, 0.28, 0.06), bevel=0.015)

    def leg(self, side, upper, lower, boot, cuff=None):
        x = J[side + "Hip"][0]
        self.box(side + "UpperLeg", upper, (x, 0, -0.395), (0.25, 0.3, 0.25), bevel=0.025)
        self.box(side + "LowerLeg", lower, (x, 0, -0.66), (0.24, 0.29, 0.28), bevel=0.025)
        self.box(side + "Foot", boot, (x, 0.03, -0.875), (0.25, 0.36, 0.15), bevel=0.035)
        if cuff:
            self.box(side + "LowerLeg", cuff, (x, 0, -0.56), (0.27, 0.31, 0.06), bevel=0.015)

    def join(self):
        """Joins each part's pieces into one mesh named after the part."""
        objs = {}
        for part, pieces in self.parts.items():
            bpy.ops.object.select_all(action="DESELECT")
            for p in pieces:
                p.select_set(True)
            bpy.context.view_layer.objects.active = pieces[0]
            if len(pieces) > 1:
                bpy.ops.object.join()
            obj = bpy.context.active_object
            obj.name = part
            obj.data.name = part
            obj.data.materials.clear()
            obj.data.materials.append(self.pal.material)
            objs[part] = obj
        return objs

COMMON = {
    "skin": ((0.95, 0.78, 0.62), 0, 0.6),
    "eye": ((0.07, 0.07, 0.09), 0, 0.3),
    "white": ((1, 1, 1), 0, 0.3),
    "mouth": ((0.35, 0.15, 0.12), 0, 0.6),
    "gold": ((1.0, 0.76, 0.3), 1, 0.22),
    "steel": ((0.78, 0.8, 0.84), 1, 0.2),
    "leather": ((0.48, 0.31, 0.18), 0, 0.55),
    "leatherDark": ((0.28, 0.18, 0.11), 0, 0.6),
    "wood": ((0.5, 0.33, 0.18), 0, 0.7),
}

def palette(name, extra):
    entries = dict(COMMON)
    entries.update(extra)
    return Palette(name, entries)

# ---------------------------------------------------------------- characters
def build_ranger():
    b = Builder(palette("Ranger", {
        "green": ((0.22, 0.46, 0.24), 0, 0.8), "greenDark": ((0.13, 0.3, 0.15), 0, 0.85),
        "feather": ((0.9, 0.3, 0.2), 0, 0.7),
    }))
    b.head(); b.face()
    # hood: back, top and sides wrap the head, open face
    b.box("Head", "green", (0, -0.05, 0.71), (0.47, 0.34, 0.47), bevel=0.05)
    b.box("Head", "green", (0, 0.03, 0.93), (0.47, 0.44, 0.07), bevel=0.03)
    for sx in (-0.225, 0.225):
        b.box("Head", "green", (sx, 0.06, 0.7), (0.05, 0.34, 0.44), bevel=0.02)
    b.box("Head", "greenDark", (0, -0.26, 0.64), (0.14, 0.12, 0.16), bevel=0.03)  # hood tail
    # leather vest over green tunic
    b.torso("green", "leatherDark")
    b.box("UpperTorso", "leather", (0, 0.02, 0.22), (0.5, 0.36, 0.44), bevel=0.03)
    b.box("UpperTorso", "leatherDark", (0.05, 0.195, 0.2), (0.07, 0.02, 0.5), bevel=0.01, rot=(0, 35, 0))  # strap
    b.box("LowerTorso", "gold", (0, 0.18, -0.1), (0.1, 0.04, 0.08), bevel=0.012)  # buckle
    for sx in (-0.16, 0.16):
        b.box("LowerTorso", "leather", (sx, 0.17, -0.17), (0.1, 0.07, 0.1), bevel=0.02)  # pouches
    # cloak + quiver on the back
    b.box("UpperTorso", "greenDark", (0, -0.23, 0.02), (0.58, 0.06, 0.86), bevel=0.02, rot=(-6, 0, 0))
    b.cyl("UpperTorso", "leather", (0.12, -0.28, 0.33), 0.07, 0.45, rot=(0, -20, 0))
    for dx in (0.07, 0.12, 0.17):
        b.box("UpperTorso", "feather", (dx + 0.07, -0.28, 0.6), (0.03, 0.03, 0.1), bevel=0.008, rot=(0, -20, 0))
    for side in ("Left", "Right"):
        b.arm(side, "green", "leather", pad="leatherDark", cuff="leatherDark")
        b.leg(side, "leatherDark", "greenDark", "leather", cuff="leatherDark")
    return b

def build_mage():
    b = Builder(palette("Mage", {
        "purple": ((0.4, 0.22, 0.7), 0, 0.65), "purpleDark": ((0.24, 0.13, 0.44), 0, 0.7),
        "beard": ((0.93, 0.93, 0.96), 0, 0.9), "gem": ((0.35, 0.85, 1.0), 0.2, 0.05),
    }))
    b.head(); b.face(mouth=False)
    # beard and moustache
    b.box("Head", "beard", (0, 0.2, 0.57), (0.36, 0.08, 0.18), bevel=0.04)
    b.box("Head", "beard", (0, 0.2, 0.47), (0.24, 0.07, 0.14), bevel=0.04)
    # wizard hat: brim + tall bent cone + gold band + star
    b.cyl("Head", "purpleDark", (0, 0, 0.92), 0.36, 0.05, verts=20)
    b.cone("Head", "purple", (0, -0.02, 1.13), 0.23, 0.02, 0.44, rot=(-8, 0, 0), verts=16)
    b.cyl("Head", "gold", (0, 0, 0.965), 0.235, 0.05, verts=20)
    b.box("Head", "gem", (0, 0.2, 1.03), (0.07, 0.03, 0.07), bevel=0.01, rot=(0, 45, 0))
    # robes with gold trim and a gem clasp
    b.torso("purple", "purpleDark")
    b.box("UpperTorso", "gold", (0, 0.195, 0.2), (0.07, 0.02, 0.54), bevel=0.01)
    b.box("UpperTorso", "gem", (0, 0.21, 0.36), (0.09, 0.03, 0.09), bevel=0.02, rot=(0, 45, 0))
    b.box("UpperTorso", "purpleDark", (0, 0, 0.44), (0.62, 0.42, 0.08), bevel=0.02)  # mantle
    b.box("LowerTorso", "gold", (0, 0, -0.1), (0.54, 0.37, 0.05), bevel=0.012)  # sash
    b.box("LowerTorso", "purple", (0, 0, -0.26), (0.58, 0.4, 0.16), bevel=0.03)  # robe skirt
    b.box("UpperTorso", "purpleDark", (0, -0.22, 0.05), (0.54, 0.05, 0.8), bevel=0.02, rot=(-5, 0, 0))  # cloak
    for side in ("Left", "Right"):
        b.arm(side, "purple", "purple", cuff="gold")
        # wide sleeve ends
        x = J[side + "Shoulder"][0]
        b.box(side + "LowerArm", "purpleDark", (x, 0, 0.03), (0.3, 0.31, 0.1), bevel=0.02)
        b.leg(side, "purpleDark", "purpleDark", "leatherDark")
    return b

def build_rogue():
    b = Builder(palette("Rogue", {
        "black": ((0.1, 0.1, 0.12), 0, 0.55), "charcoal": ((0.22, 0.22, 0.26), 0, 0.6),
        "red": ((0.75, 0.1, 0.15), 0, 0.65),
    }))
    b.head(); b.face(mouth=False)
    # red mask over the lower face, dark hood
    b.box("Head", "red", (0, 0.03, 0.57), (0.44, 0.38, 0.16), bevel=0.03)
    b.box("Head", "black", (0, -0.05, 0.71), (0.47, 0.34, 0.47), bevel=0.05)
    b.box("Head", "black", (0, 0.03, 0.93), (0.47, 0.44, 0.07), bevel=0.03)
    for sx in (-0.225, 0.225):
        b.box("Head", "black", (sx, 0.06, 0.72), (0.05, 0.34, 0.42), bevel=0.02)
    b.box("Head", "red", (0.12, -0.24, 0.6), (0.08, 0.05, 0.28), bevel=0.02, rot=(0, 15, 0))  # scarf tail
    # leathers, crossed straps, red sash, dagger sheaths
    b.torso("black", "charcoal")
    for ang in (35, -35):
        b.box("UpperTorso", "charcoal", (0, 0.195, 0.2), (0.06, 0.02, 0.62), bevel=0.01, rot=(0, ang, 0))
    b.box("UpperTorso", "steel", (0, 0.21, 0.2), (0.07, 0.02, 0.07), bevel=0.01, rot=(0, 45, 0))
    b.box("LowerTorso", "red", (0, 0, -0.1), (0.55, 0.38, 0.08), bevel=0.02)
    b.box("LowerTorso", "red", (0.2, 0.19, -0.2), (0.08, 0.03, 0.18), bevel=0.015, rot=(0, -12, 0))
    for sx in (-0.29, 0.29):
        b.box("LowerTorso", "leatherDark", (sx, 0.05, -0.22), (0.05, 0.08, 0.26), bevel=0.012)
        b.box("LowerTorso", "steel", (sx, 0.05, -0.06), (0.06, 0.09, 0.06), bevel=0.01)
    for side in ("Left", "Right"):
        b.arm(side, "black", "charcoal", hand="black", pad="charcoal", cuff="red")
        b.leg(side, "charcoal", "black", "black", cuff="charcoal")
    return b

def build_cleric():
    b = Builder(palette("Cleric", {
        "white": ((0.96, 0.95, 0.91), 0, 0.55), "cream": ((0.9, 0.84, 0.66), 0, 0.6),
        "blue": ((0.3, 0.5, 0.92), 0, 0.5), "halo": ((1.0, 0.92, 0.55), 1, 0.1),
    }))
    b.head(); b.face()
    # gold circlet with a gem, and a floating halo
    b.box("Head", "gold", (0, 0, 0.84), (0.44, 0.44, 0.06), bevel=0.015)
    b.box("Head", "blue", (0, 0.225, 0.84), (0.07, 0.02, 0.07), bevel=0.012, rot=(0, 45, 0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.025, major_segments=24, minor_segments=8,
                                     location=(0, -0.02, 1.02), rotation=(math.radians(15), 0, 0))
    b._finish(bpy.context.active_object, "Head", "halo", 0)
    # vestments: white robe, gold mantle, tabard with a cross
    b.torso("white", "cream")
    b.box("UpperTorso", "gold", (0, 0, 0.44), (0.62, 0.42, 0.08), bevel=0.02)
    b.box("UpperTorso", "cream", (0, 0.195, 0.15), (0.3, 0.02, 0.5), bevel=0.01)
    b.box("UpperTorso", "gold", (0, 0.21, 0.2), (0.05, 0.02, 0.28), bevel=0.008)
    b.box("UpperTorso", "gold", (0, 0.21, 0.24), (0.18, 0.02, 0.05), bevel=0.008)
    b.box("LowerTorso", "gold", (0, 0, -0.1), (0.54, 0.37, 0.05), bevel=0.012)
    b.box("LowerTorso", "white", (0, 0, -0.26), (0.58, 0.4, 0.16), bevel=0.03)
    b.box("UpperTorso", "gold", (0, -0.22, 0.02), (0.56, 0.05, 0.84), bevel=0.02, rot=(-6, 0, 0))  # cape
    for side in ("Left", "Right"):
        b.arm(side, "white", "white", pad="gold", cuff="gold")
        b.leg(side, "cream", "white", "gold")
    return b

# ---------------------------------------------------------------- knight (split the Meshy mesh)
KNIGHT_CENTER = (-0.07, 0.2)  # body centre in the source file (x, y)
KNIGHT_JOINTS_SRC = {
    "ground": (0, 0, -0.952), "root": (0, 0, -0.15), "waist": (0, 0, -0.05), "neck": (0, 0, 0.49),
    # source file faces -Y, so the character's right is -X there
    "RightShoulder": (-0.42, 0, 0.45), "RightElbow": (-0.42, 0, 0.25), "RightWrist": (-0.42, 0, -0.02),
    "LeftShoulder": (0.42, 0, 0.45), "LeftElbow": (0.42, 0, 0.25), "LeftWrist": (0.42, 0, -0.02),
    "RightHip": (-0.135, 0, -0.25), "RightKnee": (-0.135, 0, -0.5), "RightAnkle": (-0.135, 0, -0.78),
    "LeftHip": (0.135, 0, -0.25), "LeftKnee": (0.135, 0, -0.5), "LeftAnkle": (0.135, 0, -0.78),
}

def knight_part(x, y, z):
    u = x - KNIGHT_CENTER[0]
    if u < -0.27 and z < -0.27:
        return None  # sword blade: the game's own weapon is shown instead
    if y > 0.43 and z < 0.47:
        return "UpperTorso"  # cape hangs from the shoulders
    if u < -0.27:
        return "RightUpperArm" if z >= 0.25 else ("RightLowerArm" if z >= -0.02 else "RightHand")
    if u > 0.27:
        if z >= 0.25:
            return "LeftUpperArm"
        if z < -0.02 and y > 0.22:
            return "LeftHand"
        return "LeftLowerArm"  # includes the shield
    if z >= 0.49:
        return "Head"
    if z >= -0.05:
        return "UpperTorso"
    if z >= -0.25:
        return "LowerTorso"
    side = "Right" if u < 0 else "Left"
    if z >= -0.5:
        return side + "UpperLeg"
    return side + ("LowerLeg" if z >= -0.78 else "Foot")

def build_knight():
    bpy.ops.import_scene.gltf(filepath=KNIGHT_SRC)
    src = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    bpy.context.view_layer.objects.active = src
    src.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = src.data
    bm = bmesh.new(); bm.from_mesh(me)
    assign = [knight_part(*f.calc_center_median()) for f in bm.faces]
    bm.free()
    objs = {}
    for part in R15:
        obj = src.copy(); obj.data = me.copy(); obj.name = part; obj.data.name = part
        bpy.context.scene.collection.objects.link(obj)
        bm = bmesh.new(); bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f, a in zip(bm.faces, assign) if a != part], context="FACES")
        bm.to_mesh(obj.data); bm.free()
        objs[part] = obj
    bpy.data.objects.remove(src)
    # centre the body, then turn it to face +Y (right hand to +X)
    turn = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation((-KNIGHT_CENTER[0], -KNIGHT_CENTER[1], 0))
    for obj in objs.values():
        obj.data.transform(turn)
    joints = {}
    for name, (x, y, z) in KNIGHT_JOINTS_SRC.items():
        p = turn @ Vector((x + KNIGHT_CENTER[0], y + KNIGHT_CENTER[1], z))
        joints[name] = (p.x, p.y, p.z)
    return objs, joints, objs["Head"].data.materials[0]

# ---------------------------------------------------------------- rigging + export
def ensure_part(objs, part, joints, material):
    """A body part with no geometry (e.g. a hand hidden behind a shield) gets a small nub."""
    if len(objs[part].data.polygons) > 0:
        return
    bpy.data.objects.remove(objs[part])
    key = part.replace("Hand", "Wrist").replace("Foot", "Ankle")
    bpy.ops.mesh.primitive_cube_add(size=0.12, location=joints.get(key, (0, 0, 0)))
    obj = bpy.context.active_object
    obj.name = part; obj.data.name = part
    obj.data.materials.append(material)
    objs[part] = obj

def rig_and_export(name, objs, joints, material):
    for part in R15:
        ensure_part(objs, part, joints, material)
    # HumanoidRootPart: R15 standard 2x2x1 studs, scaled to this body (1 unit ~ 2.8 studs)
    s = 1 / 2.8
    bpy.ops.mesh.primitive_cube_add(size=1, location=joints["root"])
    hrp = bpy.context.active_object
    hrp.scale = (2 * s, 1 * s, 2 * s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    hrp.name = "HumanoidRootPart"; hrp.data.name = "HumanoidRootPart"
    # Invisible, like Roblox's own root part.
    ghost = bpy.data.materials.new("HumanoidRootPart")
    ghost.use_nodes = True
    ghost.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.0
    ghost.blend_method = "BLEND"
    hrp.data.materials.append(ghost)
    hrp.hide_render = True
    objs = dict(objs); objs["HumanoidRootPart"] = hrp

    # origin of every part at its bounding-box centre
    for obj in objs.values():
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")

    # Game file: 15 plain MeshParts named after R15 parts. The game joins them with
    # Motor6Ds at runtime (Shared/ClassRigs.lua), so Roblox's own animations drive them.
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True,
                              export_skins=False, export_animations=False, export_materials="EXPORT")

    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, (parent, joint) in BONES.items():
        eb = arm_data.edit_bones.new(bone)
        head = Vector(joints[joint])
        # tail toward the child joint, or a short stub
        children = [j for b2, (p2, j) in BONES.items() if p2 == bone and j != joint]
        tail = Vector(joints[children[0]]) if children else head + Vector((0, 0, 0.12 if bone == "Head" else -0.1))
        if (tail - head).length < 0.02:
            tail = head + Vector((0, 0, 0.08))
        eb.head, eb.tail = head, tail
        if parent:
            eb.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")

    for part, obj in objs.items():
        bone = "HumanoidRootNode" if part == "HumanoidRootPart" else part
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        mw = obj.matrix_world.copy()
        obj.parent = arm
        obj.matrix_world = mw

    tris = {p: sum(len(poly.vertices) - 2 for poly in o.data.polygons) for p, o in objs.items()}
    path = os.path.join(OUT, name + "_Rigged.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_skins=True,
                              export_animations=False, export_apply=False, export_materials="EXPORT")

    # joint positions relative to the body's bounding box, in Roblox axes (x, z, -y), per unit height
    pts = [obj.matrix_world @ Vector(c) for p, obj in objs.items() if p != "HumanoidRootPart" for c in obj.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre, height = (mn + mx) / 2, mx.z - mn.z
    rel = {}
    for joint, p in joints.items():
        d = (Vector(p) - centre) / height
        rel[joint] = (round(d.x, 4), round(d.z, 4), round(-d.y, 4))
    return {"file": path, "tris": sum(tris.values()), "maxPartTris": max(tris.values()), "joints": rel,
            "arm": arm, "objs": objs}

def pose_and_render(name, arm, joints):
    """Renders the model in a neutral and an action pose to prove the skeleton drives it."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 24; sc.cycles.use_denoising = False
    sc.render.resolution_x = 420; sc.render.resolution_y = 520
    sc.render.film_transparent = True
    world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.55
    cam.location = (1.9, 3.4, 0.35); cam.rotation_euler = (math.radians(86), 0, math.radians(151))
    sc.camera = cam
    for rot, energy in ((( 50, 0, 150), 3.5), ((60, 0, -40), 1.5)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
        sun.rotation_euler = [math.radians(a) for a in rot]; sun.data.energy = energy
    sc.render.filepath = os.path.join(OUT, name + "_rest.png")
    bpy.ops.render.render(write_still=True)
    pb = arm.pose.bones
    pb["RightUpperArm"].rotation_mode = "XYZ"; pb["RightUpperArm"].rotation_euler = (math.radians(-110), 0, 0)
    pb["LeftUpperArm"].rotation_mode = "XYZ"; pb["LeftUpperArm"].rotation_euler = (math.radians(35), 0, 0)
    pb["RightLowerArm"].rotation_mode = "XYZ"; pb["RightLowerArm"].rotation_euler = (math.radians(-30), 0, 0)
    pb["LeftUpperLeg"].rotation_mode = "XYZ"; pb["LeftUpperLeg"].rotation_euler = (math.radians(-35), 0, 0)
    pb["RightUpperLeg"].rotation_mode = "XYZ"; pb["RightUpperLeg"].rotation_euler = (math.radians(30), 0, 0)
    pb["LeftLowerLeg"].rotation_mode = "XYZ"; pb["LeftLowerLeg"].rotation_euler = (math.radians(40), 0, 0)
    pb["Head"].rotation_mode = "XYZ"; pb["Head"].rotation_euler = (0, 0, math.radians(20))
    bpy.context.view_layer.update()
    sc.render.filepath = os.path.join(OUT, name + "_pose.png")
    bpy.ops.render.render(write_still=True)

report = {}
for cls in ["Knight", "Ranger", "Mage", "Rogue", "Cleric"]:
    reset()
    if cls == "Knight":
        objs, joints, mat = build_knight()
    else:
        builder = {"Ranger": build_ranger, "Mage": build_mage, "Rogue": build_rogue, "Cleric": build_cleric}[cls]()
        objs, joints, mat = builder.join(), dict(J), builder.pal.material
    info = rig_and_export(cls, objs, joints, mat)
    pose_and_render(cls, info.pop("arm"), joints)
    info.pop("objs")
    report[cls] = info
    print("BUILT", cls, info["tris"], "tris, max part", info["maxPartTris"])
with open(os.path.join(OUT, "rigs.json"), "w") as f:
    json.dump(report, f, indent=1)
