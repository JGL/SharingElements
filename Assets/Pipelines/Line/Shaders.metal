#include "Library/Shapes.metal"
#include "Library/Fog.metal"
#include "Library/Pi.metal"

typedef struct {
	float4 color; //color
	float lineWidth; //slider,0,10,3
	float3 resolution;
} LineUniforms;

typedef struct {
	float4 position [[position]];
	float2 uv;
	float aspect [[flat]];
} CustomVertexData;

vertex CustomVertexData lineVertex(
	uint id [[instance_id]],
	Vertex in [[stage_in]],
	constant VertexUniforms &vertexUniforms [[buffer( VertexBufferVertexUniforms )]],
	constant LineUniforms &uniforms [[buffer( VertexBufferMaterialUniforms )]],
	constant float3 *points [[buffer( VertexBufferCustom0 )]] )
{
	const float2 res = uniforms.resolution.xy;
	const float aspect = uniforms.resolution.z;
	const int index = (int)id * 2;

	float4 p0 = float4( points[index], 1.0 );
	float4 p1 = float4( points[index + 1], 1.0 );

	const float4x4 vp = vertexUniforms.projectionMatrix * vertexUniforms.viewMatrix;
	const float4x4 mvp = vertexUniforms.modelViewProjectionMatrix;

	const float4 worldPosition = vertexUniforms.modelMatrix * mix( p0, p1, in.uv.x );

	p0 = mvp * p0;
	p1 = mvp * p1;

	// p0.y /= aspect;
	// p1.y /= aspect;

	float2 dir = p1.xy - p0.xy;
	float width = length( dir * res );
	dir.y /= aspect;

	dir = normalize( dir );
	float2 dirInv = float2( -dir.y, dir.x );

	const float2 size = 2.0 * uniforms.lineWidth / res;
	float4 offset = float4( size * mix( dirInv, -dirInv, in.uv.y ), 0.0, 0.0 );

	float4 ends = float4( 0.5 * size * mix( -dir, dir, in.uv.x ), 0.0, 0.0 );
	offset += ends;
	width += 2.0 * uniforms.lineWidth;

	CustomVertexData out;
	out.position = vp * worldPosition + offset;
	out.uv = in.uv;
	out.aspect = width / ( 4.0 * uniforms.lineWidth );
	return out;
}

fragment float4 lineFragment( CustomVertexData in [[stage_in]],
	constant LineUniforms &uniforms [[buffer( FragmentBufferMaterialUniforms )]] )
{
	const float4 color = uniforms.color;
	const float aspect = in.aspect;

	float2 uv = 2.0 * in.uv - 1.0;
	uv.x *= aspect;

	const float softness = 0.25;
	const float lineWidth = 0.5 - softness;

	float result = Line( uv, float2( -aspect + lineWidth + softness, 0.0 ), float2( aspect - lineWidth - softness, 0.0 ) ) - lineWidth;
	result = 1.0 - smoothstep( 0.0, softness + fwidth( result ), result );

	if( result <= 0.0 ) {
		discard_fragment();
	}

	return float4( color.rgb, color.a * result );
}
