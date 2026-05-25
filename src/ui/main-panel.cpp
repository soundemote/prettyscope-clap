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
    knobs.resize(descriptors.size());
    knobAs.resize(descriptors.size());

    for (size_t i = 0; i < descriptors.size(); ++i)
    {
        auto *param = e.patchCopy.paramMap.at(descriptors[i].stableId.value);
        createComponent(editor, *this, *param, knobs[i], knobAs[i]);
        addAndMakeVisible(*knobs[i]);
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
