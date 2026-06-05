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
    float discontinuitySkipSamples{
        defaultVisualFloat(kDiscontinuitySkipSamplesVisualParameterId, 1.0f)};
    float phosphorFastDecay{defaultVisualFloat(kPhosphorFastDecayVisualParameterId, 0.25f)};
    float phosphorAfterglow{defaultVisualFloat(kPhosphorAfterglowVisualParameterId, 0.95f)};
    float beamGlowStrength{defaultVisualFloat(kBeamGlowStrengthVisualParameterId, 0.35f)};
    float beamTraceWidth{defaultVisualFloat(kBeamTraceWidthVisualParameterId, 2.0f)};
    float beamGlowWidth{defaultVisualFloat(kBeamGlowWidthVisualParameterId, 7.0f)};
    float dot1Intensity{defaultVisualFloat(kDot1IntensityVisualParameterId, 1.0f)};
    float dot1Size{defaultVisualFloat(kDot1SizeVisualParameterId, 2.0f)};
    float dot1Halo{defaultVisualFloat(kDot1HaloVisualParameterId, 0.35f)};
    float dot1ImageMix{defaultVisualFloat(kDot1ImageMixVisualParameterId, 0.0f)};
    float dot1Rotation{defaultVisualFloat(kDot1RotationVisualParameterId, 0.0f)};
    float dot1Aspect{defaultVisualFloat(kDot1AspectVisualParameterId, 1.0f)};
    float dot2Intensity{defaultVisualFloat(kDot2IntensityVisualParameterId, 0.45f)};
    float dot2Size{defaultVisualFloat(kDot2SizeVisualParameterId, 6.0f)};
    float dot2Halo{defaultVisualFloat(kDot2HaloVisualParameterId, 0.65f)};
    float dot2ImageMix{defaultVisualFloat(kDot2ImageMixVisualParameterId, 0.0f)};
    float dot2Rotation{defaultVisualFloat(kDot2RotationVisualParameterId, 0.0f)};
    float dot2Aspect{defaultVisualFloat(kDot2AspectVisualParameterId, 1.0f)};
    float dotOverallIntensity{defaultVisualFloat(kDotOverallIntensityVisualParameterId, 1.0f)};
    float dotOverallSize{defaultVisualFloat(kDotOverallSizeVisualParameterId, 1.0f)};
    float dotOverallHalo{defaultVisualFloat(kDotOverallHaloVisualParameterId, 1.0f)};
    float dotOverallImageMix{defaultVisualFloat(kDotOverallImageMixVisualParameterId, 1.0f)};
    float screenBurnPersistence{defaultVisualFloat(kScreenBurnPersistenceVisualParameterId, 0.98f)};
    float screenBurnFastDecay{defaultVisualFloat(kScreenBurnFastDecayVisualParameterId, 0.25f)};
    float screenBurnAfterglow{defaultVisualFloat(kScreenBurnAfterglowVisualParameterId, 0.95f)};
    float screenBurnFloorFade{defaultVisualFloat(kScreenBurnFloorFadeVisualParameterId, 0.00035f)};
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
    state.discontinuitySkipSamples =
        clampVisualFloat(kDiscontinuitySkipSamplesVisualParameterId,
                         state.discontinuitySkipSamples);
    state.phosphorFastDecay =
        clampVisualFloat(kPhosphorFastDecayVisualParameterId, state.phosphorFastDecay);
    state.phosphorAfterglow =
        clampVisualFloat(kPhosphorAfterglowVisualParameterId, state.phosphorAfterglow);
    state.beamGlowStrength =
        clampVisualFloat(kBeamGlowStrengthVisualParameterId, state.beamGlowStrength);
    state.beamTraceWidth =
        clampVisualFloat(kBeamTraceWidthVisualParameterId, state.beamTraceWidth);
    state.beamGlowWidth = clampVisualFloat(kBeamGlowWidthVisualParameterId, state.beamGlowWidth);
    state.dot1Intensity = clampVisualFloat(kDot1IntensityVisualParameterId, state.dot1Intensity);
    state.dot1Size = clampVisualFloat(kDot1SizeVisualParameterId, state.dot1Size);
    state.dot1Halo = clampVisualFloat(kDot1HaloVisualParameterId, state.dot1Halo);
    state.dot1ImageMix = clampVisualFloat(kDot1ImageMixVisualParameterId, state.dot1ImageMix);
    state.dot1Rotation = clampVisualFloat(kDot1RotationVisualParameterId, state.dot1Rotation);
    state.dot1Aspect = clampVisualFloat(kDot1AspectVisualParameterId, state.dot1Aspect);
    state.dot2Intensity = clampVisualFloat(kDot2IntensityVisualParameterId, state.dot2Intensity);
    state.dot2Size = clampVisualFloat(kDot2SizeVisualParameterId, state.dot2Size);
    state.dot2Halo = clampVisualFloat(kDot2HaloVisualParameterId, state.dot2Halo);
    state.dot2ImageMix = clampVisualFloat(kDot2ImageMixVisualParameterId, state.dot2ImageMix);
    state.dot2Rotation = clampVisualFloat(kDot2RotationVisualParameterId, state.dot2Rotation);
    state.dot2Aspect = clampVisualFloat(kDot2AspectVisualParameterId, state.dot2Aspect);
    state.dotOverallIntensity =
        clampVisualFloat(kDotOverallIntensityVisualParameterId, state.dotOverallIntensity);
    state.dotOverallSize = clampVisualFloat(kDotOverallSizeVisualParameterId, state.dotOverallSize);
    state.dotOverallHalo = clampVisualFloat(kDotOverallHaloVisualParameterId, state.dotOverallHalo);
    state.dotOverallImageMix =
        clampVisualFloat(kDotOverallImageMixVisualParameterId, state.dotOverallImageMix);
    state.screenBurnPersistence =
        clampVisualFloat(kScreenBurnPersistenceVisualParameterId, state.screenBurnPersistence);
    state.screenBurnFastDecay =
        clampVisualFloat(kScreenBurnFastDecayVisualParameterId, state.screenBurnFastDecay);
    state.screenBurnAfterglow =
        clampVisualFloat(kScreenBurnAfterglowVisualParameterId, state.screenBurnAfterglow);
    state.screenBurnFloorFade =
        clampVisualFloat(kScreenBurnFloorFadeVisualParameterId, state.screenBurnFloorFade);
    return state;
}
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_VISUAL_STATE_H
