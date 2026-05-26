/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_SCOPE_VISUAL_STATE_H
#define PRETTYSCOPE_SCOPE_VISUAL_STATE_H

#include <algorithm>

#include "scope/visual-parameters.h"

namespace baconpaul::sidequest_ns
{
inline float defaultVisualFloat(std::string_view id, float fallback)
{
    const auto *descriptor = visualFloatParameterById(id);
    if (!descriptor)
    {
        return fallback;
    }

    return descriptor->defaultValue;
}

struct ScopeVisualState
{
    float phosphorDecay{defaultVisualFloat(kPhosphorDecayVisualParameterId, 0.98f)};
    float beamIntensity{defaultVisualFloat(kBeamIntensityVisualParameterId, 1.6f)};
    float inputGain{defaultVisualFloat(kInputGainVisualParameterId, 1.0f)};
    float timeScale{defaultVisualFloat(kTimeScaleVisualParameterId, 1.0f)};
    float phosphorFastDecay{defaultVisualFloat(kPhosphorFastDecayVisualParameterId, 0.25f)};
    float phosphorAfterglow{defaultVisualFloat(kPhosphorAfterglowVisualParameterId, 0.95f)};
};

inline float clampVisualFloat(std::string_view id, float value)
{
    const auto *descriptor = visualFloatParameterById(id);
    if (!descriptor)
    {
        return value;
    }

    return std::clamp(value, descriptor->minValue, descriptor->maxValue);
}

inline ScopeVisualState sanitizedScopeVisualState(ScopeVisualState state)
{
    state.phosphorDecay =
        clampVisualFloat(kPhosphorDecayVisualParameterId, state.phosphorDecay);
    state.beamIntensity =
        clampVisualFloat(kBeamIntensityVisualParameterId, state.beamIntensity);
    state.inputGain = clampVisualFloat(kInputGainVisualParameterId, state.inputGain);
    state.timeScale = clampVisualFloat(kTimeScaleVisualParameterId, state.timeScale);
    state.phosphorFastDecay =
        clampVisualFloat(kPhosphorFastDecayVisualParameterId, state.phosphorFastDecay);
    state.phosphorAfterglow =
        clampVisualFloat(kPhosphorAfterglowVisualParameterId, state.phosphorAfterglow);
    return state;
}
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_VISUAL_STATE_H
