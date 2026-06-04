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

#include "main-panel.h"
#include "plugin-editor.h"
#include "patch-data-bindings.h"
#include "scope/visual-parameters.h"

namespace baconpaul::sidequest_ns::ui
{

MainPanel::MainPanel(PluginEditor &e)
    : sst::jucegui::components::NamedPanel("Visual Parameters"), editor(e)
{
    for (size_t i = 0; i < dotImageStatusLabels.size(); ++i)
    {
        auto status = std::make_unique<juce::Label>();
        status->setJustificationType(juce::Justification::centredLeft);
        status->setColour(juce::Label::textColourId, juce::Colours::white.withAlpha(0.72f));
        addAndMakeVisible(*status);
        dotImageStatusLabels[i] = std::move(status);

        auto load = std::make_unique<juce::TextButton>("Load");
        load->onClick = [this, i]() { editor.loadDotImageOverride(i); };
        addAndMakeVisible(*load);
        dotImageLoadButtons[i] = std::move(load);

        auto save = std::make_unique<juce::TextButton>("Save");
        save->onClick = [this, i]() { editor.saveDotImage(i); };
        addAndMakeVisible(*save);
        dotImageSaveButtons[i] = std::move(save);

        auto clear = std::make_unique<juce::TextButton>("Clear");
        clear->onClick = [this, i]() { editor.clearDotImageOverride(i); };
        addAndMakeVisible(*clear);
        dotImageClearButtons[i] = std::move(clear);
    }
    refreshDotImageStatus();

    const auto descriptors = visualFloatParameters();
    knobs.reserve(descriptors.size());
    knobAs.reserve(descriptors.size());

    for (const auto &descriptor : descriptors)
    {
        auto *param = e.patchCopy.paramById(descriptor.stableId.value);
        if (!param)
        {
            SQLOG("Skipping visual control for missing parameter " << descriptor.id);
            continue;
        }

        const auto categoryName = juce::String(descriptor.category.data(),
                                               static_cast<int>(descriptor.category.size()));
        if (categories.empty() || categories.back().name != categoryName)
        {
            auto label = std::make_unique<juce::Label>();
            label->setText(categoryName, juce::dontSendNotification);
            label->setJustificationType(juce::Justification::centredLeft);
            label->setColour(juce::Label::textColourId, juce::Colours::white.withAlpha(0.72f));
            addAndMakeVisible(*label);

            auto section = CategorySection{};
            section.name = categoryName;
            section.label = std::move(label);
            categories.push_back(std::move(section));
        }

        auto knob = std::make_unique<sst::jucegui::components::Knob>();
        auto knobData = std::unique_ptr<PatchContinuous>();
        createComponent(editor, *this, *param, knob, knobData);
        addAndMakeVisible(*knob);
        categories.back().knobIndices.push_back(knobs.size());
        knobs.push_back(std::move(knob));
        knobAs.push_back(std::move(knobData));
    }
}

void MainPanel::refreshDotImageStatus()
{
    for (size_t i = 0; i < dotImageStatusLabels.size(); ++i)
    {
        if (dotImageStatusLabels[i])
        {
            dotImageStatusLabels[i]->setText(editor.dotImageStatusText(i),
                                             juce::dontSendNotification);
        }
    }
}

void MainPanel::resized()
{
    auto b = getContentArea();
    const auto right = b.getRight();
    constexpr int spw = 82;
    constexpr int sph = 82;
    constexpr int labelHeight = 20;
    constexpr int sectionGap = 4;
    constexpr int buttonWidth = 48;
    constexpr int buttonHeight = 22;
    constexpr int buttonGap = 4;

    auto y = b.getY();
    for (size_t i = 0; i < dotImageStatusLabels.size(); ++i)
    {
        auto row = juce::Rectangle<int>(b.getX(), y, b.getWidth(), buttonHeight);
        auto buttons = row.removeFromRight(buttonWidth * 3 + buttonGap * 2);
        if (dotImageClearButtons[i])
        {
            dotImageClearButtons[i]->setBounds(buttons.removeFromRight(buttonWidth));
        }
        buttons.removeFromRight(buttonGap);
        if (dotImageSaveButtons[i])
        {
            dotImageSaveButtons[i]->setBounds(buttons.removeFromRight(buttonWidth));
        }
        buttons.removeFromRight(buttonGap);
        if (dotImageLoadButtons[i])
        {
            dotImageLoadButtons[i]->setBounds(buttons.removeFromRight(buttonWidth));
        }
        if (dotImageStatusLabels[i])
        {
            dotImageStatusLabels[i]->setBounds(row);
        }
        y += buttonHeight + buttonGap;
    }
    y += sectionGap;

    for (auto &category : categories)
    {
        if (category.label)
        {
            category.label->setBounds(b.getX(), y, b.getWidth(), labelHeight);
        }
        y += labelHeight;

        auto x = b.getX();
        for (const auto index : category.knobIndices)
        {
            if (index >= knobs.size() || !knobs[index])
            {
                continue;
            }

            if (x + spw > right)
            {
                x = b.getX();
                y += sph;
            }

            knobs[index]->setBounds(x, y, spw - 5, sph - 5);
            x += spw;
        }

        if (!category.knobIndices.empty())
        {
            y += sph;
        }
        y += sectionGap;
    }
}

} // namespace baconpaul::sidequest_ns::ui
