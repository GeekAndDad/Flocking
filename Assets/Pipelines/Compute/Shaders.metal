#include "Satin/Includes.metal"
#include "../Types.metal"
#include "../Physics/Flocking.metal"
#include "../Physics/Boundary.metal"
#include "../Physics/Damping.metal"
#include "Library/Random.metal"
#include "Library/Curlnoise.metal"
#include "Library/Pi.metal"
#include "Library/Shapes.metal"

kernel void resetCompute( uint index [[thread_position_in_grid]],
	constant Particle *inBuffer [[buffer( ComputeBufferCustom0 )]],
	device Particle *outBuffer [[buffer( ComputeBufferCustom1 )]],
	constant ComputeUniforms &uniforms [[buffer( ComputeBufferCustom2 )]] )
{
	const float id = int( index );
	const float2 res = uniforms.resolution.xy;
	const float time = uniforms.time;
	const float fid = float( id );

	Particle out;
	out.position = 2.0 * res * float2( random( float2( time, fid ) ), random( float2( time, -2.0 * fid ) ) ) - res.xy;
	out.velocity = 2.0 * float2( random( float2( fid, time ) ), random( float2( -2.0 * fid, time ) ) ) - 1.0;
	out.radius = uniforms.radius;
	outBuffer[index] = out;
}

kernel void updateCompute( uint index [[thread_position_in_grid]],
	constant Particle *inBuffer [[buffer( ComputeBufferCustom0 )]],
	device Particle *outBuffer [[buffer( ComputeBufferCustom1 )]],
	constant ComputeUniforms &uniforms [[buffer( ComputeBufferCustom2 )]] )
{
	const int count = uniforms.particleCount;
	const float time = uniforms.time;
	const float2 res = uniforms.resolution.xy;
	const float accelerationMax = uniforms.accelerationMax;
	const float velocityMax = uniforms.velocityMax;

	const Particle in = inBuffer[index];

	Particle out;
	float2 p = in.position;
	float2 v = in.velocity;

	float2 a = dampingForce( v, uniforms.damping );
	a += uniforms.flocking * flockingForce( index, p, v, count, uniforms, inBuffer );
	a += uniforms.curl * curlNoise( float3( uniforms.curlScale * p, time * uniforms.curlSpeed ) ).xy;

	const float accelerationMagnitude = length( a );
	if( accelerationMagnitude > accelerationMax ) {
		a /= accelerationMagnitude;
		a *= accelerationMax;
	}

	const float velocityMagnitude = length( v );
	if( velocityMagnitude > velocityMax ) {
		v /= velocityMagnitude;
		v *= velocityMax;
	}

	v += a;
	p += v;
	p = boundary( p, res, uniforms.radius );

	out.position = p;
	out.velocity = v;
	out.radius = uniforms.radius;
	outBuffer[index] = out;
}
