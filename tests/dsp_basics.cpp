/*
 * SideQuest Starting Point
 *
 * Basically lets paul bootstrap his projects.
 *
 * Copyright 2024-2025, Paul Walker and Various authors, as described in the github
 * transaction log.
 *
 * This source repo is released under the MIT license, but has
 * GPL3 dependencies, as such the combined work will be
 * released under GPL3.
 *
 * The source code and license are at https://github.com/baconpaul/sidequest-startingpoint
 */

#include "catch2/catch2.hpp"

#include "engine/engine.h"
#include "scope/scope-audio-snapshot.h"

#include <algorithm>
#include <memory>

TEST_CASE("Some DSP Test", "[dsp]") { REQUIRE(1 + 1 == 2); }

TEST_CASE("Engine passes stereo input to output and scope tap", "[audio]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();

    float left[baconpaul::sidequest_ns::blockSize]{};
    float right[baconpaul::sidequest_ns::blockSize]{};
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        left[i] = static_cast<float>(i) * 0.1f;
        right[i] = -left[i];
    }

    const float *input[] = {left, right};
    engine->process(nullptr, input, 2, baconpaul::sidequest_ns::blockSize);

    REQUIRE(engine->hasScopeInput);
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        REQUIRE(engine->output[0][i] == left[i]);
        REQUIRE(engine->output[1][i] == right[i]);
        REQUIRE(engine->scopeInput[0][i] == left[i]);
        REQUIRE(engine->scopeInput[1][i] == right[i]);
    }
}

TEST_CASE("Engine mirrors mono input to stereo output and scope tap", "[audio]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();

    float mono[baconpaul::sidequest_ns::blockSize]{};
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        mono[i] = static_cast<float>(i) * 0.05f;
    }

    const float *input[] = {mono};
    engine->process(nullptr, input, 1, baconpaul::sidequest_ns::blockSize);

    REQUIRE(engine->hasScopeInput);
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        REQUIRE(engine->output[0][i] == mono[i]);
        REQUIRE(engine->output[1][i] == mono[i]);
        REQUIRE(engine->scopeInput[0][i] == mono[i]);
        REQUIRE(engine->scopeInput[1][i] == mono[i]);
    }
}

TEST_CASE("Scope audio snapshot copies the engine scope tap", "[audio]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();

    float left[baconpaul::sidequest_ns::blockSize]{};
    float right[baconpaul::sidequest_ns::blockSize]{};
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        left[i] = 0.25f + static_cast<float>(i) * 0.01f;
        right[i] = -0.5f + static_cast<float>(i) * 0.02f;
    }

    const float *input[] = {left, right};
    engine->process(nullptr, input, 2, baconpaul::sidequest_ns::blockSize);

    baconpaul::sidequest_ns::ScopeAudioSnapshot snapshot;
    snapshot.copyFromPlanarStereo(engine->scopeInput);

    REQUIRE(snapshot.hasSignal);
    REQUIRE(snapshot.frameCount == baconpaul::sidequest_ns::blockSize);
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        REQUIRE(snapshot.samples[0][i] == left[i]);
        REQUIRE(snapshot.samples[1][i] == right[i]);
    }
}

TEST_CASE("Scope audio snapshot queue returns the latest published block", "[audio]")
{
    baconpaul::sidequest_ns::ScopeAudioSnapshotQueue queue;
    queue.subscribe();

    float first[baconpaul::sidequest_ns::blockSize]{};
    float second[baconpaul::sidequest_ns::blockSize]{};
    float block[2][baconpaul::sidequest_ns::blockSize]{};

    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        first[i] = static_cast<float>(i);
        second[i] = 100.0f + static_cast<float>(i);
    }

    std::copy_n(first, baconpaul::sidequest_ns::blockSize, block[0]);
    std::copy_n(first, baconpaul::sidequest_ns::blockSize, block[1]);
    queue.publishFromPlanarStereo(block);

    std::copy_n(second, baconpaul::sidequest_ns::blockSize, block[0]);
    std::copy_n(second, baconpaul::sidequest_ns::blockSize, block[1]);
    queue.publishFromPlanarStereo(block);

    const auto snapshot = queue.readLatest();

    REQUIRE(snapshot.has_value());
    REQUIRE(snapshot->hasSignal);
    REQUIRE(snapshot->frameCount == baconpaul::sidequest_ns::blockSize);
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        REQUIRE(snapshot->samples[0][i] == second[i]);
        REQUIRE(snapshot->samples[1][i] == second[i]);
    }
}

TEST_CASE("Engine publishes subscribed scope snapshots", "[audio]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();
    engine->scopeSnapshots.subscribe();

    float left[baconpaul::sidequest_ns::blockSize]{};
    float right[baconpaul::sidequest_ns::blockSize]{};
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        left[i] = 0.75f + static_cast<float>(i) * 0.03f;
        right[i] = -0.25f - static_cast<float>(i) * 0.04f;
    }

    const float *input[] = {left, right};
    engine->process(nullptr, input, 2, baconpaul::sidequest_ns::blockSize);

    const auto snapshot = engine->scopeSnapshots.readLatest();

    REQUIRE(snapshot.has_value());
    REQUIRE(snapshot->hasSignal);
    REQUIRE(snapshot->frameCount == baconpaul::sidequest_ns::blockSize);
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        REQUIRE(snapshot->samples[0][i] == left[i]);
        REQUIRE(snapshot->samples[1][i] == right[i]);
    }
}
