#include <input.h>
#include <input_event.h>
#include <main.h>
#include <options.h>
#include <plugin.h>
#include <pointer_input.h>
#include <window.h>
#include <workspace.h>

#include <utility>

// meta+click extras that kwin's modifier+click commands can't express: middle toggles
// maximize, right raises and focuses before kwin's own resize starts. runs just ahead
// of kwin's window action filter
class MetaClick : public KWin::Plugin, public KWin::InputEventFilter
{
public:
    MetaClick()
        : KWin::InputEventFilter(KWin::InputFilterOrder::WindowAction)
    {
        KWin::input()->installInputEventFilter(this);
    }

    bool pointerButton(KWin::PointerButtonEvent *event) override
    {
        // a consumed press also consumes its release, so the window never sees half a click
        if (event->state == KWin::PointerButtonState::Released) {
            return event->button == Qt::MiddleButton && std::exchange(m_consumeRelease, false);
        }
        if (event->modifiersRelevantForShortcuts != Qt::MetaModifier) {
            return false;
        }
        KWin::Window *window = KWin::input()->pointer()->focus();
        if (!window || !window->isClient()) {
            return false;
        }

        switch (event->button) {
        case Qt::MiddleButton:
            if (!window->isMaximizable()) {
                return false;
            }
            // MaximizeOp also raises and focuses
            KWin::workspace()->performWindowOperation(window, KWin::Options::MaximizeOp);
            m_consumeRelease = true;
            return true;
        case Qt::RightButton:
            // same as kwin's "activate, raise and move", which has no resize counterpart
            KWin::workspace()->raiseWindow(window);
            KWin::workspace()->requestFocus(window);
            return false;
        default:
            return false;
        }
    }

private:
    bool m_consumeRelease = false;
};

class MetaClickFactory : public KWin::PluginFactory
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID PluginFactory_iid FILE "metadata.json")
    Q_INTERFACES(KWin::PluginFactory)

public:
    std::unique_ptr<KWin::Plugin> create() const override
    {
        return std::make_unique<MetaClick>();
    }
};

#include "metaclick.moc"
