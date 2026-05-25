/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_UI_PHOSPHOR_SCOPE_RENDERER_H
#define PRETTYSCOPE_UI_PHOSPHOR_SCOPE_RENDERER_H

#include "scope-renderer.h"

#include <vector>

namespace baconpaul::sidequest_ns::ui
{
class PhosphorScopeRenderer : public IScopeRenderer
{
  public:
    PhosphorScopeRenderer();
    ~PhosphorScopeRenderer() override;

    PhosphorScopeRenderer(const PhosphorScopeRenderer &) = delete;
    PhosphorScopeRenderer &operator=(const PhosphorScopeRenderer &) = delete;

    void initialise(juce::OpenGLContext &context) override;
    void render(const ScopeRenderContext &context, const ScopeAudioSnapshot &snapshot,
                const ScopeVisualState &visualState) override;
    void shutdown() override;

  private:
    struct Impl;
    std::unique_ptr<Impl> impl;
};
} // namespace baconpaul::sidequest_ns::ui

#endif // PRETTYSCOPE_UI_PHOSPHOR_SCOPE_RENDERER_H
