/*
 * SideQuest Starting Point
 *
 * Basically lets paul bootstrap his projects.
 *
 * Copyright 2024-2025, Paul Walker and Various authors, as described in the github
 * transaction log.
 *
 * This source repo is released under the MIT license, but has
 * GPL3 dependencies, as such the combined work will be
 * released under GPL3.
 *
 * The source code and license are at https://github.com/baconpaul/sidequest-startingpoint
 */

#ifndef BACONPAUL_SIDEQUEST_UI_DOT_IMAGE_CODEC_H
#define BACONPAUL_SIDEQUEST_UI_DOT_IMAGE_CODEC_H

#include <juce_graphics/juce_graphics.h>

#include <string>

namespace baconpaul::sidequest_ns::ui
{
inline constexpr int kMaxDotImageDimension = 512;

juce::Image normalizeDotImageForState(const juce::Image &image);
std::string imageToPngBase64(const juce::Image &image);
juce::Image imageFromPngBase64(const std::string &base64);
} // namespace baconpaul::sidequest_ns::ui

#endif // BACONPAUL_SIDEQUEST_UI_DOT_IMAGE_CODEC_H
