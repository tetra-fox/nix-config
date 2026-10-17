#include <input.h>
#include <input_event.h>
#include <main.h>
#include <options.h>
#include <plugin.h>
#include <pointer_input.h>
#include <window.h>
#include <workspace.h>

#include <utility>

// meta+middle click toggles maximize on the window under the pointer. kwin's
// modifier+click commands have no maximize, so this filter sits just ahead of them
class MaximizeToggle : public KWin::Plugin, public KWin::InputEventFilter
{
public:
    MaximizeToggle()
        : KWin::InputEventFilter(KWin::InputFilterOrder::WindowAction)
    {
        KWin::input()->installInputEventFilter(this);
    }

    bool pointerButton(KWin::PointerButtonEvent *event) override
    {
        if (event->button != Qt::MiddleButton) {
            return false;
        }
        // a consumed press also consumes its release, so the window never sees half a click
        if (event->state == KWin::PointerButtonState::Released) {
            return std::exchange(m_consumeRelease, false);
        }
        if (event->modifiersRelevantForShortcuts != Qt::MetaModifier) {
            return false;
        }
        KWin::Window *window = KWin::input()->pointer()->focus();
        if (!window || !window->isClient() || !window->isMaximizable()) {
            return false;
        }
        KWin::workspace()->performWindowOperation(window, KWin::Options::MaximizeOp);
        m_consumeRelease = true;
        return true;
    }

private:
    bool m_consumeRelease = false;
};

class MaximizeToggleFactory : public KWin::PluginFactory
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID PluginFactory_iid FILE "metadata.json")
    Q_INTERFACES(KWin::PluginFactory)

public:
    std::unique_ptr<KWin::Plugin> create() const override
    {
        return std::make_unique<MaximizeToggle>();
    }
};

#include "maximizetoggle.moc"
