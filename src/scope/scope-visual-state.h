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
struct ScopeVisualState
{
    float phosphorDecay{0.98f};
    float beamIntensity{1.6f};
    float inputGain{1.0f};
    float timeScale{1.0f};
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
    return state;
}
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_VISUAL_STATE_H
