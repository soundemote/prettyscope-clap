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

namespace baconpaul::sidequest_ns::ui
{
void SimpleXyScopeRenderer::initialise(juce::OpenGLContext &) {}

void SimpleXyScopeRenderer::shutdown() {}

void SimpleXyScopeRenderer::render(const ScopeRenderContext &context,
                                   const ScopeAudioSnapshot &snapshot,
                                   const ScopeVisualState &visualState)
{
    using namespace juce::gl;

    juce::OpenGLHelpers::clear(juce::Colour(0xff05070a));

    glViewport(0, 0, juce::roundToInt(context.scale * context.bounds.getWidth()),
               juce::roundToInt(context.scale * context.bounds.getHeight()));
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
        glBegin(GL_LINE_STRIP);
        for (uint32_t i = 0; i < snapshot.validFrameCount(); ++i)
        {
            const auto x =
                std::clamp(snapshot.samples[0][i] * visualState.inputGain, -1.0f, 1.0f);
            const auto y =
                std::clamp(snapshot.samples[1][i] * visualState.inputGain, -1.0f, 1.0f);
            glVertex2f(x, y);
        }
        glEnd();
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}
} // namespace baconpaul::sidequest_ns::ui
