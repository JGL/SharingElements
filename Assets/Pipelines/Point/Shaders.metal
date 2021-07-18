#include "Library/Shapes.metal"

typedef struct {
	float4 color; //color
	float pointSize; //slider,0,16,8
	float aspect;
} PointUniforms;

typedef struct {
	float4 position [[position]];
	float pointSize [[point_size]];
} CustomVertexData;

vertex CustomVertexData pointVertex( uint id [[instance_id]],
	Vertex in [[stage_in]],
	constant VertexUniforms &vertexUniforms [[buffer( VertexBufferVertexUniforms )]],
	constant PointUniforms &point [[buffer( VertexBufferMaterialUniforms )]],
	constant float3 *vertices [[buffer( VertexBufferCustom0 )]] )
{
	CustomVertexData out;
	const int index = (int)id;
	const float3 v0 = vertices[index];
	out.position = vertexUniforms.modelViewProjectionMatrix * float4( v0, 1.0 );
	out.pointSize = point.pointSize;
	return out;
}

fragment float4 pointFragment( CustomVertexData in [[stage_in]],
	const float2 puv [[point_coord]],
	constant PointUniforms &uniforms [[buffer( FragmentBufferMaterialUniforms )]] )
{
	const float2 uv = 2.0 * puv - 1.0;
	const float softness = 0.175;
	float result = Circle( uv, 1.0 - softness );
	result = 1.0 - smoothstep( 0.0, softness, result );
	if( result <= 0.0 ) {
		discard_fragment();
	}
	const float4 color = uniforms.color;
	return float4( color.rgb, color.a * result );
}
