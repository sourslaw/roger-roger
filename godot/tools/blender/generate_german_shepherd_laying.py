import bpy
import os
import math


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def make_material(name: str, color: tuple[float, float, float, float], roughness: float = 0.6) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def add_cube(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float], rot: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return obj


def add_uv_sphere(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float], rot: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=loc, rotation=rot, segments=24, ring_count=12)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return obj


def add_cone(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float], rot: tuple[float, float, float]) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.5, depth=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return obj


def add_cylinder(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float], rot: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return obj


def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)


def make_dog() -> bpy.types.Object:
    fur_tan = make_material("DogFurTan", (0.68, 0.50, 0.26, 1.0), roughness=0.73)
    fur_dark = make_material("DogFurDark", (0.12, 0.09, 0.07, 1.0), roughness=0.78)
    nose_black = make_material("DogNose", (0.02, 0.02, 0.02, 1.0), roughness=0.3)
    eye_black = make_material("DogEye", (0.01, 0.01, 0.01, 1.0), roughness=0.2)

    body = add_uv_sphere("Body", (0.0, 0.0, 0.38), (0.65, 1.45, 0.52), (0.0, 0.0, math.radians(6)))
    chest = add_uv_sphere("Chest", (0.0, 0.66, 0.43), (0.58, 0.62, 0.52), (math.radians(10), 0.0, 0.0))
    haunch = add_uv_sphere("Haunch", (0.0, -0.72, 0.34), (0.60, 0.68, 0.46), (math.radians(-6), 0.0, 0.0))
    neck = add_uv_sphere("Neck", (0.0, 0.98, 0.48), (0.36, 0.34, 0.30), (math.radians(16), 0.0, 0.0))
    head = add_uv_sphere("Head", (0.0, 1.22, 0.56), (0.40, 0.55, 0.38), (math.radians(18), 0.0, 0.0))
    muzzle = add_uv_sphere("Muzzle", (0.0, 1.55, 0.45), (0.22, 0.28, 0.18), (math.radians(10), 0.0, 0.0))
    nose = add_uv_sphere("Nose", (0.0, 1.72, 0.43), (0.08, 0.10, 0.07))

    ear_l = add_cone("EarL", (-0.20, 1.10, 0.86), (0.20, 0.12, 0.28), (math.radians(-12), math.radians(6), math.radians(20)))
    ear_r = add_cone("EarR", (0.20, 1.10, 0.86), (0.20, 0.12, 0.28), (math.radians(-12), math.radians(-6), math.radians(-20)))

    paw_fl = add_cube("FrontPawL", (-0.18, 1.26, 0.15), (0.11, 0.54, 0.11), (0.0, math.radians(4), 0.0))
    paw_fr = add_cube("FrontPawR", (0.18, 1.24, 0.15), (0.11, 0.56, 0.11), (0.0, math.radians(-4), 0.0))
    paw_hl = add_cube("HindPawL", (-0.24, -1.08, 0.16), (0.12, 0.34, 0.11), (math.radians(5), math.radians(18), 0.0))
    paw_hr = add_cube("HindPawR", (0.24, -1.0, 0.16), (0.12, 0.34, 0.11), (math.radians(5), math.radians(-18), 0.0))

    tail = add_cylinder("Tail", (0.0, -1.36, 0.42), (0.09, 0.09, 0.42), (math.radians(72), 0.0, 0.0))

    eye_l = add_uv_sphere("EyeL", (-0.12, 1.47, 0.58), (0.04, 0.04, 0.04))
    eye_r = add_uv_sphere("EyeR", (0.12, 1.47, 0.58), (0.04, 0.04, 0.04))

    tan_parts = [
        body, chest, haunch, neck, head, muzzle,
        paw_fl, paw_fr, paw_hl, paw_hr, tail
    ]
    dark_parts = [ear_l, ear_r]
    for part in tan_parts:
        assign_material(part, fur_tan)
    for part in dark_parts:
        assign_material(part, fur_dark)
    assign_material(nose, nose_black)
    assign_material(eye_l, eye_black)
    assign_material(eye_r, eye_black)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in tan_parts + dark_parts + [nose]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    dog = bpy.context.active_object
    dog.name = "GermanShepherdLying"

    bpy.ops.object.shade_smooth()
    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))

    bevel = dog.modifiers.new(name="Bevel", type="BEVEL")
    bevel.width = 0.015
    bevel.segments = 3
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(35)

    # Keep eyes as separate objects for crisp highlights.
    eye_l.parent = dog
    eye_r.parent = dog

    bpy.ops.object.select_all(action="DESELECT")
    dog.select_set(True)
    eye_l.select_set(True)
    eye_r.select_set(True)
    bpy.context.view_layer.objects.active = dog
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    return dog


def export_glb(output_path: str) -> None:
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_normals=True,
        export_tangents=True,
    )


def main() -> None:
    clear_scene()
    dog = make_dog()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_glb = os.path.normpath(os.path.join(script_dir, "..", "..", "assets", "models", "dog", "GermanShepherdLying.glb"))
    export_glb(output_glb)
    print(f"Generated and exported: {output_glb}")


if __name__ == "__main__":
    main()
