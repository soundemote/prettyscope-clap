/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_UI_SIMPLE_XY_SCOPE_RENDERER_H
#define PRETTYSCOPE_UI_SIMPLE_XY_SCOPE_RENDERER_H

#include "scope-renderer.h"

namespace baconpaul::sidequest_ns::ui
{
struct SimpleXyScopeRenderer : IScopeRenderer
{
    void initialise(juce::OpenGLContext &context) override;
    void render(const ScopeRenderContext &context, const ScopeAudioSnapshot &snapshot) override;
    void shutdown() override;
};
} // namespace baconpaul::sidequest_ns::ui

#endif // PRETTYSCOPE_UI_SIMPLE_XY_SCOPE_RENDERER_H
