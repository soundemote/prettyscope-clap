/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#ifndef PRETTYSCOPE_UI_SCOPE_SNAPSHOT_INSPECTOR_H
#define PRETTYSCOPE_UI_SCOPE_SNAPSHOT_INSPECTOR_H

#include <juce_gui_basics/juce_gui_basics.h>

#include "scope/scope-audio-snapshot.h"

namespace baconpaul::sidequest_ns::ui
{
struct ScopeSnapshotInspector : juce::Component
{
    void setSnapshot(const ScopeAudioSnapshot &snapshot);
    void paint(juce::Graphics &g) override;

  private:
    float leftPeak{0.0f};
    float rightPeak{0.0f};
    uint32_t frameCount{0};
    bool hasSignal{false};
};
} // namespace baconpaul::sidequest_ns::ui

#endif // PRETTYSCOPE_UI_SCOPE_SNAPSHOT_INSPECTOR_H
