/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#include "scope-opengl-view.h"

#include "phosphor-scope-renderer.h"
#include "simple-xy-scope-renderer.h"

#include <exception>
#include <utility>

namespace baconpaul::sidequest_ns::ui
{
ScopeOpenGLView::ScopeOpenGLView()
    : ScopeOpenGLView(std::make_unique<PhosphorScopeRenderer>())
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

void ScopeOpenGLView::setDotImages(const ScopeDotImages &dotImages)
{
    const juce::ScopedLock lock(snapshotLock);
    latestDotImages = dotImages;
}

void ScopeOpenGLView::resized()
{
    const juce::ScopedLock lock(snapshotLock);
    renderBounds = getLocalBounds();
}

void ScopeOpenGLView::mouseWheelMove(const juce::MouseEvent &event,
                                     const juce::MouseWheelDetails &wheel)
{
    juce::Component::mouseWheelMove(event, wheel);
    if (onSignalGainWheel)
    {
        onSignalGainWheel(wheel.deltaY != 0.0f ? wheel.deltaY : wheel.deltaX);
    }
}

void ScopeOpenGLView::newOpenGLContextCreated()
{
    if (renderer)
    {
        try
        {
            renderer->initialise(openGLContext);
        }
        catch (const std::exception &e)
        {
            installFallbackRenderer(e.what());
        }
        catch (...)
        {
            installFallbackRenderer("unknown OpenGL renderer initialization failure");
        }
    }
}

void ScopeOpenGLView::openGLContextClosing()
{
    if (renderer)
    {
        try
        {
            renderer->shutdown();
        }
        catch (...)
        {
            juce::Logger::writeToLog(
                "Prettyscope renderer shutdown failed; continuing editor teardown");
        }
    }
}

void ScopeOpenGLView::renderOpenGL()
{
    ScopeAudioSnapshot snapshot;
    ScopeVisualState visualState;
    ScopeDotImages dotImages;
    juce::Rectangle<int> bounds;
    {
        const juce::ScopedLock lock(snapshotLock);
        snapshot = latestSnapshot;
        visualState = latestVisualState;
        dotImages = latestDotImages;
        bounds = renderBounds;
    }

    if (renderer)
    {
        try
        {
            renderer->render({openGLContext, bounds,
                              static_cast<float>(openGLContext.getRenderingScale())},
                             snapshot, visualState, dotImages);
        }
        catch (const std::exception &e)
        {
            installFallbackRenderer(e.what());
        }
        catch (...)
        {
            installFallbackRenderer("unknown OpenGL renderer failure");
        }
        return;
    }

    juce::OpenGLHelpers::clear(juce::Colour(0xff05070a));
}

void ScopeOpenGLView::installFallbackRenderer(std::string_view reason)
{
    juce::Logger::writeToLog("Prettyscope phosphor renderer failed: " +
                             juce::String(reason.data(), reason.size()) +
                             ". Falling back to simple XY renderer.");

    if (renderer)
    {
        try
        {
            renderer->shutdown();
        }
        catch (...)
        {
        }
    }

    renderer = std::make_unique<SimpleXyScopeRenderer>();
    try
    {
        renderer->initialise(openGLContext);
    }
    catch (...)
    {
        juce::Logger::writeToLog("Prettyscope fallback renderer failed to initialize.");
        renderer.reset();
    }
}
} // namespace baconpaul::sidequest_ns::ui
