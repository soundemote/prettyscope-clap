/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#include "scope-opengl-view.h"

#include "simple-xy-scope-renderer.h"

namespace baconpaul::sidequest_ns::ui
{
ScopeOpenGLView::ScopeOpenGLView()
{
    renderer = std::make_unique<SimpleXyScopeRenderer>();

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

void ScopeOpenGLView::newOpenGLContextCreated()
{
    renderer->initialise(openGLContext);
}

void ScopeOpenGLView::openGLContextClosing()
{
    renderer->shutdown();
}

void ScopeOpenGLView::renderOpenGL()
{
    ScopeAudioSnapshot snapshot;
    juce::Rectangle<int> bounds;
    {
        const juce::ScopedLock lock(snapshotLock);
        snapshot = latestSnapshot;
        bounds = renderBounds;
    }

    renderer->render({openGLContext, bounds,
                      static_cast<float>(openGLContext.getRenderingScale())},
                     snapshot);
}
} // namespace baconpaul::sidequest_ns::ui
