import SpriteKit

/// Pixel-exact palette swap for the cat's fur. Sprites are drawn with four key colors
/// (see Tools/gen_sprites.py: O, OS, OL, D); everything else (eyes, white fur, pink) is untouched.
enum CatShader {
    private static let source = """
    void main() {
        // Custom shaders sample linearly; snap to texel centers (every cat layer is 64x64) to stay pixel-exact.
        vec2 uv = (floor(v_tex_coord * 64.0) + 0.5) / 64.0;
        vec4 c = texture2D(u_texture, uv);
        vec3 rgb = c.a > 0.0 ? c.rgb / c.a : c.rgb;
        if (distance(rgb, vec3(0.9490, 0.6000, 0.2902)) < 0.06) { rgb = u_fur.rgb; }
        else if (distance(rgb, vec3(0.8706, 0.4706, 0.2039)) < 0.06) { rgb = u_shade.rgb; }
        else if (distance(rgb, vec3(0.9843, 0.7373, 0.4510)) < 0.06) { rgb = u_light.rgb; }
        else if (distance(rgb, vec3(0.7765, 0.3686, 0.1098)) < 0.06) { rgb = u_stripe.rgb; }
        gl_FragColor = vec4(rgb * c.a, c.a);
    }
    """

    private static var cache: [CatCoat: SKShader] = [:]

    /// nil for the ginger coat: the sprites already are ginger, so no shader is needed.
    static func shader(for coat: CatCoat) -> SKShader? {
        guard coat != .ginger else { return nil }
        if let cached = cache[coat] { return cached }
        let names = ["u_fur", "u_shade", "u_light", "u_stripe"]
        let uniforms = zip(names, coat.palette).map { name, rgb in
            SKUniform(name: name, vectorFloat4: SIMD4<Float>(Float(rgb.0 / 255), Float(rgb.1 / 255), Float(rgb.2 / 255), 1))
        }
        let shader = SKShader(source: source, uniforms: uniforms)
        cache[coat] = shader
        return shader
    }
}
