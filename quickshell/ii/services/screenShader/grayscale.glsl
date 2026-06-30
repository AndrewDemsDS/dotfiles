#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Desaturate the whole screen to luminance. Useful for focus / reducing
// colour distraction. Point Config.options.light.shader.path here to use it.
void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    float luma = dot(pixColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(luma), pixColor.a);
}
