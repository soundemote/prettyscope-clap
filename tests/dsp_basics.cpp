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
#include "presets/preset-manager.h"
#include "scope/scope-audio-snapshot.h"
#include "scope/visual-parameters.h"
#include "sst/plugininfra/patch-support/patch_base_clap_adapter.h"

#include <algorithm>
#include <memory>
#include <set>
#include <string>

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

TEST_CASE("Scope audio snapshot reports per-channel peaks", "[audio]")
{
    float block[2][baconpaul::sidequest_ns::blockSize]{};
    block[0][0] = -0.25f;
    block[0][1] = 0.75f;
    block[1][0] = -0.5f;
    block[1][1] = 0.125f;

    baconpaul::sidequest_ns::ScopeAudioSnapshot snapshot;
    snapshot.copyFromPlanarStereo(block, 2);

    REQUIRE(snapshot.peak(0) == Approx(0.75f));
    REQUIRE(snapshot.peak(1) == Approx(0.5f));
    REQUIRE(snapshot.peak(2) == Approx(0.0f));
}

TEST_CASE("Scope audio snapshot exposes renderable frame state", "[audio]")
{
    float block[2][baconpaul::sidequest_ns::blockSize]{};

    baconpaul::sidequest_ns::ScopeAudioSnapshot snapshot;
    snapshot.copyFromPlanarStereo(block, 1);

    REQUIRE(snapshot.validFrameCount() == 1);
    REQUIRE_FALSE(snapshot.hasRenderableTrace());

    snapshot.copyFromPlanarStereo(block, 2);
    REQUIRE(snapshot.validFrameCount() == 2);
    REQUIRE(snapshot.hasRenderableTrace());

    snapshot.frameCount = baconpaul::sidequest_ns::blockSize + 100;
    REQUIRE(snapshot.validFrameCount() == baconpaul::sidequest_ns::blockSize);
}

TEST_CASE("Scope audio snapshot clears on null source", "[audio]")
{
    baconpaul::sidequest_ns::ScopeAudioSnapshot snapshot;
    snapshot.frameCount = 8;
    snapshot.hasSignal = true;
    snapshot.samples[0][0] = 1.0f;

    snapshot.copyFromPlanarStereo(nullptr);

    REQUIRE_FALSE(snapshot.hasSignal);
    REQUIRE(snapshot.frameCount == 0);
    REQUIRE(snapshot.samples[0][0] == 0.0f);
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

TEST_CASE("Scope audio snapshot queue stamps new snapshots", "[audio]")
{
    baconpaul::sidequest_ns::ScopeAudioSnapshotQueue queue;
    queue.subscribe();

    float block[2][baconpaul::sidequest_ns::blockSize]{};
    block[0][0] = 1.0f;
    block[1][0] = -1.0f;

    queue.publishFromPlanarStereo(block);
    const auto first = queue.readLatest();
    REQUIRE(first.has_value());
    REQUIRE(first->serial > 0);

    queue.publishFromPlanarStereo(block);
    const auto second = queue.readLatest();
    REQUIRE(second.has_value());
    REQUIRE(second->serial > first->serial);

    queue.publishEmpty();
    const auto empty = queue.readLatest();
    REQUIRE(empty.has_value());
    REQUIRE(empty->serial > second->serial);
    REQUIRE_FALSE(empty->hasSignal);
}

TEST_CASE("Scope audio snapshot queue ignores publishes while unsubscribed", "[audio]")
{
    baconpaul::sidequest_ns::ScopeAudioSnapshotQueue queue;
    float block[2][baconpaul::sidequest_ns::blockSize]{};
    block[0][0] = 1.0f;
    block[1][0] = -1.0f;

    queue.publishFromPlanarStereo(block);
    REQUIRE_FALSE(queue.readLatest().has_value());

    queue.subscribe();
    queue.publishFromPlanarStereo(block);
    REQUIRE(queue.readLatest().has_value());

    queue.unsubscribe();
    queue.publishFromPlanarStereo(block);
    REQUIRE_FALSE(queue.readLatest().has_value());
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

TEST_CASE("Engine publishes empty scope snapshot when input disappears", "[audio]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();
    engine->scopeSnapshots.subscribe();

    float left[baconpaul::sidequest_ns::blockSize]{};
    float right[baconpaul::sidequest_ns::blockSize]{};
    left[0] = 0.5f;
    right[0] = -0.5f;

    const float *input[] = {left, right};
    engine->process(nullptr, input, 2, baconpaul::sidequest_ns::blockSize);
    REQUIRE(engine->scopeSnapshots.readLatest()->hasSignal);

    engine->process(nullptr, nullptr, 0, 0);
    const auto snapshot = engine->scopeSnapshots.readLatest();

    REQUIRE(snapshot.has_value());
    REQUIRE_FALSE(snapshot->hasSignal);
    REQUIRE(snapshot->frameCount == 0);
}

TEST_CASE("Engine ignores advertised input with no readable source channel", "[audio]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();
    engine->scopeSnapshots.subscribe();

    const float *input[] = {nullptr};
    engine->process(nullptr, input, 1, baconpaul::sidequest_ns::blockSize);

    REQUIRE_FALSE(engine->hasScopeInput);
    for (size_t i = 0; i < baconpaul::sidequest_ns::blockSize; ++i)
    {
        REQUIRE(engine->output[0][i] == 0.0f);
        REQUIRE(engine->output[1][i] == 0.0f);
    }

    const auto snapshot = engine->scopeSnapshots.readLatest();
    REQUIRE(snapshot.has_value());
    REQUIRE_FALSE(snapshot->hasSignal);
    REQUIRE(snapshot->frameCount == 0);
}

TEST_CASE("Engine applies notified parameter updates without CLAP output queue", "[params]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();
    const auto *descriptor = baconpaul::sidequest_ns::visualFloatParameterById("input_gain");
    REQUIRE(descriptor != nullptr);

    engine->mainToAudio.push({baconpaul::sidequest_ns::Engine::MainToAudioMsg::BEGIN_EDIT,
                              descriptor->stableId.value});
    engine->mainToAudio.push({baconpaul::sidequest_ns::Engine::MainToAudioMsg::SET_PARAM,
                              descriptor->stableId.value, descriptor->midValue});
    engine->mainToAudio.push({baconpaul::sidequest_ns::Engine::MainToAudioMsg::END_EDIT,
                              descriptor->stableId.value});

    engine->process(nullptr, nullptr, 0, 0);

    REQUIRE(engine->patch.dirty);
    REQUIRE(engine->beginEndParamGestureCount == 0);
}

TEST_CASE("Preset patch send queues audio updates without CLAP host", "[params]")
{
    baconpaul::sidequest_ns::Patch patch;
    auto mainToAudio = std::make_unique<baconpaul::sidequest_ns::Engine::mainToAudioQueue_T>();

    baconpaul::sidequest_ns::presets::PresetManager::sendEntirePatchToAudio(
        patch, *mainToAudio, "Standalone", nullptr);

    auto message = mainToAudio->pop();
    REQUIRE(message.has_value());
    REQUIRE(message->action == baconpaul::sidequest_ns::Engine::MainToAudioMsg::SEND_PATCH_NAME);

    message = mainToAudio->pop();
    REQUIRE(message.has_value());
    REQUIRE(message->action == baconpaul::sidequest_ns::Engine::MainToAudioMsg::STOP_AUDIO);

    for (uint32_t i = 0; i < patch.params.size(); ++i)
    {
        message = mainToAudio->pop();
        REQUIRE(message.has_value());
        REQUIRE(message->action ==
                baconpaul::sidequest_ns::Engine::MainToAudioMsg::SET_PARAM_WITHOUT_NOTIFYING);
    }

    message = mainToAudio->pop();
    REQUIRE(message.has_value());
    REQUIRE(message->action == baconpaul::sidequest_ns::Engine::MainToAudioMsg::START_AUDIO);
}

TEST_CASE("Engine handles parameter rescan requests without CLAP host", "[params]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();

    engine->mainToAudio.push(
        {baconpaul::sidequest_ns::Engine::MainToAudioMsg::SEND_REQUEST_RESCAN});

    engine->process(nullptr, nullptr, 0, 0);
    engine->onMainThread();

    auto message = engine->audioToUi.pop();
    REQUIRE(message.has_value());
    REQUIRE(message->action == baconpaul::sidequest_ns::Engine::AudioToUIMsg::DO_PARAM_RESCAN);
}

TEST_CASE("Engine ignores unknown parameter updates", "[params]")
{
    auto engine = std::make_unique<baconpaul::sidequest_ns::Engine>();
    constexpr uint32_t unknownParameterId{0xffffffff};

    REQUIRE(engine->patch.paramById(unknownParameterId) == nullptr);

    engine->mainToAudio.push({baconpaul::sidequest_ns::Engine::MainToAudioMsg::SET_PARAM,
                              unknownParameterId, 0.5f});
    engine->process(nullptr, nullptr, 0, 0);
    REQUIRE_FALSE(engine->patch.dirty);

    engine->handleParamValue(nullptr, unknownParameterId, 0.25f);
    REQUIRE_FALSE(engine->audioToUi.pop().has_value());
}

TEST_CASE("Prettyscope visual descriptors adapt into Sidequest patch params", "[params]")
{
    baconpaul::sidequest_ns::Patch patch;
    const auto descriptors = baconpaul::sidequest_ns::visualFloatParameters();

    REQUIRE(patch.params.size() == descriptors.size());

    for (const auto &descriptor : descriptors)
    {
        auto found = patch.paramMap.find(descriptor.stableId.value);
        REQUIRE(found != patch.paramMap.end());

        const auto *param = found->second;
        REQUIRE(param->visualParameterId == descriptor.id);
        REQUIRE(param->meta.id == descriptor.stableId.value);
        REQUIRE(param->meta.name == descriptor.displayName);
        REQUIRE(param->meta.groupName == descriptor.category);
        REQUIRE(param->meta.minVal == descriptor.minValue);
        REQUIRE(param->meta.maxVal == descriptor.maxValue);
        REQUIRE(param->meta.defaultVal == descriptor.defaultValue);
        REQUIRE((param->meta.flags & CLAP_PARAM_IS_AUTOMATABLE) != 0);
    }
}

TEST_CASE("Prettyscope visual descriptor ids are unique and stable", "[params]")
{
    std::set<std::string> stringIds;
    std::set<uint32_t> stableIds;

    for (const auto &descriptor : baconpaul::sidequest_ns::visualFloatParameters())
    {
        REQUIRE_FALSE(descriptor.id.empty());
        REQUIRE(descriptor.stableId.value != 0);
        REQUIRE(stringIds.insert(std::string(descriptor.id)).second);
        REQUIRE(stableIds.insert(descriptor.stableId.value).second);

        REQUIRE(baconpaul::sidequest_ns::visualFloatParameterById(descriptor.id) ==
                &descriptor);
        REQUIRE(baconpaul::sidequest_ns::visualFloatParameterByStableId(
                    descriptor.stableId.value) == &descriptor);
    }

    REQUIRE(stringIds.size() == baconpaul::sidequest_ns::visualFloatParameters().size());
    REQUIRE(stableIds.size() == baconpaul::sidequest_ns::visualFloatParameters().size());
}

TEST_CASE("Prettyscope visual descriptor ranges contain defaults and midpoints", "[params]")
{
    for (const auto &descriptor : baconpaul::sidequest_ns::visualFloatParameters())
    {
        REQUIRE(descriptor.minValue < descriptor.maxValue);
        REQUIRE(descriptor.defaultValue >= descriptor.minValue);
        REQUIRE(descriptor.defaultValue <= descriptor.maxValue);
        REQUIRE(descriptor.midValue >= descriptor.minValue);
        REQUIRE(descriptor.midValue <= descriptor.maxValue);
        REQUIRE_FALSE(descriptor.displayName.empty());
        REQUIRE_FALSE(descriptor.category.empty());
    }
}

TEST_CASE("Prettyscope visual params roundtrip through Sidequest values", "[params]")
{
    baconpaul::sidequest_ns::Patch patch;
    const auto *descriptor = baconpaul::sidequest_ns::visualFloatParameterById("input_gain");

    REQUIRE(descriptor != nullptr);

    auto *param = patch.paramMap.at(descriptor->stableId.value);
    const auto normalized = param->meta.naturalToNormalized01(descriptor->midValue);
    const auto raw = param->meta.normalized01ToNatural(normalized);

    param->value = raw;

    REQUIRE(param->visualParameterId == "input_gain");
    REQUIRE(raw == Approx(descriptor->midValue));
    REQUIRE(param->value == Approx(descriptor->midValue));
    REQUIRE(param->meta.naturalToNormalized01(param->value) == normalized);
}

TEST_CASE("Prettyscope visual descriptor normalized helpers roundtrip raw values", "[params]")
{
    const auto *descriptor = baconpaul::sidequest_ns::visualFloatParameterById("input_gain");
    REQUIRE(descriptor != nullptr);

    const auto normalized = baconpaul::sidequest_ns::normalizedValueFor(
        *descriptor, descriptor->midValue);
    const auto raw = baconpaul::sidequest_ns::rawValueFor(*descriptor, normalized);

    REQUIRE(normalized >= 0.0f);
    REQUIRE(normalized <= 1.0f);
    REQUIRE(raw == Approx(descriptor->midValue));
    REQUIRE(baconpaul::sidequest_ns::normalizedValueFor(*descriptor,
                                                        descriptor->minValue - 10.0f) ==
            Approx(0.0f));
    REQUIRE(baconpaul::sidequest_ns::normalizedValueFor(*descriptor,
                                                        descriptor->maxValue + 10.0f) ==
            Approx(1.0f));
    REQUIRE(baconpaul::sidequest_ns::rawValueFor(*descriptor, -1.0f) ==
            Approx(descriptor->minValue));
    REQUIRE(baconpaul::sidequest_ns::rawValueFor(*descriptor, 2.0f) ==
            Approx(descriptor->maxValue));
}

TEST_CASE("Prettyscope visual state defaults match descriptors", "[params]")
{
    baconpaul::sidequest_ns::ScopeVisualState state;

    REQUIRE(state.phosphorDecay ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kPhosphorDecayVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.beamIntensity ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kBeamIntensityVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.inputGain ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kInputGainVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.timeScale ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kTimeScaleVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.phosphorFastDecay ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kPhosphorFastDecayVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.phosphorAfterglow ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kPhosphorAfterglowVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.beamGlowStrength ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kBeamGlowStrengthVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.beamTraceWidth ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kBeamTraceWidthVisualParameterId)
                       ->defaultValue));
    REQUIRE(state.beamGlowWidth ==
            Approx(baconpaul::sidequest_ns::visualFloatParameterById(
                       baconpaul::sidequest_ns::kBeamGlowWidthVisualParameterId)
                       ->defaultValue));
}

TEST_CASE("Prettyscope visual params appear through CLAP patch adapter", "[params]")
{
    baconpaul::sidequest_ns::Patch patch;
    for (uint32_t index = 0; index < patch.params.size(); ++index)
    {
        clap_param_info info{};

        REQUIRE(sst::plugininfra::patch_support::patchParamsInfo(index, &info, patch));
        const auto *descriptor = baconpaul::sidequest_ns::visualFloatParameterByStableId(info.id);

        REQUIRE(descriptor != nullptr);
        REQUIRE(std::string(info.name) == descriptor->displayName);
        REQUIRE(std::string(info.module) == descriptor->category);
        REQUIRE((info.flags & CLAP_PARAM_IS_AUTOMATABLE) != 0);

        double value = -1.0;
        REQUIRE(sst::plugininfra::patch_support::patchParamsValue(info.id, &value, patch));
        REQUIRE(value == Approx(descriptor->defaultValue));
    }
}

TEST_CASE("Prettyscope patch visual params produce renderer visual state", "[params]")
{
    baconpaul::sidequest_ns::Patch patch;
    patch.visualParams.phosphorDecay.value = 0.991f;
    patch.visualParams.beamIntensity.value = 2.25f;
    patch.visualParams.inputGain.value = 3.5f;
    patch.visualParams.timeScale.value = 1.75f;
    patch.visualParams.phosphorFastDecay.value = 0.65f;
    patch.visualParams.phosphorAfterglow.value = 0.85f;
    patch.visualParams.beamGlowStrength.value = 0.55f;
    patch.visualParams.beamTraceWidth.value = 3.5f;
    patch.visualParams.beamGlowWidth.value = 12.0f;

    const auto state = patch.visualParams.visualState();

    REQUIRE(state.phosphorDecay == Approx(0.991f));
    REQUIRE(state.beamIntensity == Approx(2.25f));
    REQUIRE(state.inputGain == Approx(3.5f));
    REQUIRE(state.timeScale == Approx(1.75f));
    REQUIRE(state.phosphorFastDecay == Approx(0.65f));
    REQUIRE(state.phosphorAfterglow == Approx(0.85f));
    REQUIRE(state.beamGlowStrength == Approx(0.55f));
    REQUIRE(state.beamTraceWidth == Approx(3.5f));
    REQUIRE(state.beamGlowWidth == Approx(12.0f));
}

TEST_CASE("Prettyscope renderer visual state is clamped to descriptor ranges", "[params]")
{
    baconpaul::sidequest_ns::Patch patch;
    patch.visualParams.phosphorDecay.value = 2.0f;
    patch.visualParams.beamIntensity.value = -1.0f;
    patch.visualParams.inputGain.value = 99.0f;
    patch.visualParams.timeScale.value = 0.01f;
    patch.visualParams.phosphorFastDecay.value = 2.0f;
    patch.visualParams.phosphorAfterglow.value = -2.0f;
    patch.visualParams.beamGlowStrength.value = 100.0f;
    patch.visualParams.beamTraceWidth.value = 0.0f;
    patch.visualParams.beamGlowWidth.value = 100.0f;

    const auto state = patch.visualParams.visualState();

    REQUIRE(state.phosphorDecay == Approx(0.999f));
    REQUIRE(state.beamIntensity == Approx(0.0f));
    REQUIRE(state.inputGain == Approx(8.0f));
    REQUIRE(state.timeScale == Approx(0.25f));
    REQUIRE(state.phosphorFastDecay == Approx(1.0f));
    REQUIRE(state.phosphorAfterglow == Approx(0.0f));
    REQUIRE(state.beamGlowStrength == Approx(2.0f));
    REQUIRE(state.beamTraceWidth == Approx(0.5f));
    REQUIRE(state.beamGlowWidth == Approx(24.0f));
}
