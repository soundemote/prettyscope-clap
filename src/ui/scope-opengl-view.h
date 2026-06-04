/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_UI_SCOPE_OPENGL_VIEW_H
#define PRETTYSCOPE_UI_SCOPE_OPENGL_VIEW_H

#include <juce_gui_basics/juce_gui_basics.h>
#include <juce_opengl/juce_opengl.h>

#include <functional>

#include "scope/scope-audio-snapshot.h"
#include "scope-renderer.h"

namespace baconpaul::sidequest_ns::ui
{
struct ScopeOpenGLView : juce::Component, private juce::OpenGLRenderer
{
    ScopeOpenGLView();
    explicit ScopeOpenGLView(std::unique_ptr<IScopeRenderer> renderer);
    ~ScopeOpenGLView() override;

    void setSnapshot(const ScopeAudioSnapshot &snapshot);
    void setVisualState(const ScopeVisualState &visualState);
    void setDotImages(const ScopeDotImages &dotImages);
    void resized() override;
    void mouseWheelMove(const juce::MouseEvent &event, const juce::MouseWheelDetails &wheel) override;

    std::function<void(float wheelDelta)> onSignalGainWheel;

  private:
    void newOpenGLContextCreated() override;
    void renderOpenGL() override;
    void openGLContextClosing() override;
    void installFallbackRenderer(std::string_view reason);

    juce::OpenGLContext openGLContext;
    std::unique_ptr<IScopeRenderer> renderer;
    juce::CriticalSection snapshotLock;
    ScopeAudioSnapshot latestSnapshot;
    ScopeVisualState latestVisualState;
    ScopeDotImages latestDotImages;
    juce::Rectangle<int> renderBounds;
};
} // namespace baconpaul::sidequest_ns::ui

#endif // PRETTYSCOPE_UI_SCOPE_OPENGL_VIEW_H
