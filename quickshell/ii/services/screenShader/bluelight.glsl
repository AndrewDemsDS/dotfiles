#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Blue-light filter: warm the image by cutting blue and easing green.
// Lighter touch than night-light/hyprsunset; pairs well as a quick toggle.
void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    pixColor.b *= 0.72;
    pixColor.g *= 0.92;
    fragColor = pixColor;
}
