/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_UI_SCOPE_RENDERER_H
#define PRETTYSCOPE_UI_SCOPE_RENDERER_H

#include <juce_gui_basics/juce_gui_basics.h>
#include <juce_opengl/juce_opengl.h>

#include "scope/scope-audio-snapshot.h"
#include "scope/scope-visual-state.h"

namespace baconpaul::sidequest_ns::ui
{
struct ScopeRenderContext
{
    juce::OpenGLContext &openGLContext;
    juce::Rectangle<int> bounds;
    float scale{1.0f};
};

struct IScopeRenderer
{
    virtual ~IScopeRenderer() = default;

    virtual void initialise(juce::OpenGLContext &context) = 0;
    virtual void render(const ScopeRenderContext &context, const ScopeAudioSnapshot &snapshot,
                        const ScopeVisualState &visualState) = 0;
    virtual void shutdown() = 0;
};
} // namespace baconpaul::sidequest_ns::ui

#endif // PRETTYSCOPE_UI_SCOPE_RENDERER_H
