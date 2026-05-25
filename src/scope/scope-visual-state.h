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

namespace baconpaul::sidequest_ns
{
struct ScopeVisualState
{
    float phosphorDecay{0.98f};
    float beamIntensity{1.6f};
    float inputGain{1.0f};
    float timeScale{1.0f};
};
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_VISUAL_STATE_H
