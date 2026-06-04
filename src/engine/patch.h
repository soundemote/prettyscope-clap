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

#ifndef BACONPAUL_SIDEQUEST_ENGINE_PATCH_H
#define BACONPAUL_SIDEQUEST_ENGINE_PATCH_H

#include <vector>
#include <array>
#include <unordered_map>
#include <algorithm>
#include <clap/clap.h>
#include "configuration.h"
#include "sst/cpputils/constructors.h"
#include "sst/cpputils/active_set_overlay.h"
#include "sst/basic-blocks/params/ParamMetadata.h"
#include "sst/basic-blocks/dsp/Lag.h"
#include "sst/basic-blocks/modulators/DAHDSREnvelope.h"
#include "sst/plugininfra/patch-support/patch_base.h"
#include "scope/scope-visual-state.h"
#include "scope/visual-parameters.h"

namespace baconpaul::sidequest_ns
{
namespace scpu = sst::cpputils;
namespace pats = sst::plugininfra::patch_support;
using md_t = sst::basic_blocks::params::ParamMetaData;
struct Param : pats::ParamBase, sst::cpputils::active_set_overlay<Param>::participant
{
    Param(const md_t &m) : pats::ParamBase(m) {}
    Param(const md_t &m, std::string visualId) : pats::ParamBase(m), visualParameterId(visualId) {}

    Param &operator=(const float &val)
    {
        value = val;
        return *this;
    }

    uint64_t adhocFeatures{0};
    enum AdHocFeatureValues : uint64_t
    {
    };

    bool isTemposynced() const
    {
        if (tempoSyncPartner)
            return tempoSyncPartner->value;

        return false;
    }

    Param *tempoSyncPartner{nullptr};

    sst::basic_blocks::dsp::LinearLag<float, false> lag;
    std::string visualParameterId;
};

struct Patch : pats::PatchBase<Patch, Param>
{
    static constexpr uint32_t patchVersion{9};
    static constexpr const char *id{"com.soundemote.prettyscope"};

    static constexpr uint32_t floatFlags{CLAP_PARAM_IS_AUTOMATABLE};
    static constexpr uint32_t boolFlags{CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_STEPPED};

    static md_t floatMd() { return md_t().asFloat().withFlags(floatFlags); }
    static md_t floatEnvRateMd()
    {
        return md_t().asFloat().withFlags(floatFlags).as25SecondExpTime();
    }
    static md_t boolMd() { return md_t().asBool().withFlags(boolFlags); }
    static md_t intMd() { return md_t().asInt().withFlags(boolFlags); }

    Patch() : pats::PatchBase<Patch, Param>()

    {
        auto pushParams = [this](auto &from) { this->pushMultipleParams(from.params()); };

        pushParams(visualParams);

        std::sort(params.begin(), params.end(),
                  [](const Param *a, const Param *b)
                  {
                      auto ga = a->meta.groupName;
                      auto gb = b->meta.groupName;
                      if (ga != gb)
                      {
                          if (ga == "Main")
                              return true;
                          if (gb == "Main")
                              return false;

                          return ga < gb;
                      }

                      auto an = a->meta.name;
                      auto bn = b->meta.name;
                      auto ane = an.find("Env ") != std::string::npos;
                      auto bne = bn.find("Env ") != std::string::npos;

                      if (ane != bne)
                      {
                          if (ane)
                              return false;

                          return true;
                      }
                      if (ane && bne)
                          return a->meta.id < b->meta.id;

                      return a->meta.name < b->meta.name;
                  });
    }

    struct VisualNode
    {
        VisualNode()
            : phosphorDecay(makeParam(kPhosphorDecayVisualParameterId)),
              beamIntensity(makeParam(kBeamIntensityVisualParameterId)),
              inputGain(makeParam(kInputGainVisualParameterId)),
              timeScale(makeParam(kTimeScaleVisualParameterId)),
              phosphorFastDecay(makeParam(kPhosphorFastDecayVisualParameterId)),
              phosphorAfterglow(makeParam(kPhosphorAfterglowVisualParameterId)),
              beamGlowStrength(makeParam(kBeamGlowStrengthVisualParameterId)),
              beamTraceWidth(makeParam(kBeamTraceWidthVisualParameterId)),
              beamGlowWidth(makeParam(kBeamGlowWidthVisualParameterId)),
              dot1Intensity(makeParam(kDot1IntensityVisualParameterId)),
              dot1Size(makeParam(kDot1SizeVisualParameterId)),
              dot1Halo(makeParam(kDot1HaloVisualParameterId)),
              dot1ImageMix(makeParam(kDot1ImageMixVisualParameterId)),
              dot1Rotation(makeParam(kDot1RotationVisualParameterId)),
              dot1Aspect(makeParam(kDot1AspectVisualParameterId)),
              dot2Intensity(makeParam(kDot2IntensityVisualParameterId)),
              dot2Size(makeParam(kDot2SizeVisualParameterId)),
              dot2Halo(makeParam(kDot2HaloVisualParameterId)),
              dot2ImageMix(makeParam(kDot2ImageMixVisualParameterId)),
              dot2Rotation(makeParam(kDot2RotationVisualParameterId)),
              dot2Aspect(makeParam(kDot2AspectVisualParameterId)),
              dotOverallIntensity(makeParam(kDotOverallIntensityVisualParameterId)),
              dotOverallSize(makeParam(kDotOverallSizeVisualParameterId)),
              dotOverallHalo(makeParam(kDotOverallHaloVisualParameterId)),
              dotOverallImageMix(makeParam(kDotOverallImageMixVisualParameterId)),
              screenBurnPersistence(makeParam(kScreenBurnPersistenceVisualParameterId)),
              screenBurnFastDecay(makeParam(kScreenBurnFastDecayVisualParameterId)),
              screenBurnAfterglow(makeParam(kScreenBurnAfterglowVisualParameterId)),
              screenBurnFloorFade(makeParam(kScreenBurnFloorFadeVisualParameterId))
        {
        }

        std::string name() const { return "Prettyscope"; }

        static md_t metadataFrom(const VisualFloatParameterDescriptor &descriptor)
        {
            uint32_t flags = 0;
            if (descriptor.automatable)
            {
                flags |= CLAP_PARAM_IS_AUTOMATABLE;
            }
            if (!descriptor.visible)
            {
                flags |= CLAP_PARAM_IS_HIDDEN;
            }

            return md_t()
                .asFloat()
                .withFlags(flags)
                .withID(descriptor.stableId.value)
                .withName(std::string(descriptor.displayName))
                .withGroupName(std::string(descriptor.category))
                .withRange(descriptor.minValue, descriptor.maxValue)
                .withDefault(descriptor.defaultValue);
        }

        static Param makeParam(std::string_view visualId)
        {
            const auto *descriptor = visualFloatParameterById(visualId);
            assert(descriptor);
            return Param(metadataFrom(*descriptor), std::string(descriptor->id));
        }

        Param phosphorDecay;
        Param beamIntensity;
        Param inputGain;
        Param timeScale;
        Param phosphorFastDecay;
        Param phosphorAfterglow;
        Param beamGlowStrength;
        Param beamTraceWidth;
        Param beamGlowWidth;
        Param dot1Intensity;
        Param dot1Size;
        Param dot1Halo;
        Param dot1ImageMix;
        Param dot1Rotation;
        Param dot1Aspect;
        Param dot2Intensity;
        Param dot2Size;
        Param dot2Halo;
        Param dot2ImageMix;
        Param dot2Rotation;
        Param dot2Aspect;
        Param dotOverallIntensity;
        Param dotOverallSize;
        Param dotOverallHalo;
        Param dotOverallImageMix;
        Param screenBurnPersistence;
        Param screenBurnFastDecay;
        Param screenBurnAfterglow;
        Param screenBurnFloorFade;

        std::vector<Param *> params()
        {
            std::vector<Param *> res{&phosphorDecay, &beamIntensity, &inputGain, &timeScale,
                                     &phosphorFastDecay, &phosphorAfterglow, &beamGlowStrength,
                                     &beamTraceWidth, &beamGlowWidth, &dot1Intensity, &dot1Size,
                                     &dot1Halo, &dot1ImageMix, &dot1Rotation, &dot1Aspect,
                                     &dot2Intensity, &dot2Size, &dot2Halo, &dot2ImageMix,
                                     &dot2Rotation, &dot2Aspect, &dotOverallIntensity,
                                     &dotOverallSize, &dotOverallHalo, &dotOverallImageMix,
                                     &screenBurnPersistence, &screenBurnFastDecay,
                                     &screenBurnAfterglow, &screenBurnFloorFade};
            return res;
        }

        ScopeVisualState visualState() const
        {
            ScopeVisualState state;
            state.phosphorDecay = phosphorDecay.value;
            state.beamIntensity = beamIntensity.value;
            state.inputGain = inputGain.value;
            state.timeScale = timeScale.value;
            state.phosphorFastDecay = phosphorFastDecay.value;
            state.phosphorAfterglow = phosphorAfterglow.value;
            state.beamGlowStrength = beamGlowStrength.value;
            state.beamTraceWidth = beamTraceWidth.value;
            state.beamGlowWidth = beamGlowWidth.value;
            state.dot1Intensity = dot1Intensity.value;
            state.dot1Size = dot1Size.value;
            state.dot1Halo = dot1Halo.value;
            state.dot1ImageMix = dot1ImageMix.value;
            state.dot1Rotation = dot1Rotation.value;
            state.dot1Aspect = dot1Aspect.value;
            state.dot2Intensity = dot2Intensity.value;
            state.dot2Size = dot2Size.value;
            state.dot2Halo = dot2Halo.value;
            state.dot2ImageMix = dot2ImageMix.value;
            state.dot2Rotation = dot2Rotation.value;
            state.dot2Aspect = dot2Aspect.value;
            state.dotOverallIntensity = dotOverallIntensity.value;
            state.dotOverallSize = dotOverallSize.value;
            state.dotOverallHalo = dotOverallHalo.value;
            state.dotOverallImageMix = dotOverallImageMix.value;
            state.screenBurnPersistence = screenBurnPersistence.value;
            state.screenBurnFastDecay = screenBurnFastDecay.value;
            state.screenBurnAfterglow = screenBurnAfterglow.value;
            state.screenBurnFloorFade = screenBurnFloorFade.value;
            return sanitizedScopeVisualState(state);
        }
    };

    VisualNode visualParams;

    char name[256]{"Init"};

    Param *paramById(uint32_t id)
    {
        auto it = paramMap.find(id);
        if (it == paramMap.end())
        {
            return nullptr;
        }

        return it->second;
    }

    const Param *paramById(uint32_t id) const
    {
        auto it = paramMap.find(id);
        if (it == paramMap.end())
        {
            return nullptr;
        }

        return it->second;
    }

    float migrateParamValueFromVersion(Param *p, float value, uint32_t version);
    void migratePatchFromVersion(uint32_t version);
};
} // namespace baconpaul::sidequest_ns
#endif // PATCH_H
