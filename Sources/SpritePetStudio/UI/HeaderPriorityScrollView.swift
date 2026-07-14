import AppKit
import SwiftUI

/// A macOS scroll view that gives its enclosing editor header first use of a
/// scroll gesture. Scrolling toward later content collapses the header first;
/// scrolling back at the visual top expands it before moving the document.
struct HeaderPriorityScrollView<Content: View>: NSViewRepresentable {
    @Binding var isHeaderCollapsed: Bool
    let resetKey: String
    let content: Content

    init(
        isHeaderCollapsed: Binding<Bool>,
        resetKey: String,
        @ViewBuilder content: () -> Content
    ) {
        _isHeaderCollapsed = isHeaderCollapsed
        self.resetKey = resetKey
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> HeaderPriorityNSScrollView {
        let scrollView = HeaderPriorityNSScrollView()
        let hostingView = NSHostingView(rootView: AnyView(content))
        scrollView.hostingView = hostingView
        scrollView.documentView = hostingView
        configure(scrollView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: HeaderPriorityNSScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.hostingView?.rootView = AnyView(content)
        configure(scrollView, coordinator: context.coordinator)
        scrollView.refreshDocumentLayout()

        if scrollView.lastResetKey != resetKey {
            scrollView.lastResetKey = resetKey
            DispatchQueue.main.async {
                scrollView.scrollToVisualTop()
            }
        }
    }

    private func configure(_ scrollView: HeaderPriorityNSScrollView, coordinator: Coordinator) {
        scrollView.isHeaderCollapsed = { [weak coordinator] in
            coordinator?.parent.isHeaderCollapsed ?? false
        }
        scrollView.setHeaderCollapsed = { [weak coordinator] collapsed in
            guard let coordinator, coordinator.parent.isHeaderCollapsed != collapsed else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                coordinator.parent.isHeaderCollapsed = collapsed
            }
        }
    }

    final class Coordinator {
        var parent: HeaderPriorityScrollView

        init(parent: HeaderPriorityScrollView) {
            self.parent = parent
        }
    }
}

final class HeaderPriorityNSScrollView: NSScrollView {
    var hostingView: NSHostingView<AnyView>?
    var isHeaderCollapsed: (() -> Bool)?
    var setHeaderCollapsed: ((Bool) -> Void)?
    var lastResetKey = ""
    private var isRefreshingDocumentLayout = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        automaticallyAdjustsContentInsets = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        automaticallyAdjustsContentInsets = false
    }

    override func layout() {
        super.layout()
        refreshDocumentLayout()
    }

    func refreshDocumentLayout() {
        guard let hostingView, !isRefreshingDocumentLayout else { return }
        isRefreshingDocumentLayout = true
        defer { isRefreshingDocumentLayout = false }
        let width = max(1, contentSize.width)
        hostingView.setFrameSize(NSSize(width: width, height: max(1, hostingView.frame.height)))
        hostingView.layoutSubtreeIfNeeded()
        let height = max(contentSize.height, ceil(hostingView.fittingSize.height))
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
    }

    func scrollToVisualTop() {
        guard let documentView else { return }
        let originY: CGFloat
        if documentView.isFlipped {
            originY = 0
        } else {
            originY = max(0, documentView.bounds.height - contentView.bounds.height)
        }
        contentView.scroll(to: NSPoint(x: 0, y: originY))
        reflectScrolledClipView(contentView)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard abs(delta) > 0.001 else {
            super.scrollWheel(with: event)
            return
        }

        // In AppKit, a negative vertical delta advances toward later content.
        if delta < 0, isHeaderCollapsed?() == false {
            setHeaderCollapsed?(true)
            return
        }

        if delta > 0, isHeaderCollapsed?() == true, isAtVisualTop {
            setHeaderCollapsed?(false)
            return
        }

        super.scrollWheel(with: event)
    }

    private var isAtVisualTop: Bool {
        guard let documentView else { return true }
        if documentView.isFlipped {
            return contentView.bounds.minY <= 0.5
        }
        return contentView.bounds.maxY >= documentView.bounds.maxY - 0.5
    }
}
