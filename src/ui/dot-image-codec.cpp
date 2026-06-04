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

#include "dot-image-codec.h"

#include <algorithm>
#include <cmath>

namespace baconpaul::sidequest_ns::ui
{
juce::Image normalizeDotImageForState(const juce::Image &image)
{
    if (!image.isValid())
    {
        return {};
    }

    const auto width = image.getWidth();
    const auto height = image.getHeight();
    if (width <= 0 || height <= 0)
    {
        return {};
    }

    if (width <= kMaxDotImageDimension && height <= kMaxDotImageDimension)
    {
        return image.convertedToFormat(juce::Image::ARGB);
    }

    const auto scale =
        static_cast<float>(kMaxDotImageDimension) / static_cast<float>(std::max(width, height));
    const auto targetWidth = std::max(1, static_cast<int>(std::round(width * scale)));
    const auto targetHeight = std::max(1, static_cast<int>(std::round(height * scale)));

    auto resized = juce::Image(juce::Image::ARGB, targetWidth, targetHeight, true);
    auto graphics = juce::Graphics(resized);
    graphics.setImageResamplingQuality(juce::Graphics::highResamplingQuality);
    graphics.drawImage(image, 0, 0, targetWidth, targetHeight, 0, 0, width, height);
    return resized;
}

std::string imageToPngBase64(const juce::Image &image)
{
    auto normalized = normalizeDotImageForState(image);
    if (!normalized.isValid())
    {
        return {};
    }

    auto png = juce::PNGImageFormat();
    auto output = juce::MemoryOutputStream();
    if (!png.writeImageToStream(normalized, output))
    {
        return {};
    }
    return output.getMemoryBlock().toBase64Encoding().toStdString();
}

juce::Image imageFromPngBase64(const std::string &base64)
{
    if (base64.empty())
    {
        return {};
    }

    auto block = juce::MemoryBlock();
    if (!block.fromBase64Encoding(juce::String(base64)))
    {
        return {};
    }

    return normalizeDotImageForState(
        juce::ImageFileFormat::loadFrom(block.getData(), block.getSize()));
}
} // namespace baconpaul::sidequest_ns::ui
