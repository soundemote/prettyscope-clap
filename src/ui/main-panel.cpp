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

        auto knob = std::make_unique<sst::jucegui::components::Knob>();
        auto knobData = std::unique_ptr<PatchContinuous>();
        createComponent(editor, *this, *param, knob, knobData);
        addAndMakeVisible(*knob);
        knobs.push_back(std::move(knob));
        knobAs.push_back(std::move(knobData));
    }
}

void MainPanel::resized()
{
    auto b = getContentArea();
    auto w = b.getWidth();
    auto x = b.getX();
    auto y = b.getY();
    auto spw = 50;
    auto sph = 70;

    for (size_t i = 0; i < knobs.size(); ++i)
    {
        if (!knobs[i])
        {
            continue;
        }

        knobs[i]->setBounds(x, y, spw - 5, sph - 5);
        x += spw;
        if (x + spw > w)
        {
            x = b.getX();
            y += sph;
        }
    }
}

} // namespace baconpaul::sidequest_ns::ui
