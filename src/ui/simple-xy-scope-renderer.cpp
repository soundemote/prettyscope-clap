/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#include "simple-xy-scope-renderer.h"

#include <algorithm>
#include <cmath>

namespace baconpaul::sidequest_ns::ui
{
namespace
{
bool isDiscontinuity(const ScopeAudioSnapshot &snapshot, uint32_t previousIndex, uint32_t index,
                     int skipSamples)
{
    if (skipSamples <= 0)
    {
        return false;
    }

    constexpr float jumpThreshold = 0.85f;
    return std::abs(snapshot.samples[0][index] - snapshot.samples[0][previousIndex]) >
               jumpThreshold ||
           std::abs(snapshot.samples[1][index] - snapshot.samples[1][previousIndex]) >
               jumpThreshold;
}
} // namespace

void SimpleXyScopeRenderer::initialise(juce::OpenGLContext &) {}

void SimpleXyScopeRenderer::shutdown() {}

void SimpleXyScopeRenderer::render(const ScopeRenderContext &context,
                                   const ScopeAudioSnapshot &snapshot,
                                   const ScopeVisualState &visualState,
                                   const ScopeDotImages &)
{
    using namespace juce::gl;

    juce::OpenGLHelpers::clear(juce::Colour(0xff05070a));
    if (!context.hasDrawableArea())
    {
        return;
    }

    glViewport(0, 0, context.pixelWidth(), context.pixelHeight());
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glLineWidth(1.0f * context.scale);
    glColor4f(0.20f, 0.55f, 0.70f, 0.25f);
    glBegin(GL_LINES);
    glVertex2f(-1.0f, 0.0f);
    glVertex2f(1.0f, 0.0f);
    glVertex2f(0.0f, -1.0f);
    glVertex2f(0.0f, 1.0f);
    glEnd();

    if (snapshot.hasRenderableTrace())
    {
        glLineWidth(2.0f * context.scale);
        const auto beamAlpha =
            std::clamp(0.90f * visualState.beamIntensity / 1.6f, 0.0f, 1.0f);
        glColor4f(0.62f, 0.88f, 1.0f, beamAlpha);
        glBegin(GL_LINES);
        const auto skipSamples =
            std::clamp(static_cast<int>(std::round(visualState.discontinuitySkipSamples)), 0, 2);
        uint32_t skipThroughIndex = 0;
        for (uint32_t i = 1; i < snapshot.validFrameCount(); ++i)
        {
            if (i <= skipThroughIndex)
            {
                continue;
            }

            if (isDiscontinuity(snapshot, i - 1, i, skipSamples))
            {
                skipThroughIndex =
                    std::max(skipThroughIndex, i + static_cast<uint32_t>(skipSamples) - 1);
                continue;
            }

            const auto x0 =
                std::clamp(snapshot.samples[0][i - 1] * visualState.inputGain, -1.0f, 1.0f);
            const auto y0 =
                std::clamp(snapshot.samples[1][i - 1] * visualState.inputGain, -1.0f, 1.0f);
            const auto x1 =
                std::clamp(snapshot.samples[0][i] * visualState.inputGain, -1.0f, 1.0f);
            const auto y1 =
                std::clamp(snapshot.samples[1][i] * visualState.inputGain, -1.0f, 1.0f);
            glVertex2f(x0, y0);
            glVertex2f(x1, y1);
        }
        glEnd();
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}
} // namespace baconpaul::sidequest_ns::ui
