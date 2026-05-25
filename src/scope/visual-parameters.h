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

inline constexpr std::array<VisualFloatParameterDescriptor, 4> kVisualFloatParameters{{
    {kPhosphorDecayVisualParameterId, {1000}, "Phosphor Decay", "Phosphor", 0.98f, 0.80f,
     0.95f, 0.999f, true, true},
    {kBeamIntensityVisualParameterId, {1001}, "Beam Intensity", "Beam", 1.6f, 0.0f, 1.0f,
     4.0f, true, true},
    {kInputGainVisualParameterId, {1002}, "Input Gain", "Signal", 1.0f, 0.1f, 1.0f, 8.0f,
     true, true},
    {kTimeScaleVisualParameterId, {1003}, "Time Scale", "Signal", 1.0f, 0.25f, 1.0f, 4.0f,
     true, true},
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
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_VISUAL_PARAMETERS_H
