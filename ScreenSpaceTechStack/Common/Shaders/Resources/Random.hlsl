// Copyright 1998-2018 Epic Games, Inc. All Rights Reserved.

/*=============================================================================
	Random.ush: A pseudo-random number generator.
=============================================================================*/

#ifndef __Random_ush__
#define __Random_ush__


inline int2 ihash(int2 n)
{
	n = (n << 13) ^ n;
	return (n*(n*n * 15731 + 789221) + 1376312589) & 2147483647;
}

inline int3 ihash(int3 n)
{
	n = (n << 13) ^ n;
	return (n*(n*n * 15731 + 789221) + 1376312589) & 2147483647;
}

inline float2 frand(int2 n)
{
	return ihash(n) / 2147483647.0;
}

inline float3 frand(int3 n)
{
	return ihash(n) / 2147483647.0;
}

inline float2 cellNoise(float2 p, float4 RandomNumber)
{
	int seed = dot(p, float2(641338.4168541, 963955.16871685));
	return sin(float2(frand(int2(seed, seed - 53))) * RandomNumber.xy + RandomNumber.zw);
}

inline float3 cellNoise(float3 p, float4 RandomNumber)
{
	int seed = dot(p, float3(641738.4168541, 9646285.16871685, 3186964.168734));
	return sin(float3(frand(int3(seed, seed - 12, seed - 57))) * RandomNumber.xyz + RandomNumber.w);
}

// @param xy should be a integer position (e.g. pixel position on the screen), repeats each 128x128 pixels
// similar to a texture lookup but is only ALU
// ~13 ALU operations (3 frac, 6 *, 4 mad)
float PseudoRandom(float2 xy)
{
	float2 pos = frac(xy / 128.0f) * 128.0f + float2(-64.340622f, -72.465622f);
	
	// found by experimentation
	return frac(dot(pos.xyx * pos.xyy, float3(20.390625f, 60.703125f, 2.4281209f)));
}

// high frequency dither pattern appearing almost random without banding steps
//note: from "NEXT GENERATION POST PROCESSING IN CALL OF DUTY: ADVANCED WARFARE"
//      http://advances.realtimerendering.com/s2014/index.html
// Epic extended by FrameId
// ~7 ALU operations (2 frac, 3 mad, 2 *)
// @return 0..1
float InterleavedGradientNoise( float2 uv, float FrameId )
{
	// magic values are found by experimentation
	uv += FrameId * (float2(47, 17) * 0.695f);

    const float3 magic = float3( 0.06711056f, 0.00583715f, 52.9829189f );
    return frac(magic.z * frac(dot(uv, magic.xy)));
}

// [0, 1[
// ~10 ALU operations (2 frac, 5 *, 3 mad)
float RandFast( uint2 PixelPos, float Magic = 3571.0 )
{
	float2 Random2 = ( 1.0 / 4320.0 ) * PixelPos + float2( 0.25, 0.0 );
	float Random = frac( dot( Random2 * Random2, Magic ) );
	Random = frac( Random * Random * (2 * Magic) );
	return Random;
}

// This is the largest prime < 2^12 so s*s will fit in a 24-bit floating point mantissa
#define BBS_PRIME24 4093

// Blum-Blum-Shub-inspired pseudo random number generator
// http://www.umbc.edu/~olano/papers/mNoise.pdf
// real BBS uses ((s*s) mod M) with bignums and M as the product of two huge Blum primes
// instead, we use a single prime M just small enough not to overflow
// note that the above paper used 61, which fits in a half, but is unusably bad
// @param Integer valued floating point seed
// @return random number in range [0,1)
// ~8 ALU operations (5 *, 3 frac)
float RandBBSfloat(float seed)
{
	float s = frac(seed / BBS_PRIME24);
	s = frac(s * s * BBS_PRIME24);
	s = frac(s * s * BBS_PRIME24);
	return s;
}

// 3D random number generator inspired by PCGs (permuted congruential generator)
// Using a **simple** Feistel cipher in place of the usual xor shift permutation step
// @param v = 3D integer coordinate
// @return three elements w/ 16 random bits each (0-0xffff).
// ~8 ALU operations for result.x    (7 mad, 1 >>)
// ~10 ALU operations for result.xy  (8 mad, 2 >>)
// ~12 ALU operations for result.xyz (9 mad, 3 >>)
uint3 Rand3DPCG16(int3 p)
{
	// taking a signed int then reinterpreting as unsigned gives good behavior for negatives
	uint3 v = uint3(p);

	// Linear congruential step. These LCG constants are from Numerical Recipies
	// For additional #'s, PCG would do multiple LCG steps and scramble each on output
	// So v here is the RNG state
	v = v * 1664525u + 1013904223u;

	// PCG uses xorshift for the final shuffle, but it is expensive (and cheap
	// versions of xorshift have visible artifacts). Instead, use simple MAD Feistel steps
	//
	// Feistel ciphers divide the state into separate parts (usually by bits)
	// then apply a series of permutation steps one part at a time. The permutations
	// use a reversible operation (usually ^) to part being updated with the result of
	// a permutation function on the other parts and the key.
	//
	// In this case, I'm using v.x, v.y and v.z as the parts, using + instead of ^ for
	// the combination function, and just multiplying the other two parts (no key) for 
	// the permutation function.
	//
	// That gives a simple mad per round.
	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;
	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;

	// only top 16 bits are well shuffled
	return v >> 16u;
}

// 3D random number generator inspired by PCGs (permuted congruential generator)
// Using a **simple** Feistel cipher in place of the usual xor shift permutation step
// @param v = 3D integer coordinate
// @return three elements w/ 32 random bits each (0-0xffffffff).
// ~12 ALU operations for result.x   (10 mad, 3 >>)
// ~14 ALU operations for result.xy  (11 mad, 3 >>)
// ~15 ALU operations for result.xyz (12 mad, 3 >>)
uint3 Rand3DPCG32(int3 p)
{
	// taking a signed int then reinterpreting as unsigned gives good behavior for negatives
	uint3 v = uint3(p);

	// Linear congruential step.
	v = v * 1664525u + 1013904223u;

	// swapping low and high bits makes all 32 bits pretty good
	v = v * (1u << 16u) + (v >> 16u);

	// final shuffle
	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;
	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;

	return v;
}



// 4D random number generator inspired by PCGs (permuted congruential generator)
// Using a **simple** Feistel cipher in place of the usual xor shift permutation step
// @param v = 4D integer coordinate
// @return four elements w/ 32 random bits each (0-0xffffffff).
// ~12 ALU operations for result.x   (10 mad, 3 >>)
// ~14 ALU operations for result.xy  (11 mad, 3 >>)
// ~15 ALU operations for result.xyz (12 mad, 3 >>)
uint4 Rand4DPCG32(int4 p)
{
	// taking a signed int then reinterpreting as unsigned gives good behavior for negatives
	uint4 v = uint4(p);

	// Linear congruential step.
	v = v * 1664525u + 1013904223u;

	// swapping low and high bits makes all 32 bits pretty good
	v = v * (1u << 16u) + (v >> 16u);

	// final shuffle
	v.x += v.y*v.w;
	v.y += v.z*v.x;
	v.z += v.x*v.y;
	v.w += v.y*v.z;
	v.x += v.y*v.w;
	v.y += v.z*v.x;
	v.z += v.x*v.y;
	v.w += v.y*v.z;

	return v;
}




/**
 * Find good arbitrary axis vectors to represent U and V axes of a plane,
 * given just the normal. Ported from UnMath.h
 */
void FindBestAxisVectors(float3 In, out float3 Axis1, out float3 Axis2 )
{
	const float3 N = abs(In);

	// Find best basis vectors.
	if( N.z > N.x && N.z > N.y )
	{
		Axis1 = float3(1, 0, 0);
	}
	else
	{
		Axis1 = float3(0, 0, 1);
	}

	Axis1 = normalize(Axis1 - In * dot(Axis1, In));
	Axis2 = cross(Axis1, In);
}

// References for noise:
//
// Improved Perlin noise
//   http://mrl.nyu.edu/~perlin/noise/
//   http://http.developer.nvidia.com/GPUGems/gpugems_ch05.html
// Modified Noise for Evaluation on Graphics Hardware
//   http://www.csee.umbc.edu/~olano/papers/mNoise.pdf
// Perlin Noise
//   http://mrl.nyu.edu/~perlin/doc/oscar.html
// Fast Gradient Noise
//   http://prettyprocs.wordpress.com/2012/10/20/fast-perlin-noise


// -------- ALU based method ---------

/*
 * Pseudo random number generator, based on "TEA, a tiny Encrytion Algorithm"
 * http://citeseer.ist.psu.edu/viewdoc/download?doi=10.1.1.45.281&rep=rep1&type=pdf
 * http://www.umbc.edu/~olano/papers/index.html#GPUTEA
 * @param v - old seed (full 32bit range)
 * @param IterationCount - >=1, bigger numbers cost more performance but improve quality
 * @return new seed
 */
uint2 ScrambleTEA(uint2 v, uint IterationCount = 3)
{
	// Start with some random data (numbers can be arbitrary but those have been used by others and seem to work well)
	uint k[4] ={ 0xA341316Cu , 0xC8013EA4u , 0xAD90777Du , 0x7E95761Eu };
	
	uint y = v[0];
	uint z = v[1];
	uint sum = 0;
	
	[ROOL]
	for(uint i = 0; i < IterationCount; ++i)
	{
		sum += 0x9e3779b9;
		y += ((z << 4u) + k[0]) ^ (z + sum) ^ ((z >> 5u) + k[1]);
		z += ((y << 4u) + k[2]) ^ (y + sum) ^ ((y >> 5u) + k[3]);
	}

	return uint2(y, z);
}

// Wraps noise for tiling texture creation
// @param v = unwrapped texture parameter
// @param bTiling = true to tile, false to not tile
// @param RepeatSize = number of units before repeating
// @return either original or wrapped coord
float3 NoiseTileWrap(float3 v,  bool bTiling, float RepeatSize)
{
	return bTiling ? (frac(v / RepeatSize) * RepeatSize) : v;
}

// Evaluate polynomial to get smooth transitions for Perlin noise
// only needed by Perlin functions in this file
// scalar(per component): 2 add, 5 mul
float4 PerlinRamp(float4 t)
{
	return t * t * t * (t * (t * 6 - 15) + 10); 
}

// Analytical derivative of the PerlinRamp polynomial
// only needed by Perlin functions in this file
// scalar(per component): 2 add, 5 mul
float4 PerlinRampDerivative(float4 t)
{
	return t * t * (t * (t * 30 - 60) + 30);
}

#define MGradientMask int3(0x8000, 0x4000, 0x2000)
#define MGradientScale float3(1. / 0x4000, 1. / 0x2000, 1. / 0x1000)
// Modified noise gradient term
// @param seed - random seed for integer lattice position
// @param offset - [-1,1] offset of evaluation point from lattice point
// @return gradient direction (xyz) and contribution (w) from this lattice point
float4 MGradient(int seed, float3 offset)
{
	uint rand = Rand3DPCG16(int3(seed,0,0)).x;
	float3 direction = float3(rand.xxx & MGradientMask) * MGradientScale - 1;
	return float4(direction, dot(direction, offset));
}

// compute Perlin and related noise corner seed values
// @param v = 3D noise argument, use float3(x,y,0) for 2D or float3(x,0,0) for 1D
// @param bTiling = true to return seed values for a repeating noise pattern
// @param RepeatSize = integer units before tiling in each dimension
// @param seed000-seed111 = hash function seeds for the eight corners
// @return fractional part of v
float3 NoiseSeeds(float3 v, bool bTiling, float RepeatSize,
	out float seed000, out float seed001, out float seed010, out float seed011,
	out float seed100, out float seed101, out float seed110, out float seed111)
{
	float3 fv = frac(v);
	float3 iv = floor(v);

	const float3 primes = float3(19, 47, 101);

	if (bTiling)
	{	// can't algebraically combine with primes
		seed000 = dot(primes, NoiseTileWrap(iv, true, RepeatSize));
		seed100 = dot(primes, NoiseTileWrap(iv + float3(1, 0, 0), true, RepeatSize));
		seed010 = dot(primes, NoiseTileWrap(iv + float3(0, 1, 0), true, RepeatSize));
		seed110 = dot(primes, NoiseTileWrap(iv + float3(1, 1, 0), true, RepeatSize));
		seed001 = dot(primes, NoiseTileWrap(iv + float3(0, 0, 1), true, RepeatSize));
		seed101 = dot(primes, NoiseTileWrap(iv + float3(1, 0, 1), true, RepeatSize));
		seed011 = dot(primes, NoiseTileWrap(iv + float3(0, 1, 1), true, RepeatSize));
		seed111 = dot(primes, NoiseTileWrap(iv + float3(1, 1, 1), true, RepeatSize));
	}
	else
	{	// get to combine offsets with multiplication by primes in this case
		seed000 = dot(iv, primes);
		seed100 = seed000 + primes.x;
		seed010 = seed000 + primes.y;
		seed110 = seed100 + primes.y;
		seed001 = seed000 + primes.z;
		seed101 = seed100 + primes.z;
		seed011 = seed010 + primes.z;
		seed111 = seed110 + primes.z;
	}

	return fv;
}

// Perlin-style "Modified Noise"
// http://www.umbc.edu/~olano/papers/index.html#mNoise
// @param v = 3D noise argument, use float3(x,y,0) for 2D or float3(x,0,0) for 1D
// @param bTiling = repeat noise pattern
// @param RepeatSize = integer units before tiling in each dimension
// @return random number in the range -1 .. 1
float GradientNoise3D_ALU(float3 v, bool bTiling, float RepeatSize)
{
	float seed000, seed001, seed010, seed011, seed100, seed101, seed110, seed111;
	float3 fv = NoiseSeeds(v, bTiling, RepeatSize, seed000, seed001, seed010, seed011, seed100, seed101, seed110, seed111);

	float rand000 = MGradient(int(seed000), fv - float3(0, 0, 0)).w;
	float rand100 = MGradient(int(seed100), fv - float3(1, 0, 0)).w;
	float rand010 = MGradient(int(seed010), fv - float3(0, 1, 0)).w;
	float rand110 = MGradient(int(seed110), fv - float3(1, 1, 0)).w;
	float rand001 = MGradient(int(seed001), fv - float3(0, 0, 1)).w;
	float rand101 = MGradient(int(seed101), fv - float3(1, 0, 1)).w;
	float rand011 = MGradient(int(seed011), fv - float3(0, 1, 1)).w;
	float rand111 = MGradient(int(seed111), fv - float3(1, 1, 1)).w;

	float3 Weights = PerlinRamp(float4(fv, 0)).xyz;

	float i = lerp(lerp(rand000, rand100, Weights.x), lerp(rand010, rand110, Weights.x), Weights.y);
	float j = lerp(lerp(rand001, rand101, Weights.x), lerp(rand011, rand111, Weights.x), Weights.y);
	return lerp(i, j, Weights.z).x;
}

// Coordinates for corners of a Simplex tetrahedron
// Based on McEwan et al., Efficient computation of noise in GLSL, JGT 2011
// @param v = 3D noise argument
// @return 4 corner locations
float4x3 SimplexCorners(float3 v)
{
	// find base corner by skewing to tetrahedral space and back
	float3 tet = floor(v + v.x/3 + v.y/3 + v.z/3);
	float3 base = tet - tet.x/6 - tet.y/6 - tet.z/6;
	float3 f = v - base;

	// Find offsets to other corners (McEwan did this in tetrahedral space,
	// but since skew is along x=y=z axis, this works in Euclidean space too.)
	float3 g = step(f.yzx, f.xyz), h = 1 - g.zxy;
	float3 a1 = min(g, h) - 1. / 6., a2 = max(g, h) - 1. / 3.;

	// four corners
	return float4x3(base, base + a1, base + a2, base + 0.5);
}

// Improved smoothing function for simplex noise
// @param f = fractional distance to four tetrahedral corners
// @return weight for each corner
float4 SimplexSmooth(float4x3 f)
{
	const float scale = 1024. / 375.;	// scale factor to make noise -1..1
	float4 d = float4(dot(f[0], f[0]), dot(f[1], f[1]), dot(f[2], f[2]), dot(f[3], f[3]));
	float4 s = saturate(2 * d);
	return (1 * scale + s*(-3 * scale + s*(3 * scale - s*scale)));
}

// Derivative of simplex noise smoothing function
// @param f = fractional distanc eto four tetrahedral corners
// @return derivative of smoothing function for each corner by x, y and z
float3x4 SimplexDSmooth(float4x3 f)
{
	const float scale = 1024. / 375.;	// scale factor to make noise -1..1
	float4 d = float4(dot(f[0], f[0]), dot(f[1], f[1]), dot(f[2], f[2]), dot(f[3], f[3]));
	float4 s = saturate(2 * d);
	s = -12 * scale + s*(24 * scale - s * 12 * scale);

	return float3x4(
		s * float4(f[0][0], f[1][0], f[2][0], f[3][0]),
		s * float4(f[0][1], f[1][1], f[2][1], f[3][1]),
		s * float4(f[0][2], f[1][2], f[2][2], f[3][2]));
}

// Simplex noise and its Jacobian derivative
// @param v = 3D noise argument
// @param bTiling = whether to repeat noise pattern
// @param RepeatSize = integer units before tiling in each dimension, must be a multiple of 3
// @return float3x3 Jacobian in J[*].xyz, vector noise in J[*].w
//     J[0].w, J[1].w, J[2].w is a Perlin-style simplex noise with vector output, e.g. (Nx, Ny, Nz)
//     J[i].x is X derivative of the i'th component of the noise so J[2].x is dNz/dx
// You can use this to compute the noise, gradient, curl, or divergence:
//   float3x4 J = JacobianSimplex_ALU(...);
//   float3 VNoise = float3(J[0].w, J[1].w, J[2].w);	// 3D noise
//   float3 Grad = J[0].xyz;							// gradient of J[0].w
//   float3 Curl = float3(J[1][2]-J[2][1], J[2][0]-J[0][2], J[0][1]-J[1][2]);
//   float Div = J[0][0]+J[1][1]+J[2][2];
// All of these are confirmed to compile out all unneeded terms.
// So Grad of X doesn't compute Y or Z components, and VNoise doesn't do any of the derivative computation.
float3x4 JacobianSimplex_ALU(float3 v, bool bTiling, float RepeatSize)
{
	// corners of tetrahedron
	float4x3 T = SimplexCorners(v);
	uint3 rand;
	float4x3 gvec[3], fv;
	float3x4 grad;

	// processing of tetrahedral vertices, unrolled
	// to compute gradient at each corner
	fv[0] = v - T[0];
	rand = Rand3DPCG16(int3(floor(NoiseTileWrap(6 * T[0] + 0.5, bTiling, RepeatSize))));
	gvec[0][0] = float3(rand.xxx & MGradientMask) * MGradientScale - 1;
	gvec[1][0] = float3(rand.yyy & MGradientMask) * MGradientScale - 1;
	gvec[2][0] = float3(rand.zzz & MGradientMask) * MGradientScale - 1;
	grad[0][0] = dot(gvec[0][0], fv[0]);
	grad[1][0] = dot(gvec[1][0], fv[0]);
	grad[2][0] = dot(gvec[2][0], fv[0]);

	fv[1] = v - T[1];
	rand = Rand3DPCG16(int3(floor(NoiseTileWrap(6 * T[1] + 0.5, bTiling, RepeatSize))));
	gvec[0][1] = float3(rand.xxx & MGradientMask) * MGradientScale - 1;
	gvec[1][1] = float3(rand.yyy & MGradientMask) * MGradientScale - 1;
	gvec[2][1] = float3(rand.zzz & MGradientMask) * MGradientScale - 1;
	grad[0][1] = dot(gvec[0][1], fv[1]);
	grad[1][1] = dot(gvec[1][1], fv[1]);
	grad[2][1] = dot(gvec[2][1], fv[1]);

	fv[2] = v - T[2];
	rand = Rand3DPCG16(int3(floor(NoiseTileWrap(6 * T[2] + 0.5, bTiling, RepeatSize))));
	gvec[0][2] = float3(rand.xxx & MGradientMask) * MGradientScale - 1;
	gvec[1][2] = float3(rand.yyy & MGradientMask) * MGradientScale - 1;
	gvec[2][2] = float3(rand.zzz & MGradientMask) * MGradientScale - 1;
	grad[0][2] = dot(gvec[0][2], fv[2]);
	grad[1][2] = dot(gvec[1][2], fv[2]);
	grad[2][2] = dot(gvec[2][2], fv[2]);

	fv[3] = v - T[3];
	rand = Rand3DPCG16(int3(floor(NoiseTileWrap(6 * T[3] + 0.5, bTiling, RepeatSize))));
	gvec[0][3] = float3(rand.xxx & MGradientMask) * MGradientScale - 1;
	gvec[1][3] = float3(rand.yyy & MGradientMask) * MGradientScale - 1;
	gvec[2][3] = float3(rand.zzz & MGradientMask) * MGradientScale - 1;
	grad[0][3] = dot(gvec[0][3], fv[3]);
	grad[1][3] = dot(gvec[1][3], fv[3]);
	grad[2][3] = dot(gvec[2][3], fv[3]);

	// blend gradients
	float4 sv = SimplexSmooth(fv);
	float3x4 ds = SimplexDSmooth(fv);

	float3x4 jacobian;
	jacobian[0] = float4(mul(sv, gvec[0]) + mul(ds, grad[0]), dot(sv, grad[0]));
	jacobian[1] = float4(mul(sv, gvec[1]) + mul(ds, grad[1]), dot(sv, grad[1]));
	jacobian[2] = float4(mul(sv, gvec[2]) + mul(ds, grad[2]), dot(sv, grad[2]));

	return jacobian;
}

// 3D value noise - used to be incorrectly called Perlin noise
// @param v = 3D noise argument, use float3(x,y,0) for 2D or float3(x,0,0) for 1D
// @param bTiling = repeat noise pattern
// @param RepeatSize = integer units before tiling in each dimension
// @return random number in the range -1 .. 1
float ValueNoise3D_ALU(float3 v, bool bTiling, float RepeatSize)
{
	float seed000, seed001, seed010, seed011, seed100, seed101, seed110, seed111;
	float3 fv = NoiseSeeds(v, bTiling, RepeatSize, seed000, seed001, seed010, seed011, seed100, seed101, seed110, seed111);

	float rand000 = RandBBSfloat(seed000) * 2 - 1;
	float rand100 = RandBBSfloat(seed100) * 2 - 1;
	float rand010 = RandBBSfloat(seed010) * 2 - 1;
	float rand110 = RandBBSfloat(seed110) * 2 - 1;
	float rand001 = RandBBSfloat(seed001) * 2 - 1;
	float rand101 = RandBBSfloat(seed101) * 2 - 1;
	float rand011 = RandBBSfloat(seed011) * 2 - 1;
	float rand111 = RandBBSfloat(seed111) * 2 - 1;
	
	float3 Weights = PerlinRamp(float4(fv, 0)).xyz;
	
	float i = lerp(lerp(rand000, rand100, Weights.x), lerp(rand010, rand110, Weights.x), Weights.y);
	float j = lerp(lerp(rand001, rand101, Weights.x), lerp(rand011, rand111, Weights.x), Weights.y);
	return lerp(i, j, Weights.z).x;
}


#endif
