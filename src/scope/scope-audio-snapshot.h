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
#include <cmath>
#include <optional>

#include "configuration.h"
#include "sst/cpputils/ring_buffer.h"

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

    float peak(uint32_t channel) const
    {
        if (channel >= 2)
        {
            return 0.0f;
        }

        float result{0.0f};
        for (uint32_t i = 0; i < frameCount; ++i)
        {
            result = std::max(result, std::abs(samples[channel][i]));
        }

        return result;
    }
};

class ScopeAudioSnapshotQueue
{
  public:
    void subscribe() { snapshots.subscribe(); }
    void unsubscribe() { snapshots.unsubscribe(); }
    bool subscribed() const { return snapshots.subscribed(); }

    void publish(const ScopeAudioSnapshot &snapshot)
    {
        if (snapshots.subscribed())
        {
            snapshots.push(snapshot);
        }
    }

    void publishFromPlanarStereo(const float source[2][blockSize], uint32_t frames = blockSize)
    {
        if (!snapshots.subscribed())
        {
            return;
        }

        ScopeAudioSnapshot snapshot;
        snapshot.copyFromPlanarStereo(source, frames);
        snapshots.push(snapshot);
    }

    std::optional<ScopeAudioSnapshot> readLatest()
    {
        auto latest = snapshots.pop();
        if (!latest.has_value())
        {
            return std::nullopt;
        }

        auto next = snapshots.pop();
        while (next.has_value())
        {
            latest = std::move(next);
            next = snapshots.pop();
        }

        return latest;
    }

  private:
    sst::cpputils::SimpleRingBuffer<ScopeAudioSnapshot, 8, std::memory_order_seq_cst> snapshots;
};
} // namespace baconpaul::sidequest_ns

#endif // PRETTYSCOPE_SCOPE_AUDIO_SNAPSHOT_H
