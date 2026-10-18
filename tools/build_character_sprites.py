"""
Converte o export da personagem (PNGs de rotação + GIFs de caminhada) em spritesheets
PNG que o Godot importa nativamente, e gera o recurso SpriteFrames (.tres) pronto para uso.

Uso:
    python tools/build_character_sprites.py "C:/caminho/para/character - little_student_girls"

Todos os quadros são normalizados para 44x44 (tamanho dos GIFs de caminhada). Os PNGs de
rotação (32x32) são centralizados nesse quadro, o que mantém os pés exatamente na mesma
linha (y = 37) em todas as animações, evitando "pulos" ao trocar de idle para walk.
"""
import os
import sys

from PIL import Image, ImageDraw

FRAME = 44
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites", "characters", "student_girl")
RES_DIR = "res://assets/sprites/characters/student_girl"

# Ordem dos quadros de idle no spritesheet (8 direções)
IDLE_DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
WALK_DIRS = ["south", "north", "east", "west"]

IDLE_FPS = 1.0
WALK_FPS = 8.0


def anim_name(prefix: str, direction: str) -> str:
    return f"{prefix}_{direction.replace('-', '_')}"


def build_idle(src: str) -> None:
    sheet = Image.new("RGBA", (FRAME * len(IDLE_DIRS), FRAME), (0, 0, 0, 0))
    for i, d in enumerate(IDLE_DIRS):
        img = Image.open(os.path.join(src, "Idle", "rotations", f"{d}.png")).convert("RGBA")
        ox = (FRAME - img.width) // 2
        oy = (FRAME - img.height) // 2
        sheet.paste(img, (i * FRAME + ox, oy), img)
    sheet.save(os.path.join(OUT_DIR, "idle.png"))


def build_walk(src: str) -> int:
    frame_count = 0
    for d in WALK_DIRS:
        gif = Image.open(os.path.join(src, "Idle", "walk animations", f"Idle_v3_walking_{d}.gif"))
        n = gif.n_frames
        frame_count = n
        sheet = Image.new("RGBA", (FRAME * n, FRAME), (0, 0, 0, 0))
        for i in range(n):
            gif.seek(i)
            frame = gif.convert("RGBA")
            sheet.paste(frame, (i * FRAME, 0), frame)
        sheet.save(os.path.join(OUT_DIR, f"walk_{d}.png"))
    return frame_count


def build_shadow() -> None:
    # Sombra elíptica suave sob os pés (desenhada em 4x e reduzida para ter borda macia)
    w, h, s = 18, 7, 4
    big = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    draw.ellipse((0, 0, w * s - 1, h * s - 1), fill=(20, 16, 30, 110))
    big.resize((w, h), Image.LANCZOS).save(os.path.join(OUT_DIR, "shadow.png"))


def write_sprite_frames(walk_frames: int) -> None:
    lines = []
    ext = []
    subs = []
    anims = []

    ext.append(f'[ext_resource type="Texture2D" path="{RES_DIR}/idle.png" id="tex_idle"]')
    for d in WALK_DIRS:
        ext.append(f'[ext_resource type="Texture2D" path="{RES_DIR}/walk_{d}.png" id="tex_walk_{d}"]')

    for i, d in enumerate(IDLE_DIRS):
        sid = anim_name("idle", d)
        subs.append(
            f'[sub_resource type="AtlasTexture" id="{sid}"]\n'
            f'atlas = ExtResource("tex_idle")\n'
            f"region = Rect2({i * FRAME}, 0, {FRAME}, {FRAME})\n"
        )
        anims.append(
            "{\n"
            f'"frames": [{{\n"duration": 1.0,\n"texture": SubResource("{sid}")\n}}],\n'
            '"loop": true,\n'
            f'"name": &"{sid}",\n'
            f'"speed": {IDLE_FPS}\n'
            "}"
        )

    for d in WALK_DIRS:
        frame_refs = []
        for i in range(walk_frames):
            sid = f"walk_{d}_{i}"
            subs.append(
                f'[sub_resource type="AtlasTexture" id="{sid}"]\n'
                f'atlas = ExtResource("tex_walk_{d}")\n'
                f"region = Rect2({i * FRAME}, 0, {FRAME}, {FRAME})\n"
            )
            frame_refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sid}")\n}}')
        anims.append(
            "{\n"
            f'"frames": [{", ".join(frame_refs)}],\n'
            '"loop": true,\n'
            f'"name": &"walk_{d}",\n'
            f'"speed": {WALK_FPS}\n'
            "}"
        )

    load_steps = len(ext) + len(subs) + 1
    lines.append(f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]\n')
    lines.extend(ext)
    lines.append("")
    lines.extend(subs)
    lines.append("[resource]")
    lines.append(f"animations = [{', '.join(anims)}]")
    lines.append("")

    with open(os.path.join(OUT_DIR, "student_girl_frames.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    os.makedirs(OUT_DIR, exist_ok=True)
    build_idle(src)
    walk_frames = build_walk(src)
    build_shadow()
    write_sprite_frames(walk_frames)
    print(f"Spritesheets e SpriteFrames gerados em: {OUT_DIR}")


if __name__ == "__main__":
    main()
