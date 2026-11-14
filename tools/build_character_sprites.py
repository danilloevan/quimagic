"""
Converte os GIFs de animação da Hidro (8 direções) em spritesheets PNG que o Godot
importa nativamente, e gera o recurso SpriteFrames (.tres) pronto para uso.

Uso:
    python tools/build_character_sprites.py ["C:/caminho/para/hidro moves"]

Todos os quadros são normalizados para 232x232 centralizando o canvas exportado pelo
PixelLab, o que mantém os pés exatamente na mesma linha (y = 195) em todas as direções.
"""
import os
import sys

from PIL import Image, ImageDraw

FRAME = 232
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC_DIR = os.path.join(PROJECT_ROOT, "hidro moves")
OUT_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites", "characters", "hidro")
RES_DIR = "res://assets/sprites/characters/hidro"

# Ordem das 8 direções (usada tanto em idle quanto em walk)
DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]

# Quadro de contato/passagem mais neutro de cada ciclo para usar como pose parada (idle)
IDLE_FRAME_INDEX = {
    "south": 3,
    "south-east": 6,
    "east": 2,
    "north-east": 7,
    "north": 1,
    "north-west": 5,
    "west": 2,
    "south-west": 6,
}

IDLE_FPS = 1.0
WALK_FPS = 8.0


def anim_name(prefix: str, direction: str) -> str:
    return f"{prefix}_{direction.replace('-', '_')}"


def dir_slug(direction: str) -> str:
    return direction.replace("-", "_")


def build_idle(src: str) -> None:
    sheet = Image.new("RGBA", (FRAME * len(DIRS), FRAME), (0, 0, 0, 0))
    for i, d in enumerate(DIRS):
        gif = Image.open(os.path.join(src, f"Idle_v3_running_{d}.gif"))
        gif.seek(IDLE_FRAME_INDEX[d])
        frame = gif.convert("RGBA")
        ox = (FRAME - gif.width) // 2
        oy = (FRAME - gif.height) // 2
        sheet.paste(frame, (i * FRAME + ox, oy), frame)
    sheet.save(os.path.join(OUT_DIR, "idle.png"))


def build_walk(src: str) -> int:
    frame_count = 0
    for d in DIRS:
        gif = Image.open(os.path.join(src, f"Idle_v3_running_{d}.gif"))
        n = gif.n_frames
        frame_count = n
        ox = (FRAME - gif.width) // 2
        oy = (FRAME - gif.height) // 2
        sheet = Image.new("RGBA", (FRAME * n, FRAME), (0, 0, 0, 0))
        for i in range(n):
            gif.seek(i)
            frame = gif.convert("RGBA")
            sheet.paste(frame, (i * FRAME + ox, oy), frame)
        sheet.save(os.path.join(OUT_DIR, f"walk_{dir_slug(d)}.png"))
    return frame_count


def build_shadow() -> None:
    # Sombra elíptica suave sob os pés (desenhada em 4x e reduzida para ter borda macia)
    w, h, s = 22, 9, 4
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
    for d in DIRS:
        slug = dir_slug(d)
        ext.append(f'[ext_resource type="Texture2D" path="{RES_DIR}/walk_{slug}.png" id="tex_walk_{slug}"]')

    for i, d in enumerate(DIRS):
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

    for d in DIRS:
        slug = dir_slug(d)
        frame_refs = []
        for i in range(walk_frames):
            sid = f"walk_{slug}_{i}"
            subs.append(
                f'[sub_resource type="AtlasTexture" id="{sid}"]\n'
                f'atlas = ExtResource("tex_walk_{slug}")\n'
                f"region = Rect2({i * FRAME}, 0, {FRAME}, {FRAME})\n"
            )
            frame_refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sid}")\n}}')
        anims.append(
            "{\n"
            f'"frames": [{", ".join(frame_refs)}],\n'
            '"loop": true,\n'
            f'"name": &"walk_{slug}",\n'
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

    with open(os.path.join(OUT_DIR, "hidro_frames.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def main() -> None:
    src = sys.argv[1] if len(sys.argv) >= 2 else DEFAULT_SRC_DIR
    os.makedirs(OUT_DIR, exist_ok=True)
    build_idle(src)
    walk_frames = build_walk(src)
    build_shadow()
    write_sprite_frames(walk_frames)
    print(f"Spritesheets e SpriteFrames gerados em: {OUT_DIR}")


if __name__ == "__main__":
    main()
