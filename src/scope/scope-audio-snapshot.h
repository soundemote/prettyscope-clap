/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_SCOPE_AUDIO_SNAPSHOT_H
#define PRETTYSCOPE_SCOPE_AUDIO_SNAPSHOT_H

#include <algorithm>
#include <cstdint>
#include <cstring>

#include "configuration.h"

namespace baconpaul::sidequest_ns
{
struct ScopeAudioSnapshot
{
    float samples alignas(16)[2][blockSize]{};
    uint32_t frameCount{0};
    bool hasSignal{false};

    void clear()
    {
        std::memset(samples, 0, sizeof(samples));
        frameCount = 0;
        hasSignal = false;
    }

    void copyFromPlanarStereo(const float source[2][blockSize], uint32_t frames = blockSize)
    {
        const auto framesToCopy = std::min<uint32_t>(frames, blockSize);
        clear();

        for (uint32_t channel = 0; channel < 2; ++channel)
        {
            std::copy_n(source[channel], framesToCopy, samples[channel]);
        }

        frameCount = framesToCopy;
        hasSignal = frameCount > 0;
    }
};
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_AUDIO_SNAPSHOT_H
