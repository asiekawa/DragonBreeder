float4x4 WorldViewProjection;
float4x4 InvertViewProjection;
float4x4 LightViewProjection;
float3 LightPosition;
float LightDistance;
float LightIntensity = 1;
float4 Color;
float3 Camera;
Texture2D NormalMap;
Texture2D DepthMap;
SamplerState TexSampler
{
    Filter = MIN_MAG_MIP_POINT;

};

struct VS_IN
{
    float4 Position: POSITION;
	uint VertexID: SV_VertexID;
};
struct VS_OUT
{
    float4 position : SV_POSITION;		//Position
	float2 texcoord : TexCoord0;
};

#define kPI 3.1415926536f
VS_OUT VSfullScreen( VS_IN input)
{
    VS_OUT  Out;
	Out.position = float4(input.Position.xyz,1);

	Out.texcoord.x = (1+input.Position.x)*0.5f;
	Out.texcoord.y = (1-input.Position.y)*0.5f;
	return Out;
}
VS_OUT VS( VS_IN input)
{
    VS_OUT  Out;
	Out.texcoord.x = (1+input.Position.x)*0.5f;
	Out.texcoord.y = (1-input.Position.y)*0.5f;
	Out.position = mul(input.Position, WorldViewProjection);

	return Out;
}

half3 decode (half3 enc)
{
    half2 ang = enc*2-1;
    half2 scth;
    sincos(ang.x * kPI, scth.x, scth.y);
    half2 scphi = half2(sqrt(1.0 - ang.y*ang.y), ang.y);
    return half3(scth.y*scphi.x, scth.x*scphi.x, scphi.y);
}
float3 DepthToPosition(float2 TexCoord, float d, float4x4 InvertViewProjection)
{
	float4 position;
	if(d==-1)
		return -1;
	position.x =   TexCoord.x * 2.0f - 1.0f;
	position.y = -(TexCoord.y * 2.0f - 1.0f);
	position.z = d;
	position.w = 1.0f;
	position = mul(position, InvertViewProjection);
	position /= position.w;
	return position;
}
float4 Phong(float3 LightDirection, float3 position, float3 Normal)
{
	float NdL = saturate(dot(LightDirection, Normal));
	float3 H = normalize(normalize(Camera - position) + LightDirection);
	float NdH =  pow( saturate( dot( H, Normal ) ), 60.0f );
	float4 result = saturate(1 -  (distance(position, LightPosition) / LightDistance));
	result *= LightIntensity*float4(NdL * Color.rgb, NdH);
	return result;
}
float4 Phong(float3 LightDirection, float3 position, float3 Normal, float specularExp, float specularInt)
{
	float NdL = saturate(dot(LightDirection, Normal));
	float3 H = normalize(normalize(Camera - position) + LightDirection);
	float NdH =  specularInt*pow( saturate( dot( H, Normal ) ), 24*specularExp );
	float4 result = saturate(1 - (distance(position, LightPosition) / LightDistance));
	result *= LightIntensity*float4(NdL * Color.rgb, NdH);
	return result;
}
float4 PS( VS_OUT input ) : SV_TARGET
{
	float4 result = 0;
	float2 TexCoord = input.position.xy/float2(1280,720);
	float d = DepthMap.Sample(TexSampler, TexCoord);
	if(d<=0)
	{
		return (1,0,0,0);
		return 0;
	}
	float3 position = DepthToPosition(TexCoord, d, InvertViewProjection);
	float3 normal = decode(float3(NormalMap.Sample(TexSampler, TexCoord).rg,1));
	float3 direction = normalize(LightPosition-position.xyz);
	 result = Phong(direction, position.xyz, normal);
	 return result;
}

DepthStencilState DisableDepth
{
    DepthEnable = FALSE;
    DepthWriteMask = ALL;
};

technique11 PointLight
{
    pass P0
    {
		 SetDepthStencilState( DisableDepth, 0 );
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetHullShader( NULL );
        SetDomainShader( NULL );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS() ) );
    }
}
