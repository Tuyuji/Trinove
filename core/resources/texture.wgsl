alias BufferTransform = u32;
const BT_NORMAL       : BufferTransform = 0u;
const BT_90           : BufferTransform = 1u;  // 90° CCW
const BT_180          : BufferTransform = 2u;
const BT_270          : BufferTransform = 3u;  // 270° CCW
const BT_FLIPPED      : BufferTransform = 4u;  // horizontal flip
const BT_FLIPPED_90   : BufferTransform = 5u;
const BT_FLIPPED_180  : BufferTransform = 6u;
const BT_FLIPPED_270  : BufferTransform = 7u;

// Group 0: Per-frame
struct FrameUniforms {
    projection: mat4x4f,
}

@group(0) @binding(0) var<uniform> frame: FrameUniforms;
@group(0) @binding(1) var samp: sampler;

// Group 1: Per-draw
struct DrawUniforms {
    rect: vec4f,                // x, y, width, height
    srcRect: vec4f,             // u0, v0, u1, v1 (source UV rectangle)
    color: vec4f,               // tint color (white = no tint)
    opacity: f32,
    opaqueAlpha: u32,           // 1 = ignore texture alpha (XRGB formats)
    uvTransform: BufferTransform,
}

@group(1) @binding(0) var<uniform> draw: DrawUniforms;
@group(1) @binding(1) var tex: texture_2d<f32>;

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f,
}

@vertex
fn vsMain(@builtin(vertex_index) idx: u32) -> VertexOutput {
    let x = f32(idx & 1u);
    let y = f32((idx >> 1u) & 1u);

    let pos = vec2f(
        draw.rect.x + x * draw.rect.z,
        draw.rect.y + y * draw.rect.w
    );

    // Remap (x, y) -> (sx, sy) to apply the inverse of the client's buffer transform.
    var sx: f32;
    var sy: f32;
    switch (draw.uvTransform) {
        case BT_90:          { sx = y;       sy = 1.0 - x; }  // inverse: 90° CW
        case BT_180:         { sx = 1.0 - x; sy = 1.0 - y; }
        case BT_270:         { sx = 1.0 - y; sy = x;       }  // inverse: 270° CW
        case BT_FLIPPED:     { sx = 1.0 - x; sy = y;       }
        case BT_FLIPPED_90:  { sx = 1.0 - y; sy = 1.0 - x; }
        case BT_FLIPPED_180: { sx = x;       sy = 1.0 - y; }
        case BT_FLIPPED_270: { sx = y;       sy = x;       }
        default:             { sx = x;       sy = y;       }  // BT_NORMAL
    }

    var out: VertexOutput;
    out.position = frame.projection * vec4f(pos, 0.0, 1.0);
    out.uv = vec2f(
        draw.srcRect.x + sx * (draw.srcRect.z - draw.srcRect.x),
        draw.srcRect.y + sy * (draw.srcRect.w - draw.srcRect.y)
    );
    return out;
}

@fragment
fn fsMain(in: VertexOutput) -> @location(0) vec4f {
    let texColor = textureSample(tex, samp, in.uv);
    let alpha = select(texColor.a, 1.0, draw.opaqueAlpha != 0u);
    return vec4f(texColor.rgb * draw.color.rgb, alpha * draw.color.a * draw.opacity);
}
