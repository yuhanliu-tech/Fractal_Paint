const HEX_SIZE = 32.f; // size of hexagonal tiles
const SQRT3 = sqrt(3.0);

const g_offsets = array<vec2<f32>, 3>(
    vec2<f32>(0.1039284, 0.20344234),
    vec2<f32>(0.9458, 0.86602540378),
    vec2<f32>(0.34578, 0.9023423)
);

fn random2(p: vec2<f32>) -> vec2<f32> {
    return fract(sin(vec2(dot(p, vec2(127.1f, 311.7f)),
                 dot(p, vec2(269.5f,183.3f))))
                 * 43758.5453f);
}

const TRI_HEIGHT = sqrt(3.0) / 2.0;

fn get_triangle_vertices(position: vec2<f32>) -> array<vec2<f32>, 3> {
    var uv = position / HEX_SIZE / vec2(1, TRI_HEIGHT);
    let base = floor(uv);

    var res: array<vec2<f32>, 3> = array<vec2<f32>, 3>(
        vec2<f32>(base.x, base.y),
        vec2<f32>(base.x + 0.5, base.y),
        vec2<f32>(base.x + 1.0, base.y)
    );

    let flipY = bool(i32(floor(uv.y)) % 2);
    let yFrac = select(1.0 - fract(uv.y), fract(uv.y), flipY);

    var stagger = !flipY;

    if (yFrac > fract(uv.x) * 2.0) {
        stagger = !stagger;
        for (var i = 0; i < 3; i++) {
            res[i].x -= 0.5;
        }
    } else if (yFrac > fract(uv.x) * -2.0 + 2.0) {
        stagger = !stagger;
        for (var i = 0; i < 3; i++) {
            res[i].x += 0.5;
        }
    }

    if (stagger) {
        res[0].y += 1;
        res[2].y += 1;
    } else {
        res[1].y += 1;
    }

    for (var i = 0; i < 3; i++) {
        res[i] *= HEX_SIZE * vec2(1, TRI_HEIGHT);
    }

    return res;
}

fn hashtri(tri: array<vec2<f32>, 3>) -> f32 {
    var h = dot(tri[0], vec2(127.1, 311.7)) + dot(tri[1], vec2(74.7, 173.1)) + dot(tri[2], vec2(157.3, 113.5));
    h = fract(sin(h) * 43758.5453123);
    return h;
}

fn double_triangle_area(a: vec2<f32>, b: vec2<f32>, c: vec2<f32>) -> f32 {
    return abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y));
}

const DOUBLE_TRIANGLE_AREA = TRI_HEIGHT * HEX_SIZE * HEX_SIZE / 2.0;
fn barycentric_weights(p: vec2f, a: vec2f, b: vec2f, c: vec2f) -> vec3f{
    return vec3f(
        double_triangle_area(p, b, c) / DOUBLE_TRIANGLE_AREA,
        double_triangle_area(p, c, a) / DOUBLE_TRIANGLE_AREA,
        double_triangle_area(p, a, b) / DOUBLE_TRIANGLE_AREA
    );
}