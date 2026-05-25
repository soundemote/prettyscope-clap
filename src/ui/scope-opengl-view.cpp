/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#include "scope-opengl-view.h"

#include <algorithm>

namespace baconpaul::sidequest_ns::ui
{
ScopeOpenGLView::ScopeOpenGLView()
{
    openGLContext.setRenderer(this);
    openGLContext.setContinuousRepainting(true);
    openGLContext.attachTo(*this);
}

ScopeOpenGLView::~ScopeOpenGLView()
{
    openGLContext.detach();
}

void ScopeOpenGLView::setSnapshot(const ScopeAudioSnapshot &snapshot)
{
    const juce::ScopedLock lock(snapshotLock);
    latestSnapshot = snapshot;
}

void ScopeOpenGLView::resized()
{
    const juce::ScopedLock lock(snapshotLock);
    renderBounds = getLocalBounds();
}

void ScopeOpenGLView::newOpenGLContextCreated() {}

void ScopeOpenGLView::openGLContextClosing() {}

void ScopeOpenGLView::renderOpenGL()
{
    using namespace juce::gl;

    ScopeAudioSnapshot snapshot;
    juce::Rectangle<int> bounds;
    {
        const juce::ScopedLock lock(snapshotLock);
        snapshot = latestSnapshot;
        bounds = renderBounds;
    }

    const auto scale = static_cast<float>(openGLContext.getRenderingScale());
    juce::OpenGLHelpers::clear(juce::Colour(0xff05070a));

    glViewport(0, 0, juce::roundToInt(scale * bounds.getWidth()),
               juce::roundToInt(scale * bounds.getHeight()));
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glLineWidth(1.0f * scale);
    glColor4f(0.20f, 0.55f, 0.70f, 0.25f);
    glBegin(GL_LINES);
    glVertex2f(-1.0f, 0.0f);
    glVertex2f(1.0f, 0.0f);
    glVertex2f(0.0f, -1.0f);
    glVertex2f(0.0f, 1.0f);
    glEnd();

    if (snapshot.hasSignal && snapshot.frameCount > 1)
    {
        glLineWidth(2.0f * scale);
        glColor4f(0.62f, 0.88f, 1.0f, 0.90f);
        glBegin(GL_LINE_STRIP);
        for (uint32_t i = 0; i < snapshot.frameCount; ++i)
        {
            const auto x = std::clamp(snapshot.samples[0][i], -1.0f, 1.0f);
            const auto y = std::clamp(snapshot.samples[1][i], -1.0f, 1.0f);
            glVertex2f(x, y);
        }
        glEnd();
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}
} // namespace baconpaul::sidequest_ns::ui
