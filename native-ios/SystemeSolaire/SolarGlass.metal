#include <metal_stdlib>
using namespace metal;

// Distance signée d'un rectangle arrondi continu. Les capsules et les cercles
// sont le même volume avec un rayon égal à la moitié du plus petit côté.
static float roundedRectangleSDF(float2 point, float2 halfSize, float radius) {
    float safeRadius = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    float2 q = abs(point) - halfSize + safeRadius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - safeRadius;
}

static float2 roundedRectangleNormal(float2 point, float2 halfSize, float radius) {
    constexpr float epsilon = 0.75;
    float dx = roundedRectangleSDF(point + float2(epsilon, 0.0), halfSize, radius)
             - roundedRectangleSDF(point - float2(epsilon, 0.0), halfSize, radius);
    float dy = roundedRectangleSDF(point + float2(0.0, epsilon), halfSize, radius)
             - roundedRectangleSDF(point - float2(0.0, epsilon), halfSize, radius);
    float2 gradient = float2(dx, dy);
    return length_squared(gradient) > 0.0001 ? normalize(gradient) : float2(0.0, -1.0);
}

[[ stitchable ]] half4 solarGlass(
    float2 position,
    float2 size,
    float cornerRadius,
    float2 lightDirection,
    float intensity,
    float2 touchPosition,
    float touchIntensity,
    half4 violetColor,
    half4 accentColor,
    half4 warmColor
) {
    float2 halfSize = max(size * 0.5, float2(1.0));
    float2 point = position - halfSize;
    float signedDistance = roundedRectangleSDF(point, halfSize, cornerRadius);
    float inside = 1.0 - smoothstep(-0.12, 0.45, signedDistance);
    float depth = max(0.0, -signedDistance);

    // La normale vient du SDF mais la surface reste plane. Seule la tranche
    // reçoit la lumière : pas de dôme, pas de volume gonflé.
    float2 edgeNormal = roundedRectangleNormal(point, halfSize, cornerRadius);
    float2 safeLight = length_squared(lightDirection) > 0.0001
        ? normalize(lightDirection)
        : float2(0.0, -1.0);
    float facing = saturate(dot(edgeNormal, safeLight));

    // Deux lignes sous-pixel donnent une tranche de plaque : une arête nette,
    // puis une réflexion interne beaucoup plus faible. Leur faible largeur est
    // ce qui sépare visuellement le verre du plastique moulé.
    float outerEdge = exp(-depth * depth / 0.42) * inside;
    float innerDepth = depth - 1.50;
    float innerEdge = exp(-innerDepth * innerDepth / 0.22) * inside;
    float directional = pow(facing, 7.0);
    float glint = (outerEdge * 0.42 + innerEdge * 0.09)
        * directional * intensity;
    float grazing = outerEdge * facing * 0.035 * intensity;

    // Le toucher est une seconde source locale. Tous les composants reçoivent
    // la même position, donc un bouton pressé éclaire légèrement ses voisins.
    float touchRadius = max(54.0, min(size.x, size.y) * 1.25);
    float touchDistance = distance(position, touchPosition) / touchRadius;
    float touchFocus = exp(-touchDistance * touchDistance * 4.4) * touchIntensity;
    float touchGlow = touchFocus * outerEdge;

    // Dispersion contenue dans l'épaisseur du verre. Les trois raies reprennent
    // la charte de l'app et restent séparées de quelques dixièmes de point :
    // elles se lisent comme un prisme, jamais comme un contour arc-en-ciel.
    float warmDepth = depth - 0.42;
    float accentDepth = depth - 1.02;
    float violetDepth = depth - 1.62;
    float warmBand = exp(-warmDepth * warmDepth / 0.19) * inside;
    float accentBand = exp(-accentDepth * accentDepth / 0.19) * inside;
    float violetBand = exp(-violetDepth * violetDepth / 0.19) * inside;
    float prismDirection = pow(facing, 2.8);
    float prismStrength = (0.17 + touchFocus * 0.14)
        * prismDirection * intensity;

    float3 prismColor = float3(warmColor.rgb) * warmBand
                      + float3(accentColor.rgb) * accentBand
                      + float3(violetColor.rgb) * violetBand;
    prismColor *= prismStrength;
    float prismAlpha = saturate((warmBand + accentBand + violetBand)
        * prismStrength * 0.82);

    float neutralAlpha = saturate(glint + grazing + touchGlow * 0.08);
    float alpha = saturate(neutralAlpha + prismAlpha);
    float3 neutralWhite = float3(0.96, 0.97, 1.0);
    float3 color = neutralWhite * neutralAlpha + prismColor;

    return half4(half3(color), half(alpha));
}
