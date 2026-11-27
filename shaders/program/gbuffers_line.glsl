// Block outline. Written in Iris "core" style because Iris doesn't translate
// old-style (compatibility) shaders for lines, and macOS rejects those.

#ifdef VERTEX
in vec3 vaPosition;
in vec4 vaColor;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec4 glcolor;

void main() {
    glcolor = vaColor;
    gl_Position = projectionMatrix * (modelViewMatrix * vec4(vaPosition, 1.0));
}
#endif

#ifdef FRAGMENT
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(pow(glcolor.rgb, vec3(2.2)), glcolor.a);
}
#endif
