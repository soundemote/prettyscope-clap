/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * This source repo is based on baconpaul/sidequest-startingpoint and keeps
 * its inherited license obligations. See the repository license files.
 */

#include "scope-snapshot-inspector.h"

#include <algorithm>

namespace baconpaul::sidequest_ns::ui
{
void ScopeSnapshotInspector::setSnapshot(const ScopeAudioSnapshot &snapshot)
{
    hasSignal = snapshot.hasSignal;
    frameCount = snapshot.frameCount;
    leftPeak = snapshot.peak(0);
    rightPeak = snapshot.peak(1);

    repaint();
}

void ScopeSnapshotInspector::paint(juce::Graphics &g)
{
    auto bounds = getLocalBounds().toFloat();
    g.setColour(juce::Colours::black.withAlpha(0.20f));
    g.fillRoundedRectangle(bounds, 3.0f);

    g.setColour(juce::Colours::white.withAlpha(0.12f));
    g.drawRoundedRectangle(bounds.reduced(0.5f), 3.0f, 1.0f);

    auto labelArea = getLocalBounds().reduced(8, 4).removeFromLeft(92);
    g.setFont(juce::FontOptions(12.0f));
    g.setColour(juce::Colours::white.withAlpha(0.72f));
    g.drawText("Scope Input", labelArea, juce::Justification::centredLeft);

    auto meterArea = getLocalBounds().reduced(108, 8);
    auto leftArea = meterArea.removeFromTop(meterArea.getHeight() / 2 - 2);
    meterArea.removeFromTop(4);
    auto rightArea = meterArea;

    auto drawMeter = [&g](juce::Rectangle<int> area, float peak, juce::Colour colour)
    {
        const auto normalized = std::clamp(peak, 0.0f, 1.0f);
        g.setColour(juce::Colours::white.withAlpha(0.08f));
        g.fillRect(area);
        g.setColour(colour.withAlpha(0.72f));
        g.fillRect(area.withWidth(static_cast<int>(area.getWidth() * normalized)));
    };

    const auto activeColour = hasSignal ? juce::Colour(0xff86d7ff) : juce::Colours::grey;
    drawMeter(leftArea, leftPeak, activeColour);
    drawMeter(rightArea, rightPeak, activeColour);

    g.setFont(juce::FontOptions(10.0f));
    g.setColour(juce::Colours::white.withAlpha(0.45f));
    g.drawText(juce::String(frameCount) + " frames", getLocalBounds().reduced(8, 4),
               juce::Justification::bottomRight);
}
} // namespace baconpaul::sidequest_ns::ui
