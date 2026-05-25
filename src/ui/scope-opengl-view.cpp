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

#include <utility>

namespace baconpaul::sidequest_ns::ui
{
ScopeOpenGLView::ScopeOpenGLView()
    : ScopeOpenGLView(std::make_unique<SimpleXyScopeRenderer>())
{
}

ScopeOpenGLView::ScopeOpenGLView(std::unique_ptr<IScopeRenderer> renderer)
    : renderer(std::move(renderer))
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

void ScopeOpenGLView::setVisualState(const ScopeVisualState &visualState)
{
    const juce::ScopedLock lock(snapshotLock);
    latestVisualState = sanitizedScopeVisualState(visualState);
}

void ScopeOpenGLView::resized()
{
    const juce::ScopedLock lock(snapshotLock);
    renderBounds = getLocalBounds();
}

void ScopeOpenGLView::newOpenGLContextCreated()
{
    if (renderer)
    {
        renderer->initialise(openGLContext);
    }
}

void ScopeOpenGLView::openGLContextClosing()
{
    if (renderer)
    {
        renderer->shutdown();
    }
}

void ScopeOpenGLView::renderOpenGL()
{
    ScopeAudioSnapshot snapshot;
    ScopeVisualState visualState;
    juce::Rectangle<int> bounds;
    {
        const juce::ScopedLock lock(snapshotLock);
        snapshot = latestSnapshot;
        visualState = latestVisualState;
        bounds = renderBounds;
    }

    if (renderer)
    {
        renderer->render({openGLContext, bounds,
                          static_cast<float>(openGLContext.getRenderingScale())},
                         snapshot, visualState);
        return;
    }

    juce::OpenGLHelpers::clear(juce::Colour(0xff05070a));
}
} // namespace baconpaul::sidequest_ns::ui
