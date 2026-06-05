/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_SCOPE_VISUAL_PARAMETERS_H
#define PRETTYSCOPE_SCOPE_VISUAL_PARAMETERS_H

#include <algorithm>
#include <array>
#include <cstdint>
#include <span>
#include <string_view>

namespace baconpaul::sidequest_ns
{
inline constexpr uint32_t kVisualParameterStateVersion = 1;

struct VisualParameterStableId
{
    uint32_t value{};
};

struct VisualFloatParameterDescriptor
{
    std::string_view id;
    VisualParameterStableId stableId;
    std::string_view displayName;
    std::string_view category;
    float defaultValue{};
    float minValue{};
    float midValue{};
    float maxValue{};
    bool automatable{true};
    bool visible{true};
};

inline constexpr std::string_view kPhosphorDecayVisualParameterId{"phosphor_decay"};
inline constexpr std::string_view kBeamIntensityVisualParameterId{"beam_intensity"};
inline constexpr std::string_view kInputGainVisualParameterId{"input_gain"};
inline constexpr std::string_view kTimeScaleVisualParameterId{"time_scale"};
inline constexpr std::string_view kDiscontinuitySkipSamplesVisualParameterId{
    "discontinuity_skip_samples"};
inline constexpr std::string_view kPhosphorFastDecayVisualParameterId{"phosphor_fast_decay"};
inline constexpr std::string_view kPhosphorAfterglowVisualParameterId{"phosphor_afterglow"};
inline constexpr std::string_view kBeamGlowStrengthVisualParameterId{"beam_glow_strength"};
inline constexpr std::string_view kBeamTraceWidthVisualParameterId{"beam_trace_width"};
inline constexpr std::string_view kBeamGlowWidthVisualParameterId{"beam_glow_width"};
inline constexpr std::string_view kDot1IntensityVisualParameterId{"dot1_intensity"};
inline constexpr std::string_view kDot1SizeVisualParameterId{"dot1_size"};
inline constexpr std::string_view kDot1HaloVisualParameterId{"dot1_halo"};
inline constexpr std::string_view kDot1ImageMixVisualParameterId{"dot1_image_mix"};
inline constexpr std::string_view kDot1RotationVisualParameterId{"dot1_rotation"};
inline constexpr std::string_view kDot1AspectVisualParameterId{"dot1_aspect"};
inline constexpr std::string_view kDot2IntensityVisualParameterId{"dot2_intensity"};
inline constexpr std::string_view kDot2SizeVisualParameterId{"dot2_size"};
inline constexpr std::string_view kDot2HaloVisualParameterId{"dot2_halo"};
inline constexpr std::string_view kDot2ImageMixVisualParameterId{"dot2_image_mix"};
inline constexpr std::string_view kDot2RotationVisualParameterId{"dot2_rotation"};
inline constexpr std::string_view kDot2AspectVisualParameterId{"dot2_aspect"};
inline constexpr std::string_view kDotOverallIntensityVisualParameterId{"dot_overall_intensity"};
inline constexpr std::string_view kDotOverallSizeVisualParameterId{"dot_overall_size"};
inline constexpr std::string_view kDotOverallHaloVisualParameterId{"dot_overall_halo"};
inline constexpr std::string_view kDotOverallImageMixVisualParameterId{"dot_overall_image_mix"};
inline constexpr std::string_view kScreenBurnPersistenceVisualParameterId{"screen_burn_persistence"};
inline constexpr std::string_view kScreenBurnFastDecayVisualParameterId{"screen_burn_fast_decay"};
inline constexpr std::string_view kScreenBurnAfterglowVisualParameterId{"screen_burn_afterglow"};
inline constexpr std::string_view kScreenBurnFloorFadeVisualParameterId{"screen_burn_floor_fade"};

inline constexpr std::array<VisualFloatParameterDescriptor, 30> kVisualFloatParameters{{
    {kPhosphorDecayVisualParameterId, {1000}, "Phosphor Decay", "Phosphor", 0.98f, 0.80f,
     0.95f, 0.999f, true, true},
    {kBeamIntensityVisualParameterId, {1001}, "Beam Intensity", "Beam", 1.6f, 0.0f, 1.0f,
     4.0f, true, true},
    {kInputGainVisualParameterId, {1002}, "Input Gain", "Signal", 1.0f, 0.1f, 1.0f, 32.0f,
     true, true},
    {kTimeScaleVisualParameterId, {1003}, "Time Scale", "Signal", 1.0f, 0.25f, 1.0f, 4.0f,
     true, true},
    {kDiscontinuitySkipSamplesVisualParameterId, {1029}, "Skip Samples", "Signal", 1.0f,
     0.0f, 1.0f, 2.0f, true, true},
    {kPhosphorFastDecayVisualParameterId, {1004}, "Fast Decay", "Phosphor", 0.25f, 0.0f,
     0.25f, 1.0f, true, true},
    {kPhosphorAfterglowVisualParameterId, {1005}, "Afterglow", "Phosphor", 0.95f, 0.0f,
     0.80f, 1.0f, true, true},
    {kBeamGlowStrengthVisualParameterId, {1006}, "Glow Strength", "Beam", 0.35f, 0.0f,
     0.35f, 2.0f, true, true},
    {kBeamTraceWidthVisualParameterId, {1007}, "Trace Width", "Beam", 2.0f, 0.5f,
     2.0f, 8.0f, true, true},
    {kBeamGlowWidthVisualParameterId, {1008}, "Glow Width", "Beam", 7.0f, 1.0f,
     7.0f, 24.0f, true, true},
    {kDot1IntensityVisualParameterId, {1009}, "Dot 1 Intensity", "Dot 1", 1.0f, 0.0f,
     1.0f, 4.0f, true, true},
    {kDot1SizeVisualParameterId, {1010}, "Dot 1 Size", "Dot 1", 2.0f, 0.25f, 2.0f,
     32.0f, true, true},
    {kDot1HaloVisualParameterId, {1011}, "Dot 1 Halo", "Dot 1", 0.35f, 0.0f, 0.35f,
     4.0f, true, true},
    {kDot1ImageMixVisualParameterId, {1012}, "Dot 1 Image Mix", "Dot 1", 0.0f, 0.0f,
     0.5f, 1.0f, true, true},
    {kDot1RotationVisualParameterId, {1013}, "Dot 1 Rotation", "Dot 1", 0.0f, -180.0f,
     0.0f, 180.0f, true, true},
    {kDot1AspectVisualParameterId, {1014}, "Dot 1 Aspect", "Dot 1", 1.0f, 0.1f,
     1.0f, 10.0f, true, true},
    {kDot2IntensityVisualParameterId, {1015}, "Dot 2 Intensity", "Dot 2", 0.45f, 0.0f,
     1.0f, 4.0f, true, true},
    {kDot2SizeVisualParameterId, {1016}, "Dot 2 Size", "Dot 2", 6.0f, 0.25f, 4.0f,
     64.0f, true, true},
    {kDot2HaloVisualParameterId, {1017}, "Dot 2 Halo", "Dot 2", 0.65f, 0.0f, 0.5f,
     4.0f, true, true},
    {kDot2ImageMixVisualParameterId, {1018}, "Dot 2 Image Mix", "Dot 2", 0.0f, 0.0f,
     0.5f, 1.0f, true, true},
    {kDot2RotationVisualParameterId, {1019}, "Dot 2 Rotation", "Dot 2", 0.0f, -180.0f,
     0.0f, 180.0f, true, true},
    {kDot2AspectVisualParameterId, {1020}, "Dot 2 Aspect", "Dot 2", 1.0f, 0.1f,
     1.0f, 10.0f, true, true},
    {kDotOverallIntensityVisualParameterId, {1021}, "Overall Dot Intensity", "Dot Overall",
     1.0f, 0.0f, 1.0f, 4.0f, true, true},
    {kDotOverallSizeVisualParameterId, {1022}, "Overall Dot Size", "Dot Overall", 1.0f,
     0.1f, 1.0f, 8.0f, true, true},
    {kDotOverallHaloVisualParameterId, {1023}, "Overall Dot Halo", "Dot Overall", 1.0f,
     0.0f, 1.0f, 4.0f, true, true},
    {kDotOverallImageMixVisualParameterId, {1024}, "Overall Dot Image Mix", "Dot Overall",
     1.0f, 0.0f, 1.0f, 1.0f, true, true},
    {kScreenBurnPersistenceVisualParameterId, {1025}, "Screen Burn Persistence",
     "Screen Burn", 0.98f, 0.80f, 0.95f, 0.9995f, true, true},
    {kScreenBurnFastDecayVisualParameterId, {1026}, "Screen Burn Fast Decay",
     "Screen Burn", 0.25f, 0.0f, 0.25f, 1.0f, true, true},
    {kScreenBurnAfterglowVisualParameterId, {1027}, "Screen Burn Afterglow", "Screen Burn",
     0.95f, 0.0f, 0.8f, 1.0f, true, true},
    {kScreenBurnFloorFadeVisualParameterId, {1028}, "Screen Burn Floor Fade", "Screen Burn",
     0.00035f, 0.0f, 0.0005f, 0.01f, true, true},
}};

inline std::span<const VisualFloatParameterDescriptor> visualFloatParameters()
{
    return kVisualFloatParameters;
}

inline const VisualFloatParameterDescriptor *visualFloatParameterByStableId(uint32_t stableId)
{
    for (const auto &descriptor : visualFloatParameters())
    {
        if (descriptor.stableId.value == stableId)
        {
            return &descriptor;
        }
    }

    return nullptr;
}

inline const VisualFloatParameterDescriptor *visualFloatParameterById(std::string_view id)
{
    for (const auto &descriptor : visualFloatParameters())
    {
        if (descriptor.id == id)
        {
            return &descriptor;
        }
    }

    return nullptr;
}

inline float normalizedValueFor(const VisualFloatParameterDescriptor &descriptor, float rawValue)
{
    if (descriptor.maxValue <= descriptor.minValue)
    {
        return 0.0f;
    }

    const auto clamped = std::clamp(rawValue, descriptor.minValue, descriptor.maxValue);
    return (clamped - descriptor.minValue) / (descriptor.maxValue - descriptor.minValue);
}

inline float rawValueFor(const VisualFloatParameterDescriptor &descriptor, float normalizedValue)
{
    const auto normalized = std::clamp(normalizedValue, 0.0f, 1.0f);
    return descriptor.minValue + normalized * (descriptor.maxValue - descriptor.minValue);
}
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_VISUAL_PARAMETERS_H
