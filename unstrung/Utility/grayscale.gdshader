shader_type canvas_item;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 color = texture(TEXTURE, UV);
	float gray = (color.r + color.g + color.b) / 3.0;
	color.a *= opacity;
	COLOR = vec4(gray, gray, gray, color.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
