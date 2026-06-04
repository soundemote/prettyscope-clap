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

#include "plugin-editor.h"

#include "sst/plugininfra/version_information.h"
#include "sst/clap_juce_shim/menu_helper.h"
#include "sst/plugininfra/misc_platform.h"

#include "sst/jucegui/components/Label.h"

#include "presets/preset-manager.h"
#include "preset-data-binding.h"
#include "patch-data-bindings.h"
#include "dot-image-codec.h"
#include "main-panel.h"
#include "scope-opengl-view.h"
#include "scope-snapshot-inspector.h"

#include <algorithm>
#include <cmath>

namespace baconpaul::sidequest_ns::ui
{
struct IdleTimer : juce::Timer
{
    PluginEditor &editor;
    IdleTimer(PluginEditor &e) : editor(e) {}
    void timerCallback() override { editor.idle(); }
};

namespace jstl = sst::jucegui::style;
using sheet_t = jstl::StyleSheet;
static constexpr sheet_t::Class PatchMenu("prettyscope.patch-menu");

namespace
{
juce::Image createGeneratedDotImage(const ScopeVisualState &state, size_t dotIndex)
{
    constexpr int imageSize = 256;
    constexpr float pi = 3.14159265358979323846f;

    const auto isDot2 = dotIndex == 1;
    const auto dotSize = (isDot2 ? state.dot2Size : state.dot1Size) * state.dotOverallSize;
    const auto dotHalo = (isDot2 ? state.dot2Halo : state.dot1Halo) * state.dotOverallHalo;
    const auto dotIntensity =
        (isDot2 ? state.dot2Intensity : state.dot1Intensity) * state.dotOverallIntensity;
    const auto dotAspect = std::clamp(isDot2 ? state.dot2Aspect : state.dot1Aspect, 0.1f, 10.0f);
    const auto dotRotation = (isDot2 ? state.dot2Rotation : state.dot1Rotation) * pi / 180.0f;

    const auto sigma = std::clamp(dotSize * 3.4f, 1.5f, 96.0f);
    const auto haloSigma = sigma * (1.0f + std::clamp(dotHalo, 0.0f, 6.0f));
    const auto cosR = std::cos(dotRotation);
    const auto sinR = std::sin(dotRotation);

    auto image = juce::Image(juce::Image::ARGB, imageSize, imageSize, true);
    const auto centre = static_cast<float>(imageSize - 1) * 0.5f;
    const auto coreColour = isDot2 ? juce::Colour(0xff86d7ff) : juce::Colour(0xffff38a8);
    const auto haloColour = juce::Colour(0xff2ed6ff);

    for (int y = 0; y < imageSize; ++y)
    {
        for (int x = 0; x < imageSize; ++x)
        {
            const auto dx = static_cast<float>(x) - centre;
            const auto dy = static_cast<float>(y) - centre;
            const auto rx = cosR * dx + sinR * dy;
            const auto ry = -sinR * dx + cosR * dy;
            const auto ax = rx / dotAspect;
            const auto r2 = ax * ax + ry * ry;
            const auto core = std::exp(-r2 / (2.0f * sigma * sigma)) * dotIntensity;
            const auto halo = std::exp(-r2 / (2.0f * haloSigma * haloSigma)) * dotHalo * 0.22f;
            const auto alpha = std::clamp(core + halo, 0.0f, 1.0f);
            if (alpha <= 0.001f)
            {
                continue;
            }

            const auto mix = std::clamp(halo / std::max(core + halo, 0.0001f), 0.0f, 1.0f);
            const auto colour = coreColour.interpolatedWith(haloColour, mix).withAlpha(alpha);
            image.setPixelAt(x, y, colour);
        }
    }

    return image;
}

juce::String dotName(size_t dotIndex)
{
    return dotIndex == 1 ? "Dot 2" : "Dot 1";
}

juce::String compactDotImageLabel(const juce::String &label)
{
    constexpr int maxLabelLength = 28;
    if (label.length() <= maxLabelLength)
    {
        return label;
    }

    const auto extension = juce::File(label).getFileExtension();
    const auto extensionLength = extension.length();
    const auto suffixLength = std::min(extensionLength + 8, maxLabelLength - 4);
    const auto prefixLength = maxLabelLength - suffixLength - 3;

    return label.substring(0, prefixLength) + "..." +
           label.substring(label.length() - suffixLength);
}
} // namespace

PluginEditor::PluginEditor(Engine::audioToUIQueue_t &atou, Engine::mainToAudioQueue_T &utoa,
                           ScopeAudioSnapshotQueue &snapshots, const clap_host_t *h)
    : jcmp::WindowPanel(true), audioToUI(atou), mainToAudio(utoa), scopeSnapshots(snapshots),
      clapHost(h)
{
    setTitle("Prettyscope");
    setAccessible(true);
    sst::jucegui::style::StyleSheet::initializeStyleSheets([]() {});

    sheet_t::addClass(PatchMenu).withBaseClass(jcmp::JogUpDownButton::Styles::styleClass);

    setStyle(sst::jucegui::style::StyleSheet::getBuiltInStyleSheet(
        sst::jucegui::style::StyleSheet::DARK));

    style()->setFont(
        PatchMenu, jcmp::MenuButton::Styles::labelfont,
        style()
            ->getFont(jcmp::MenuButton::Styles::styleClass, jcmp::MenuButton::Styles::labelfont)
            .withHeight(18));

    mainPanel = std::make_unique<MainPanel>(*this);
    mainPanel->hasHamburger = false;
    mainPanelViewport = std::make_unique<juce::Viewport>("Visual Parameter Viewport");
    mainPanelViewport->setScrollBarsShown(true, false);
    mainPanelViewport->setViewedComponent(mainPanel.get(), false);
    addAndMakeVisible(*mainPanelViewport);

    scopeOpenGLView = std::make_unique<ScopeOpenGLView>();
    scopeOpenGLView->setVisualState(currentScopeVisualState());
    scopeOpenGLView->setDotImages(currentScopeDotImages());
    addAndMakeVisible(*scopeOpenGLView);

    scopeInspector = std::make_unique<ScopeSnapshotInspector>();
    addAndMakeVisible(*scopeInspector);

    auto startMsg = Engine::MainToAudioMsg{Engine::MainToAudioMsg::REQUEST_REFRESH};
    mainToAudio.push(startMsg);
    requestParamsFlush();

    idleTimer = std::make_unique<IdleTimer>(*this);
    idleTimer->startTimer(1000. / 60.);

    toolTip = std::make_unique<jcmp::ToolTip>();
    addChildComponent(*toolTip);

    presetManager = std::make_unique<presets::PresetManager>(clapHost);
    presetManager->onPresetLoaded = [this](auto s)
    {
        this->applyPatchDotImagesToEditor();
        this->postPatchChange(s);
        repaint();
    };

    presetDataBinding = std::make_unique<PresetDataBinding>(*presetManager, patchCopy, mainToAudio);
    presetDataBinding->setStateForDisplayName(patchCopy.name);

    presetButton = std::make_unique<jcmp::JogUpDownButton>();
    presetButton->setCustomClass(PatchMenu);
    presetButton->setSource(presetDataBinding.get());
    presetButton->onPopupMenu = [this]() { showPresetPopup(); };
    addAndMakeVisible(*presetButton);
    setPatchNameDisplay();
    sst::jucegui::component_adapters::setTraversalId(presetButton.get(), 174);

    // this needs a cleanup
    defaultsProvider = std::make_unique<defaultsProvder_t>(
        presetManager->userPath, "Prettyscope", defaultName,
        [](auto e, auto b) { SQLOG("[ERROR]" << e << " " << b); });
    setSkinFromDefaults();

    lnf = std::make_unique<sst::jucegui::style::LookAndFeelManager>(this);
    lnf->setStyle(style());

    scopeSnapshots.subscribe();

    vuMeter = std::make_unique<jcmp::VUMeter>(jcmp::VUMeter::HORIZONTAL);
    addAndMakeVisible(*vuMeter);

    mainToAudio.push({Engine::MainToAudioMsg::EDITOR_ATTACH_DETATCH, true});
    mainToAudio.push({Engine::MainToAudioMsg::REQUEST_REFRESH, true});
    requestParamsFlush();

    auto pzf = defaultsProvider->getUserDefaultValue(Defaults::zoomLevel, 100);
    zoomFactor = pzf * 0.01;
    setTransform(juce::AffineTransform().scaled(zoomFactor));

    setSize(edWidth, edHeight);
#define DEBUG_FOCUS 0
#if DEBUG_FOCUS
    focusDebugger = std::make_unique<sst::jucegui::accessibility::FocusDebugger>(*this);
    focusDebugger->setDoFocusDebug(true);
#endif
}
PluginEditor::~PluginEditor()
{
    scopeSnapshots.unsubscribe();
    mainToAudio.push({Engine::MainToAudioMsg::EDITOR_ATTACH_DETATCH, false});
    idleTimer->stopTimer();
    setLookAndFeel(nullptr);
}

void PluginEditor::idle()
{
    if (auto snapshot = scopeSnapshots.readLatest())
    {
        latestScopeSnapshot = *snapshot;
        scopeSnapshotReadCount++;
        scopeOpenGLView->setSnapshot(latestScopeSnapshot);
        scopeInspector->setSnapshot(latestScopeSnapshot);
    }

    auto aum = audioToUI.pop();
    while (aum.has_value())
    {
        if (aum->action == Engine::AudioToUIMsg::UPDATE_PARAM)
        {
            setAndSendParamValue(aum->paramId, aum->value, false);
        }
        else if (aum->action == Engine::AudioToUIMsg::UPDATE_VU)
        {
            vuMeter->setLevels(aum->value, aum->value2);
        }
        else if (aum->action == Engine::AudioToUIMsg::UPDATE_VOICE_COUNT)
        {
            SQLOG_ONCE("Implement update voice count");
        }
        else if (aum->action == Engine::AudioToUIMsg::SET_PATCH_NAME)
        {
            memset(patchCopy.name, 0, sizeof(patchCopy.name));
            strncpy(patchCopy.name, aum->patchNamePointer, 255);
            setPatchNameDisplay();
        }
        else if (aum->action == Engine::AudioToUIMsg::SET_PATCH_DIRTY_STATE)
        {
            patchCopy.dirty = (bool)aum->paramId;
            presetDataBinding->setDirtyState(patchCopy.dirty);
            presetButton->repaint();
        }
        else if (aum->action == Engine::AudioToUIMsg::DO_PARAM_RESCAN)
        {
            if (clapHost && !clapParamsExtension)
                clapParamsExtension = static_cast<const clap_host_params_t *>(
                    clapHost->get_extension(clapHost, CLAP_EXT_PARAMS));
            if (clapHost && clapParamsExtension)
            {
                clapParamsExtension->rescan(clapHost,
                                            CLAP_PARAM_RESCAN_VALUES | CLAP_PARAM_RESCAN_TEXT);
                clapParamsExtension->request_flush(clapHost);
            }
        }
        else if (aum->action == Engine::AudioToUIMsg::SEND_SAMPLE_RATE)
        {
            sampleRate = aum->value;
            repaint();
        }
        else
        {
            SQLOG("Ignored patch message " << aum->action);
        }
        aum = audioToUI.pop();
    }
}

void PluginEditor::paint(juce::Graphics &g)
{
    jcmp::WindowPanel::paint(g);
    auto ft = style()->getFont(jcmp::Label::Styles::styleClass, jcmp::Label::Styles::labelfont);

    bool isLight = defaultsProvider->getUserDefaultValue(Defaults::useLightSkin, false);

    g.setColour(juce::Colours::white.withAlpha(0.9f));
    auto q = ft.withHeight(30);
    g.setFont(q);
    int np{110};
    int ht{30};

    if (isLight)
        g.setColour(juce::Colours::navy);
    else
        g.setColour(juce::Colours::white.withAlpha(0.5f));
    q = ft.withHeight(12);
    g.setFont(q);

    g.drawText(PRODUCT_NAME, getLocalBounds().reduced(3, 3), juce::Justification::bottomLeft);

    std::string os = "";
#if JUCE_MAC
    os = "macOS";
#endif
#if JUCE_WINDOWS
    os = "Windows";
#endif
#if JUCE_LINUX
    os = "Linux";
#endif

    auto bi = os + " " + sst::plugininfra::VersionInformation::git_commit_hash;
    bi += fmt::format(" @ {:.1f}k", sampleRate / 1000.0);
    g.drawText(bi, getLocalBounds().reduced(3, 3), juce::Justification::bottomRight);

    g.drawText(sst::plugininfra::VersionInformation::git_implied_display_version,
               getLocalBounds().reduced(3, 3), juce::Justification::centredBottom);

    g.setColour(juce::Colours::white);
    g.setFont(juce::FontOptions(25));
    auto dr = juce::Rectangle<int>(0, 0, np, ht);
    g.drawText(PRODUCT_NAME, dr.reduced(2), juce::Justification::centredLeft);
}

void PluginEditor::resized()
{
    int presetHeight{33}, scopeHeight{320}, inspectorHeight{44}, footerHeight{15};

    auto lb = getLocalBounds();
    auto presetArea = lb.withHeight(presetHeight);
    auto contentArea = lb.withTrimmedTop(presetHeight).withTrimmedBottom(footerHeight);
    auto inspectorArea = contentArea.removeFromBottom(inspectorHeight);
    auto scopeArea = contentArea.removeFromBottom(scopeHeight);
    auto panelArea = contentArea;

    auto panelMargin{3};
    auto uicMargin{4};
    // Preset button
    auto but = presetArea.reduced(110, 0).withTrimmedTop(uicMargin);
    presetButton->setBounds(but);
    but = but.withLeft(presetButton->getRight() + uicMargin).withRight(getWidth() - uicMargin);

    vuMeter->setBounds(but);

    scopeOpenGLView->setBounds(scopeArea.reduced(panelMargin, 5));
    scopeInspector->setBounds(inspectorArea.reduced(panelMargin, 5));
    auto visualPanelArea = panelArea.reduced(panelMargin);
    mainPanelViewport->setBounds(visualPanelArea);
    const auto panelWidth = std::max(1, mainPanelViewport->getMaximumVisibleWidth());
    mainPanel->setSize(panelWidth, visualPanelArea.getHeight());
    mainPanel->setSize(panelWidth, std::max(visualPanelArea.getHeight(),
                                            mainPanel->getPreferredHeight(panelWidth)));
}

void PluginEditor::showTooltipOn(juce::Component *c)
{
    if (!c || !toolTip)
    {
        return;
    }

    int x = 0;
    int y = 0;
    juce::Component *component = c;
    while (component && component != this)
    {
        auto bounds = component->getBoundsInParent();
        x += bounds.getX();
        y += bounds.getY();

        component = component->getParentComponent();
    }
    if (component != this)
    {
        return;
    }

    y += c->getHeight();
    toolTip->resetSizeFromData();
    if (y + toolTip->getHeight() > getHeight() - 40)
    {
        y -= c->getHeight() + 3 + toolTip->getHeight();
    }

    if (x + toolTip->getWidth() > getWidth())
    {
        x -= toolTip->getWidth();
        x += c->getWidth() - 3;
    }

    toolTip->setTopLeftPosition(x, y);
    toolTip->setVisible(true);
}
void PluginEditor::updateTooltip(jdat::Continuous *c)
{
    if (!c || !toolTip)
    {
        return;
    }

    toolTip->setTooltipTitleAndData(c->getLabel(), {c->getValueAsString()});
    toolTip->resetSizeFromData();
}
void PluginEditor::updateTooltip(jdat::Discrete *d)
{
    if (!d || !toolTip)
    {
        return;
    }

    toolTip->setTooltipTitleAndData(d->getLabel(), {d->getValueAsString()});
    toolTip->resetSizeFromData();
}
void PluginEditor::hideTooltip()
{
    if (toolTip)
    {
        toolTip->setVisible(false);
    }
}

struct MenuValueTypein : HasEditor, juce::PopupMenu::CustomComponent, juce::TextEditor::Listener
{
    std::unique_ptr<juce::TextEditor> textEditor;
    juce::Component::SafePointer<jcmp::ContinuousParamEditor> underComp;

    MenuValueTypein(PluginEditor &editor,
                    juce::Component::SafePointer<jcmp::ContinuousParamEditor> under)
        : juce::PopupMenu::CustomComponent(false), HasEditor(editor), underComp(under)
    {
        textEditor = std::make_unique<juce::TextEditor>();
        textEditor->setWantsKeyboardFocus(true);
        textEditor->addListener(this);
        textEditor->setIndents(2, 0);

        addAndMakeVisible(*textEditor);
    }

    void getIdealSize(int &w, int &h) override
    {
        w = 180;
        h = 22;
    }
    void resized() override { textEditor->setBounds(getLocalBounds().reduced(3, 1)); }

    void visibilityChanged() override
    {
        juce::Timer::callAfterDelay(
            2,
            [this]()
            {
                if (textEditor->isVisible())
                {
                    textEditor->setText(getInitialText(),
                                        juce::NotificationType::dontSendNotification);
                    auto valCol = juce::Colour(0xFF, 0x90, 0x00);
                    textEditor->setColour(juce::TextEditor::ColourIds::backgroundColourId,
                                          valCol.withAlpha(0.1f));
                    textEditor->setColour(juce::TextEditor::ColourIds::highlightColourId,
                                          valCol.withAlpha(0.15f));
                    textEditor->setJustification(juce::Justification::centredLeft);
                    textEditor->setColour(juce::TextEditor::ColourIds::outlineColourId,
                                          juce::Colours::black.withAlpha(0.f));
                    textEditor->setColour(juce::TextEditor::ColourIds::focusedOutlineColourId,
                                          juce::Colours::black.withAlpha(0.f));
                    textEditor->setBorder(juce::BorderSize<int>(3));
                    textEditor->applyColourToAllText(valCol, true);
                    textEditor->grabKeyboardFocus();
                    textEditor->selectAll();
                }
            });
    }

    std::string getInitialText() const { return underComp->continuous()->getValueAsString(); }

    void setValueString(const std::string &s)
    {
        if (underComp && underComp->continuous())
        {
            underComp->onBeginEdit();

            if (s.empty())
            {
                underComp->continuous()->setValueFromGUI(
                    underComp->continuous()->getDefaultValue());
            }
            else
            {
                underComp->continuous()->setValueAsString(s);
            }
            underComp->onEndEdit();
            underComp->repaint();
            underComp->grabKeyboardFocus();
            underComp->notifyAccessibleChange();
        }
    }

    void textEditorReturnKeyPressed(juce::TextEditor &ed) override
    {
        auto s = ed.getText().toStdString();
        setValueString(s);
        triggerMenuItem();
    }
    void textEditorEscapeKeyPressed(juce::TextEditor &) override { triggerMenuItem(); }
};

void PluginEditor::popupMenuForContinuous(jcmp::ContinuousParamEditor *e)
{
    auto data = e->continuous();
    if (!data)
    {
        return;
    }

    if (!e->isEnabled())
    {
        return;
    }

    auto p = juce::PopupMenu();
    p.addSectionHeader(data->getLabel());
    p.addSeparator();
    p.addCustomItem(-1, std::make_unique<MenuValueTypein>(*this, juce::Component::SafePointer(e)));
    p.addSeparator();
    p.addItem("Set to Default",
              [w = juce::Component::SafePointer(e)]()
              {
                  if (!w)
                      return;
                  w->continuous()->setValueFromGUI(w->continuous()->getDefaultValue());
                  w->repaint();
              });

    // I could also stick the param id onto the component properties I guess
    auto pid = sst::jucegui::component_adapters::getClapParamId(e);
    if (clapHost && pid.has_value())
    {
        sst::clap_juce_shim::populateMenuForClapParam(p, *pid, clapHost);
    }

    p.showMenuAsync(juce::PopupMenu::Options().withParentComponent(this));
}

void PluginEditor::showPresetPopup()
{
    auto p = juce::PopupMenu();
    p.addSectionHeader("Main Menu");

    auto f = juce::PopupMenu();
    for (auto &[c, ent] : presetManager->factoryPatchNames)
    {
        auto em = juce::PopupMenu();
        for (auto &e : ent)
        {
            auto noExt = e;
            auto ps = noExt.find(PATCH_EXTENSION);
            if (ps != std::string::npos)
            {
                noExt = noExt.substr(0, ps);
            }
            em.addItem(noExt,
                       [cat = c, pat = e, this]() {
                           this->presetManager->loadFactoryPreset(patchCopy, mainToAudio, cat, pat);
                       });
        }
        f.addSubMenu(c, em);
    }

    auto u = juce::PopupMenu();
    auto cat = fs::path();
    auto s = juce::PopupMenu();
    for (const auto &up : presetManager->userPatches)
    {
        auto pp = up.parent_path();
        auto dn = up.filename().replace_extension("").u8string();
        if (pp.empty())
        {
            u.addItem(dn,
                      [this, pth = up, dn]()
                      {
                          presetManager->loadUserPresetDirect(patchCopy, mainToAudio,
                                                              presetManager->userPatchesPath / pth);
                      });
        }
        else
        {
            if (pp != cat)
            {
                if (cat.empty())
                {
                    u.addSeparator();
                }
                if (s.getNumItems() > 0)
                {
                    u.addSubMenu(cat.u8string(), s);
                    s = juce::PopupMenu();
                }
                cat = pp;
            }
            s.addItem(dn,
                      [this, pth = up, dn]()
                      {
                          presetManager->loadUserPresetDirect(patchCopy, mainToAudio,
                                                              presetManager->userPatchesPath / pth);
                      });
        }
    }
    if (s.getNumItems() > 0 && !cat.empty())
    {
        u.addSubMenu(cat.u8string(), s);
    }
    p.addSeparator();
    p.addSubMenu("Factory Presets", f);
    p.addSubMenu("User Presets", u);
    p.addSeparator();
    p.addItem("Load Patch",
              [w = juce::Component::SafePointer(this)]()
              {
                  if (w)
                      w->doLoadPatch();
              });
    p.addItem("Save Patch",
              [w = juce::Component::SafePointer(this)]()
              {
                  if (w)
                      w->doSavePatch();
              });
    p.addSeparator();
    p.addItem("Reset to Init",
              [w = juce::Component::SafePointer(this)]()
              {
                  if (w)
                  {
                      w->resetToDefault();
                  }
              });
    p.addSeparator();

    auto uim = juce::PopupMenu();
    auto isLight = defaultsProvider->getUserDefaultValue(Defaults::useLightSkin, 0);

    for (auto scale : {75, 90, 100, 110, 125, 150})
    {
        uim.addItem("Zoom " + std::to_string(scale) + "%", true,
                    std::fabs(zoomFactor * 100 - scale) < 2,
                    [s = scale, w = juce::Component::SafePointer(this)]()
                    {
                        if (!w)
                            return;
                        w->setZoomFactor(s * 0.01);
                    });
    }

    uim.addSeparator();
    uim.addItem("Dark Mode", true, !isLight,
                [w = juce::Component::SafePointer(this)]()
                {
                    if (!w)
                        return;
                    w->defaultsProvider->updateUserDefaultValue(Defaults::useLightSkin, false);
                    w->setSkinFromDefaults();
                });

    uim.addItem("Light Mode", true, isLight,
                [w = juce::Component::SafePointer(this)]()
                {
                    if (!w)
                        return;
                    w->defaultsProvider->updateUserDefaultValue(Defaults::useLightSkin, true);
                    w->setSkinFromDefaults();
                });
    uim.addSeparator();

    uim.addItem("Activate Debug Log", true, debugLevel > 0,
                [w = juce::Component::SafePointer(this)]()
                {
                    if (w)
                        w->toggleDebug();
                });

#if JUCE_WINDOWS
    auto swr = defaultsProvider->getUserDefaultValue(Defaults::useSoftwareRenderer, false);

    uim.addItem(
        "Use Software Renderer", true, swr,
        [w = juce::Component::SafePointer(this), swr]()
        {
            if (!w)
                return;
            w->defaultsProvider->updateUserDefaultValue(Defaults::useSoftwareRenderer, !swr);
            juce::AlertWindow::showMessageBoxAsync(
                juce::AlertWindow::WarningIcon, "Software Renderer Change",
                "A software renderer change is only active once you restart/reload the plugin.");
        });
#endif

    p.addSubMenu("User Interface", uim);

    p.addSeparator();
    p.addItem("Get the Source",
              []() {
                  juce::URL("https://github.com/soundemote/prettyscope-clap/")
                      .launchInDefaultBrowser();
              });
    p.addItem("Report Feedback",
              []() {
                  juce::URL("https://github.com/soundemote/prettyscope-clap/issues")
                      .launchInDefaultBrowser();
              });
    p.showMenuAsync(juce::PopupMenu::Options().withParentComponent(this));
}

void PluginEditor::doSavePatch()
{
    auto svP = presetManager->userPatchesPath;
    if (strcmp(patchCopy.name, "Init") != 0)
    {
        svP = (svP / patchCopy.name).replace_extension(PATCH_EXTENSION);
    }
    fileChooser = std::make_unique<juce::FileChooser>("Save Patch", juce::File(svP.u8string()),
                                                      juce::String("*") + PATCH_EXTENSION);
    fileChooser->launchAsync(juce::FileBrowserComponent::canSelectFiles |
                                 juce::FileBrowserComponent::saveMode |
                                 juce::FileBrowserComponent::warnAboutOverwriting,
                             [w = juce::Component::SafePointer(this)](const juce::FileChooser &c)
                             {
                                 if (!w)
                                     return;
                                 auto result = c.getResults();
                                 if (result.isEmpty() || result.size() > 1)
                                 {
                                     return;
                                 }
                                 auto pn = fs::path{result[0].getFullPathName().toStdString()};
                                 w->setPatchNameTo(pn.filename().replace_extension("").u8string());
                                 w->syncPatchDotImagesFromEditor();

#if USE_WCHAR_PRESET
                                 w->presetManager->saveUserPresetDirect(
                                     w->patchCopy, result[0].getFullPathName().toUTF16());
#else
                                 w->presetManager->saveUserPresetDirect(w->patchCopy, pn);
#endif

                                 w->presetDataBinding->setDirtyState(false);
                                 w->repaint();
                             });
}

void PluginEditor::setPatchNameTo(const std::string &s)
{
    memset(patchCopy.name, 0, sizeof(patchCopy.name));
    strncpy(patchCopy.name, s.c_str(), 255);
    mainToAudio.push({Engine::MainToAudioMsg::SEND_PATCH_NAME, 0, 0, patchCopy.name});
    setPatchNameDisplay();
}

void PluginEditor::doLoadPatch()
{
    fileChooser = std::make_unique<juce::FileChooser>(
        "Load Patch", juce::File(presetManager->userPatchesPath.u8string()),
        juce::String("*") + PATCH_EXTENSION);
    fileChooser->launchAsync(
        juce::FileBrowserComponent::canSelectFiles | juce::FileBrowserComponent::openMode,
        [w = juce::Component::SafePointer(this)](const juce::FileChooser &c)
        {
            if (!w)
                return;
            auto result = c.getResults();
            if (result.isEmpty() || result.size() > 1)
            {
                return;
            }
            auto loadPath = fs::path{result[0].getFullPathName().toStdString()};
            w->presetManager->loadUserPresetDirect(w->patchCopy, w->mainToAudio, loadPath);
        });
}

void PluginEditor::resetToDefault() { presetManager->loadInit(patchCopy, mainToAudio); }

void PluginEditor::setAndSendParamValue(uint32_t paramId, float value, bool notifyAudio,
                                        bool sendBeginEnd)
{
    auto *param = patchCopy.paramById(paramId);
    if (!param)
    {
        SQLOG("Ignoring editor update for unknown parameter id " << paramId);
        return;
    }

    param->value = value;

    auto rit = componentRefreshByID.find(paramId);
    if (rit != componentRefreshByID.end())
    {
        rit->second();
    }

    auto pit = componentByID.find(paramId);
    if (pit != componentByID.end() && pit->second)
        pit->second->repaint();

    if (notifyAudio)
    {
        if (sendBeginEnd)
            mainToAudio.push({Engine::MainToAudioMsg::Action::BEGIN_EDIT, paramId});
        mainToAudio.push({Engine::MainToAudioMsg::Action::SET_PARAM, paramId, value});
        if (sendBeginEnd)
            mainToAudio.push({Engine::MainToAudioMsg::Action::END_EDIT, paramId});
        requestParamsFlush();
    }

    if (scopeOpenGLView && param->visualParameterId.size() > 0)
    {
        refreshScopeVisualState();
    }
}

void PluginEditor::setPatchNameDisplay()
{
    if (!presetButton)
        return;
    presetDataBinding->setStateForDisplayName(patchCopy.name);
    presetButton->repaint();
}

void PluginEditor::postPatchChange(const std::string &s)
{
    presetDataBinding->setStateForDisplayName(s);
    for (auto [id, f] : componentRefreshByID)
        f();

    refreshScopeVisualState();
    repaint();
}

bool PluginEditor::keyPressed(const juce::KeyPress &key) { return false; }

void PluginEditor::visibilityChanged()
{
    if (isVisible() && isShowing())
    {
        presetButton->setWantsKeyboardFocus(true);
        presetButton->grabKeyboardFocus();
    }
}

void PluginEditor::parentHierarchyChanged()
{
    if (isVisible() && isShowing())
    {
        presetButton->setWantsKeyboardFocus(true);
        presetButton->grabKeyboardFocus();
    }

#if JUCE_WINDOWS
    auto swr = defaultsProvider->getUserDefaultValue(Defaults::useSoftwareRenderer, false);

    if (swr)
    {
        if (auto peer = getPeer())
        {
            SQLOG("Enabling software rendering engine");
            peer->setCurrentRenderingEngine(0); // 0 for software mode, 1 for Direct2D mode
        }
    }
#endif
}

void PluginEditor::setSkinFromDefaults()
{
    auto b = defaultsProvider->getUserDefaultValue(Defaults::useLightSkin, 0);
    if (b)
    {
        setStyle(sst::jucegui::style::StyleSheet::getBuiltInStyleSheet(
            sst::jucegui::style::StyleSheet::LIGHT));
        style()->setColour(PatchMenu, jcmp::MenuButton::Styles::fill,
                           style()
                               ->getColour(jcmp::base_styles::Base::styleClass,
                                           jcmp::base_styles::Base::background)
                               .darker(0.3f));
    }
    else
    {
        setStyle(sst::jucegui::style::StyleSheet::getBuiltInStyleSheet(
            sst::jucegui::style::StyleSheet::DARK));
    }

    style()->setFont(
        PatchMenu, jcmp::MenuButton::Styles::labelfont,
        style()
            ->getFont(jcmp::MenuButton::Styles::styleClass, jcmp::MenuButton::Styles::labelfont)
            .withHeight(18));
}

void PluginEditor::setZoomFactor(float zf)
{
    // SCLOG("Setting zoom factor to " << zf);
    zoomFactor = zf;
    setTransform(juce::AffineTransform().scaled(zoomFactor));
    defaultsProvider->updateUserDefaultValue(Defaults::zoomLevel, zoomFactor * 100);
    if (onZoomChanged)
        onZoomChanged(zoomFactor);
}

void PluginEditor::doSinglePanelHamburger()
{
    juce::Component *vis;
    for (auto c : mainPanel->getChildren())
    {
        if (c->isVisible())
        {
            vis = c;
        }
    }
    if (!vis)
        return;
}

void PluginEditor::activateHamburger(bool b)
{
    mainPanel->hasHamburger = b;
    mainPanel->repaint();
}

void PluginEditor::requestParamsFlush()
{
    if (!clapHost)
    {
        return;
    }

    if (!clapParamsExtension)
        clapParamsExtension = static_cast<const clap_host_params_t *>(
            clapHost->get_extension(clapHost, CLAP_EXT_PARAMS));
    if (clapParamsExtension)
    {
        clapParamsExtension->request_flush(clapHost);
    }
}

void PluginEditor::sneakyStartupGrabFrom(Patch &other)
{
    for (auto &p : other.params)
    {
        auto *destination = patchCopy.paramById(p->meta.id);
        if (destination)
        {
            destination->value = p->value;
        }
    }
    strncpy(patchCopy.name, other.name, 255);
    patchCopy.visualAssets = other.visualAssets;
    applyPatchDotImagesToEditor();
    refreshScopeVisualState();
    postPatchChange(other.name);
}

ScopeVisualState PluginEditor::currentScopeVisualState() const
{
    return patchCopy.visualParams.visualState();
}

ScopeDotImages PluginEditor::currentScopeDotImages() const
{
    auto images = ScopeDotImages{};
    for (size_t i = 0; i < dotImageOverrides.size(); ++i)
    {
        images.slots[i].image = dotImageOverrides[i].image;
        images.slots[i].revision = dotImageOverrides[i].revision;
    }
    return images;
}

void PluginEditor::refreshScopeVisualState()
{
    if (scopeOpenGLView)
    {
        scopeOpenGLView->setVisualState(currentScopeVisualState());
    }
}

void PluginEditor::refreshScopeDotImages()
{
    if (scopeOpenGLView)
    {
        scopeOpenGLView->setDotImages(currentScopeDotImages());
    }
}

void PluginEditor::syncPatchDotImagesFromEditor()
{
    for (size_t i = 0; i < dotImageOverrides.size(); ++i)
    {
        auto &target = patchCopy.visualAssets.dotImages[i];
        const auto &source = dotImageOverrides[i];
        target.label = source.label.toStdString();
        target.pngBase64 = imageToPngBase64(source.image);
    }

    mainToAudio.push({Engine::MainToAudioMsg::SET_VISUAL_ASSETS,
                      0,
                      0.0f,
                      nullptr,
                      std::make_shared<Patch::VisualAssetState>(patchCopy.visualAssets)});
}

void PluginEditor::applyPatchDotImagesToEditor()
{
    for (size_t i = 0; i < dotImageOverrides.size(); ++i)
    {
        const auto &source = patchCopy.visualAssets.dotImages[i];
        auto &target = dotImageOverrides[i];
        target.image = imageFromPngBase64(source.pngBase64);
        target.label = target.image.isValid() ? juce::String(source.label) : "Generated";
        target.revision++;
    }

    refreshScopeDotImages();
    if (mainPanel)
    {
        mainPanel->refreshDotImageStatus();
    }
    repaint();
}

juce::String PluginEditor::dotImageStatusText(size_t dotIndex) const
{
    if (dotIndex >= dotImageOverrides.size())
    {
        return {};
    }

    const auto &dot = dotImageOverrides[dotIndex];
    auto status = dotName(dotIndex) + ": ";
    if (dot.hasImage())
    {
        status += "Image " + compactDotImageLabel(dot.label);
        status += " ";
        status += juce::String(dot.image.getWidth());
        status += "x";
        status += juce::String(dot.image.getHeight());
    }
    else
    {
        status += "Generated";
    }
    return status;
}

void PluginEditor::loadDotImageOverride(size_t dotIndex)
{
    if (dotIndex >= dotImageOverrides.size())
    {
        return;
    }

    fileChooser = std::make_unique<juce::FileChooser>("Load " + dotName(dotIndex) + " Image",
                                                      juce::File{},
                                                      "*.png;*.jpg;*.jpeg;*.bmp;*.gif");
    juce::Component::SafePointer<PluginEditor> safeThis(this);
    fileChooser->launchAsync(
        juce::FileBrowserComponent::canSelectFiles | juce::FileBrowserComponent::openMode,
        [safeThis, dotIndex](const juce::FileChooser &chooser)
        {
            if (safeThis == nullptr)
            {
                return;
            }

            const auto file = chooser.getResult();
            if (file == juce::File{})
            {
                return;
            }

            auto image = normalizeDotImageForState(juce::ImageFileFormat::loadFrom(file));
            if (!image.isValid())
            {
                juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::WarningIcon,
                                                       "Dot Image Load Failed",
                                                       "Prettyscope could not read that image.");
                return;
            }

            auto &dot = safeThis->dotImageOverrides[dotIndex];
            dot.image = image;
            dot.label = file.getFileName();
            dot.revision++;
            safeThis->syncPatchDotImagesFromEditor();
            safeThis->refreshScopeDotImages();

            if (safeThis->mainPanel)
            {
                safeThis->mainPanel->refreshDotImageStatus();
            }
            safeThis->repaint();
        });
}

void PluginEditor::saveDotImage(size_t dotIndex)
{
    if (dotIndex >= dotImageOverrides.size())
    {
        return;
    }

    const auto &dot = dotImageOverrides[dotIndex];
    auto defaultFileName = dotName(dotIndex).replaceCharacter(' ', '-').toLowerCase() + ".png";
    if (dot.hasImage())
    {
        auto stem = juce::File(dot.label).getFileNameWithoutExtension();
        if (stem.isNotEmpty())
        {
            defaultFileName = stem.replaceCharacter(' ', '-').toLowerCase() + ".png";
        }
    }

    fileChooser = std::make_unique<juce::FileChooser>("Save " + dotName(dotIndex) + " Image",
                                                      juce::File::getSpecialLocation(
                                                          juce::File::userDocumentsDirectory)
                                                          .getChildFile(defaultFileName),
                                                      "*.png");
    juce::Component::SafePointer<PluginEditor> safeThis(this);
    fileChooser->launchAsync(
        juce::FileBrowserComponent::canSelectFiles | juce::FileBrowserComponent::saveMode |
            juce::FileBrowserComponent::warnAboutOverwriting,
        [safeThis, dotIndex](const juce::FileChooser &chooser)
        {
            if (safeThis == nullptr)
            {
                return;
            }

            auto file = chooser.getResult();
            if (file == juce::File{})
            {
                return;
            }
            if (!file.hasFileExtension(".png"))
            {
                file = file.withFileExtension(".png");
            }

            auto stream = file.createOutputStream();
            if (!stream)
            {
                juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::WarningIcon,
                                                       "Dot Image Save Failed",
                                                       "Prettyscope could not write that file.");
                return;
            }

            const auto &currentDot = safeThis->dotImageOverrides[dotIndex];
            auto image = currentDot.hasImage() ? currentDot.image
                                               : createGeneratedDotImage(
                                                     safeThis->currentScopeVisualState(), dotIndex);
            auto png = juce::PNGImageFormat();
            if (!png.writeImageToStream(image, *stream))
            {
                juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::WarningIcon,
                                                       "Dot Image Save Failed",
                                                       "Prettyscope could not encode the PNG.");
            }
        });
}

void PluginEditor::clearDotImageOverride(size_t dotIndex)
{
    if (dotIndex >= dotImageOverrides.size())
    {
        return;
    }

    auto &dot = dotImageOverrides[dotIndex];
    dot.image = {};
    dot.label = "Generated";
    dot.revision++;
    syncPatchDotImagesFromEditor();
    refreshScopeDotImages();

    if (mainPanel)
    {
        mainPanel->refreshDotImageStatus();
    }
    repaint();
}

bool PluginEditor::toggleDebug()
{
    if (debugLevel == 0)
    {
        sst::plugininfra::misc_platform::allocateConsole();
    }
    if (debugLevel <= 0)
        debugLevel = 1;
    else
        debugLevel = -1;
    SQLOG("Started debug session");
    SQLOG("If you are on windows and you close this window it may end your entire session");
    return debugLevel > 0;
}

void PluginEditor::onStyleChanged()
{
    jcmp::WindowPanel::onStyleChanged();
    if (lnf)
        lnf->setStyle(style());
}

} // namespace baconpaul::sidequest_ns::ui
