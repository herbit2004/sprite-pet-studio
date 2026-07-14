import AppKit
import SwiftUI

/// A native SwiftUI scroll view whose first vertical wheel gesture is offered
/// to the enclosing page header. The document itself remains a standard
/// `ScrollView`, so momentum, rubber-banding and layout use SwiftUI's normal
/// macOS behavior.
struct HeaderPriorityScrollView<Content: View>: View {
    @Binding var isHeaderCollapsed: Bool
    let resetKey: String
    let continuesScrollingAfterHeaderExpansion: Bool
    @ViewBuilder let content: () -> Content

    init(
        isHeaderCollapsed: Binding<Bool>,
        resetKey: String,
        continuesScrollingAfterHeaderExpansion: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _isHeaderCollapsed = isHeaderCollapsed
        self.resetKey = resetKey
        self.continuesScrollingAfterHeaderExpansion = continuesScrollingAfterHeaderExpansion
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical) {
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                // Keep the monitor inside the scroll document so its nearest
                // enclosing NSScrollView is always this vertical editor, not
                // a nested horizontal frame strip or an unrelated sidebar.
                .background {
                    HeaderScrollGestureMonitor(
                        isHeaderCollapsed: $isHeaderCollapsed,
                        continuesScrollingAfterHeaderExpansion: continuesScrollingAfterHeaderExpansion
                    )
                }
        }
        // Rebuilding only the native scroll container resets a newly selected
        // action/configuration to its real top without disturbing page state.
        .id(resetKey)
    }
}

private struct HeaderScrollGestureMonitor: NSViewRepresentable {
    @Binding var isHeaderCollapsed: Bool
    let continuesScrollingAfterHeaderExpansion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isHeaderCollapsed: $isHeaderCollapsed,
            continuesScrollingAfterHeaderExpansion: continuesScrollingAfterHeaderExpansion
        )
    }

    func makeNSView(context: Context) -> PassthroughMonitorView {
        let view = PassthroughMonitorView()
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ view: PassthroughMonitorView, context: Context) {
        context.coordinator.isHeaderCollapsed = $isHeaderCollapsed
        context.coordinator.continuesScrollingAfterHeaderExpansion = continuesScrollingAfterHeaderExpansion
        context.coordinator.monitoredView = view
        context.coordinator.verticalScrollView = view.enclosingScrollView
    }

    static func dismantleNSView(_ view: PassthroughMonitorView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var isHeaderCollapsed: Binding<Bool>
        var continuesScrollingAfterHeaderExpansion: Bool
        weak var monitoredView: NSView?
        weak var verticalScrollView: NSScrollView?
        private var eventMonitor: Any?

        init(
            isHeaderCollapsed: Binding<Bool>,
            continuesScrollingAfterHeaderExpansion: Bool
        ) {
            self.isHeaderCollapsed = isHeaderCollapsed
            self.continuesScrollingAfterHeaderExpansion = continuesScrollingAfterHeaderExpansion
        }

        func install(for view: NSView) {
            monitoredView = view
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let view = self.monitoredView,
                      event.window === view.window,
                      view.bounds.contains(view.convert(event.locationInWindow, from: nil)) else {
                    return event
                }

                let delta = event.scrollingDeltaY
                guard abs(delta) > 0.001 else { return event }

                // A horizontal frame strip and controls such as sliders can
                // otherwise swallow a vertical wheel event while hovered.
                // Keep clearly-horizontal gestures with the child control,
                // but always send vertical motion to this editor's outer
                // native scroll view.
                guard abs(delta) >= abs(event.scrollingDeltaX) else {
                    return event
                }

                if delta < 0, !self.isHeaderCollapsed.wrappedValue {
                    self.setCollapsed(true)
                    return nil
                }

                if delta > 0, self.isHeaderCollapsed.wrappedValue {
                    self.setCollapsed(false)
                    if self.continuesScrollingAfterHeaderExpansion,
                       let verticalScrollView = self.verticalScrollView ?? view.enclosingScrollView {
                        self.verticalScrollView = verticalScrollView
                        verticalScrollView.scrollWheel(with: event)
                    }
                    return nil
                }

                let verticalScrollView = self.verticalScrollView ?? view.enclosingScrollView
                self.verticalScrollView = verticalScrollView
                if let verticalScrollView,
                   self.requiresVerticalRerouting(event, to: verticalScrollView) {
                    verticalScrollView.scrollWheel(with: event)
                    return nil
                }

                return event
            }
        }

        func uninstall() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        deinit {
            uninstall()
        }

        private func setCollapsed(_ collapsed: Bool) {
            withAnimation(.easeInOut(duration: 0.18)) {
                isHeaderCollapsed.wrappedValue = collapsed
            }
        }

        /// Let the outer NSScrollView receive normal events through AppKit's
        /// native dispatch path (including event coalescing and momentum).
        /// Reroute only when a child control or nested horizontal scroll view
        /// would otherwise consume a vertical gesture.
        private func requiresVerticalRerouting(
            _ event: NSEvent,
            to verticalScrollView: NSScrollView
        ) -> Bool {
            guard let windowContent = event.window?.contentView else { return false }
            let point = windowContent.convert(event.locationInWindow, from: nil)
            guard let hitView = windowContent.hitTest(point) else { return false }

            if let nestedScrollView = hitView.enclosingScrollView,
               nestedScrollView !== verticalScrollView {
                return true
            }

            var candidate: NSView? = hitView
            while let current = candidate, current !== verticalScrollView {
                if current is NSControl { return true }
                if current === verticalScrollView.documentView { break }
                candidate = current.superview
            }
            return false
        }
    }
}

private final class PassthroughMonitorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
