shader_type canvas_item;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(vec3(3.0), tex.a);
}
