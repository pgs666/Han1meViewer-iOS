import SwiftUI
import UIKit

enum VideoPlayerCollapseModel {
    static func nextCollapseOffset(
        currentCollapseOffset: CGFloat,
        activeTabOffset: CGFloat,
        previousActiveTabOffset: CGFloat?,
        collapseDistance: CGFloat
    ) -> CGFloat {
        let clampedCurrent = clamp(currentCollapseOffset, upperBound: collapseDistance)

        guard let previousActiveTabOffset else {
            let nonnegativeActiveOffset = max(0, activeTabOffset)
            return min(collapseDistance, max(clampedCurrent, nonnegativeActiveOffset))
        }

        let delta = activeTabOffset - previousActiveTabOffset
        if abs(delta) > 0.5 {
            return clamp(clampedCurrent + delta, upperBound: collapseDistance)
        }

        return clampedCurrent
    }

    private static func clamp(_ value: CGFloat, upperBound: CGFloat) -> CGFloat {
        min(max(value, 0), max(upperBound, 0))
    }
}

enum VideoDetailPagerOffsetModel {
    enum InactiveSyncMode: Equatable {
        case visualTop(CGFloat)
        case scrollingHeader(CGFloat)
        case pinned(CGFloat)
    }

    static func initialNormalizedOffsetY(
        visualTopOffset: CGFloat,
        collapseDistance: CGFloat
    ) -> CGFloat {
        clamp(visualTopOffset, upperBound: collapseDistance)
    }

    static func minimumContentHeight(
        scrollBoundsHeight: CGFloat,
        pinnedVisibleHeight: CGFloat,
        collapseDistance: CGFloat
    ) -> CGFloat {
        max(
            scrollBoundsHeight - max(pinnedVisibleHeight, 0),
            max(collapseDistance, 0) + 1,
            1
        )
    }

    static func minimumListContentHeight(
        scrollBoundsHeight: CGFloat,
        pinnedVisibleHeight: CGFloat
    ) -> CGFloat {
        max(scrollBoundsHeight - max(pinnedVisibleHeight, 0), 1)
    }

    private static func clamp(_ value: CGFloat, upperBound: CGFloat) -> CGFloat {
        min(max(value, 0), max(upperBound, 0))
    }
}

private struct VideoDetailSmoothHeaderSyncState: Equatable {
    let isSyncingListOffsets: Bool
    let headerContainerY: CGFloat
    let inactiveSyncMode: VideoDetailPagerOffsetModel.InactiveSyncMode

    static func state(
        activeOffset: CGFloat,
        collapseDistance: CGFloat
    ) -> VideoDetailSmoothHeaderSyncState {
        let resolvedCollapseDistance = max(collapseDistance, 0)
        if activeOffset < resolvedCollapseDistance {
            let scrollingOffset = max(activeOffset, 0)
            return VideoDetailSmoothHeaderSyncState(
                isSyncingListOffsets: true,
                headerContainerY: -scrollingOffset,
                inactiveSyncMode: .scrollingHeader(scrollingOffset)
            )
        }
        return VideoDetailSmoothHeaderSyncState(
            isSyncingListOffsets: false,
            headerContainerY: -resolvedCollapseDistance,
            inactiveSyncMode: .pinned(resolvedCollapseDistance)
        )
    }
}

private extension VideoDetailPagerOffsetModel.InactiveSyncMode {
    var normalizedOffsetY: CGFloat {
        switch self {
        case .visualTop(let offsetY), .scrollingHeader(let offsetY), .pinned(let offsetY):
            return offsetY
        }
    }
}

struct VideoDetailPagerLayoutMetrics {
    let collapseDistance: CGFloat
    let playerScrollAway: CGFloat
    let continuationProgress: CGFloat
}

struct VideoDetailPagerState: Equatable {
    var selectedTab: VideoPageTab = .introduction
    var collapseOffset: CGFloat = 0
    var tabOffsets: [VideoPageTab: CGFloat] = [:]
    var isPlayerPlaying: Bool = false

    func layoutMetrics(
        containerHeight _: CGFloat,
        rawCollapseDistance: CGFloat
    ) -> VideoDetailPagerLayoutMetrics {
        let collapseDistance = isPlayerPlaying ? 0 : max(rawCollapseDistance, 0)
        let playerScrollAway = isPlayerPlaying ? 0 : Self.clamp(collapseOffset, upperBound: collapseDistance)
        let fadeDistance: CGFloat = 72
        let continuationProgress: CGFloat
        if rawCollapseDistance > 1 {
            continuationProgress = min(
                max((playerScrollAway - (rawCollapseDistance - fadeDistance)) / fadeDistance, 0),
                1
            )
        } else {
            continuationProgress = 0
        }

        return VideoDetailPagerLayoutMetrics(
            collapseDistance: collapseDistance,
            playerScrollAway: playerScrollAway,
            continuationProgress: continuationProgress
        )
    }

    mutating func setPlayerPlaying(_ isPlaying: Bool) {
        isPlayerPlaying = isPlaying
        if isPlaying {
            collapseOffset = 0
        }
    }

    mutating func expandPlayer() {
        collapseOffset = 0
    }

    mutating func selectTab(_ tab: VideoPageTab, collapseDistance: CGFloat) {
        selectedTab = tab
        clampCollapse(to: collapseDistance)
    }

    mutating func updateTabOffset(_ tab: VideoPageTab, offset: CGFloat, collapseDistance: CGFloat) {
        guard tab == selectedTab else { return }
        guard !isPlayerPlaying else {
            collapseOffset = 0
            return
        }
        let trackedOffset = Self.clamp(offset, upperBound: collapseDistance)
        let previousActiveOffset = tabOffsets[tab]
        let previousCollapseOffset = collapseOffset
        let nextCollapseOffset = nextCollapseOffset(
            activeTabOffset: trackedOffset,
            previousActiveTabOffset: previousActiveOffset,
            collapseDistance: collapseDistance
        )
        guard previousActiveOffset != trackedOffset
            || abs(previousCollapseOffset - nextCollapseOffset) > 0.5 else {
            return
        }
        tabOffsets[tab] = trackedOffset
        collapseOffset = nextCollapseOffset
    }

    private func nextCollapseOffset(
        activeTabOffset: CGFloat,
        previousActiveTabOffset: CGFloat?,
        collapseDistance: CGFloat
    ) -> CGFloat {
        VideoPlayerCollapseModel.nextCollapseOffset(
            currentCollapseOffset: collapseOffset,
            activeTabOffset: activeTabOffset,
            previousActiveTabOffset: previousActiveTabOffset,
            collapseDistance: collapseDistance
        )
    }

    mutating func beginInteracting(with tab: VideoPageTab, collapseDistance: CGFloat) {
        guard selectedTab != tab else { return }
        selectTab(tab, collapseDistance: collapseDistance)
    }

    mutating func handleTopPull(tab: VideoPageTab, delta: CGFloat, collapseDistance: CGFloat) {
        guard tab == selectedTab, !isPlayerPlaying, delta > 0, collapseOffset > 0 else { return }
        collapseOffset = Self.clamp(collapseOffset - delta, upperBound: collapseDistance)
    }

    mutating func clampCollapse(to collapseDistance: CGFloat) {
        collapseOffset = Self.clamp(collapseOffset, upperBound: collapseDistance)
    }

    private static func clamp(_ value: CGFloat, upperBound: CGFloat) -> CGFloat {
        min(max(value, 0), max(upperBound, 0))
    }
}

enum VideoPageTab: String, CaseIterable, Identifiable {
    case introduction
    case comments

    var id: String { rawValue }

    var pageIndex: Int {
        switch self {
        case .introduction: return 0
        case .comments: return 1
        }
    }

    static func page(at index: Int) -> VideoPageTab {
        index <= 0 ? .introduction : .comments
    }

    var scrollCoordinateSpaceName: String {
        "bottomScroll-\(rawValue)"
    }

    var title: String {
        switch self {
        case .introduction:
            return String(localized: "简介")
        case .comments:
            return String(localized: "评论")
        }
    }
}

struct VideoDetailTabContentRevision: Equatable {
    let introduction: Int
    let comments: Int
}

private struct VideoDetailSmoothHeaderGeometry: Equatable {
    let headerHeight: CGFloat
    let pinHeaderHeight: CGFloat
    let collapseDistance: CGFloat
    let visualTopOffset: CGFloat
    let pinnedVisibleHeight: CGFloat

    var contentTopInset: CGFloat {
        max(headerHeight, 0) + max(pinHeaderHeight, 0)
    }

    var resolvedVisualTopOffset: CGFloat {
        VideoDetailPagerOffsetModel.initialNormalizedOffsetY(
            visualTopOffset: visualTopOffset,
            collapseDistance: collapseDistance
        )
    }

    var collapseSpacerHeight: CGFloat {
        max(collapseDistance + 1, 1)
    }

    func listOffsetContext(
        in scrollBoundsHeight: CGFloat,
        activeOffset: CGFloat? = nil
    ) -> VideoDetailListOffsetContext {
        let visualTopOffset = resolvedVisualTopOffset
        let inactiveSyncMode = activeOffset.map {
            smoothHeaderSyncState(activeOffset: $0).inactiveSyncMode
        } ?? .visualTop(visualTopOffset)
        return VideoDetailListOffsetContext(
            contentTopInset: contentTopInset,
            initialNormalizedOffsetY: visualTopOffset,
            inactiveSyncMode: inactiveSyncMode,
            collapseSpacerHeight: collapseSpacerHeight,
            minimumContentHeight: minimumContentHeight(in: scrollBoundsHeight),
            minimumListContentHeight: minimumListContentHeight(in: scrollBoundsHeight)
        )
    }

    func smoothHeaderSyncState(activeOffset: CGFloat) -> VideoDetailSmoothHeaderSyncState {
        VideoDetailSmoothHeaderSyncState.state(
            activeOffset: activeOffset,
            collapseDistance: collapseDistance
        )
    }

    func minimumContentHeight(in scrollBoundsHeight: CGFloat) -> CGFloat {
        VideoDetailPagerOffsetModel.minimumContentHeight(
            scrollBoundsHeight: scrollBoundsHeight,
            pinnedVisibleHeight: pinnedVisibleHeight,
            collapseDistance: collapseDistance
        )
    }

    func minimumListContentHeight(in scrollBoundsHeight: CGFloat) -> CGFloat {
        VideoDetailPagerOffsetModel.minimumListContentHeight(
            scrollBoundsHeight: scrollBoundsHeight,
            pinnedVisibleHeight: pinnedVisibleHeight
        )
    }

    func rawContentOffsetY(forNormalizedOffsetY offsetY: CGFloat, in listScrollView: UIScrollView) -> CGFloat {
        let inset = listScrollView.contentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, listScrollView.contentSize.height - listScrollView.bounds.height + inset.bottom)
        let rawOffsetY = offsetY - inset.top
        return min(max(rawOffsetY, minOffsetY), maxOffsetY)
    }

    func normalizedContentOffsetY(forRawOffsetY rawOffsetY: CGFloat, in listScrollView: UIScrollView) -> CGFloat {
        rawOffsetY + listScrollView.contentInset.top
    }

}

private struct VideoDetailListOffsetContext: Equatable {
    let contentTopInset: CGFloat
    let initialNormalizedOffsetY: CGFloat
    let inactiveSyncMode: VideoDetailPagerOffsetModel.InactiveSyncMode
    let collapseSpacerHeight: CGFloat
    let minimumContentHeight: CGFloat
    let minimumListContentHeight: CGFloat
}

private struct VideoDetailNativeScrollPage {
    let listScrollView: UIScrollView
    let attachScrollDelegate: (UIScrollViewDelegate?) -> Void
    let update: () -> Void
}

private enum VideoDetailTabPageContent {
    case swiftUI(() -> AnyView)
    case nativeScrollView(VideoDetailNativeScrollPage)
}

private struct VideoDetailHorizontalPagerPosition: Equatable {
    private(set) var selectedIndex = 0
    private(set) var isPagingActive = false

    mutating func setSelectedIndex(_ index: Int) {
        selectedIndex = clamped(index)
    }

    mutating func setPagingActive(_ isActive: Bool) -> Bool {
        guard isPagingActive != isActive else { return false }
        isPagingActive = isActive
        return true
    }

    mutating func settleHorizontalPaging(at index: Int) -> (previousSelectedIndex: Int, wasPagingActive: Bool) {
        let previousSelectedIndex = selectedIndex
        let wasPagingActive = isPagingActive
        selectedIndex = clamped(index)
        isPagingActive = false
        return (previousSelectedIndex, wasPagingActive)
    }

    private func clamped(_ index: Int) -> Int {
        min(max(index, 0), VideoPageTab.allCases.count - 1)
    }
}

private struct VideoDetailTabPage {
    let tab: VideoPageTab
    let contentBottomPadding: CGFloat
    let isSelected: Bool
    let headerGeometry: VideoDetailSmoothHeaderGeometry
    let contentUpdateRevision: Int
    let onOffsetChange: (VideoPageTab, CGFloat) -> Void
    let onInteractionBegan: (VideoPageTab) -> Void
    let onTopPullDelta: (VideoPageTab, CGFloat) -> Void
    let content: VideoDetailTabPageContent

    init<Content: View>(
        tab: VideoPageTab,
        contentBottomPadding: CGFloat,
        isSelected: Bool,
        headerGeometry: VideoDetailSmoothHeaderGeometry,
        contentUpdateRevision: Int,
        onOffsetChange: @escaping (VideoPageTab, CGFloat) -> Void,
        onInteractionBegan: @escaping (VideoPageTab) -> Void,
        onTopPullDelta: @escaping (VideoPageTab, CGFloat) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tab = tab
        self.contentBottomPadding = contentBottomPadding
        self.isSelected = isSelected
        self.headerGeometry = headerGeometry
        self.contentUpdateRevision = contentUpdateRevision
        self.onOffsetChange = onOffsetChange
        self.onInteractionBegan = onInteractionBegan
        self.onTopPullDelta = onTopPullDelta
        self.content = .swiftUI({ AnyView(content()) })
    }

    init(
        tab: VideoPageTab,
        contentBottomPadding: CGFloat,
        isSelected: Bool,
        headerGeometry: VideoDetailSmoothHeaderGeometry,
        contentUpdateRevision: Int,
        onOffsetChange: @escaping (VideoPageTab, CGFloat) -> Void,
        onInteractionBegan: @escaping (VideoPageTab) -> Void,
        onTopPullDelta: @escaping (VideoPageTab, CGFloat) -> Void,
        listScrollView: UIScrollView,
        attachScrollDelegate: @escaping (UIScrollViewDelegate?) -> Void,
        nativeUpdate: @escaping () -> Void
    ) {
        self.tab = tab
        self.contentBottomPadding = contentBottomPadding
        self.isSelected = isSelected
        self.headerGeometry = headerGeometry
        self.contentUpdateRevision = contentUpdateRevision
        self.onOffsetChange = onOffsetChange
        self.onInteractionBegan = onInteractionBegan
        self.onTopPullDelta = onTopPullDelta
        self.content = .nativeScrollView(
            VideoDetailNativeScrollPage(
                listScrollView: listScrollView,
                attachScrollDelegate: attachScrollDelegate,
                update: nativeUpdate
            )
        )
    }

    var nativeListScrollView: UIScrollView? {
        if case .nativeScrollView(let nativePage) = content {
            return nativePage.listScrollView
        }
        return nil
    }

    var nativeScrollDelegateAttachment: ((UIScrollViewDelegate?) -> Void)? {
        if case .nativeScrollView(let nativePage) = content {
            return nativePage.attachScrollDelegate
        }
        return nil
    }

    func withSelection(_ isSelected: Bool) -> VideoDetailTabPage {
        switch content {
        case .swiftUI(let content):
            VideoDetailTabPage(
                tab: tab,
                contentBottomPadding: contentBottomPadding,
                isSelected: isSelected,
                headerGeometry: headerGeometry,
                contentUpdateRevision: contentUpdateRevision,
                onOffsetChange: onOffsetChange,
                onInteractionBegan: onInteractionBegan,
                onTopPullDelta: onTopPullDelta,
                content: { content() }
            )
        case .nativeScrollView(let nativePage):
            VideoDetailTabPage(
                tab: tab,
                contentBottomPadding: contentBottomPadding,
                isSelected: isSelected,
                headerGeometry: headerGeometry,
                contentUpdateRevision: contentUpdateRevision,
                onOffsetChange: onOffsetChange,
                onInteractionBegan: onInteractionBegan,
                onTopPullDelta: onTopPullDelta,
                listScrollView: nativePage.listScrollView,
                attachScrollDelegate: nativePage.attachScrollDelegate,
                nativeUpdate: nativePage.update
            )
        }
    }
}

struct VideoDetailPagerContainer<ContinuationHeader: View, Introduction: View, Comments: View>: View {
    @Binding var state: VideoDetailPagerState
    let collapseDistance: CGFloat
    let headerHeight: CGFloat
    let pinHeaderHeight: CGFloat
    let pinnedVisibleHeight: CGFloat
    let playerScrollAway: CGFloat
    let continuationProgress: CGFloat
    let introductionContentBottomPadding: CGFloat
    let commentsContentBottomPadding: CGFloat
    let introductionContentRevision: Int
    let commentsContentRevision: Int
    let headerContentRevision: Int
    let continuationHeader: () -> ContinuationHeader
    let isContinuationHeaderInteractive: Bool
    let introduction: () -> Introduction
    let comments: () -> Comments
    let nativeCommentsListScrollView: UIScrollView?
    let nativeCommentsAttachScrollDelegate: ((UIScrollViewDelegate?) -> Void)?
    let nativeCommentsUpdate: (() -> Void)?

    private var selectedTabBinding: Binding<VideoPageTab> {
        Binding(
            get: { state.selectedTab },
            set: { newTab in
                mutateState { $0.selectTab(newTab, collapseDistance: collapseDistance) }
            }
        )
    }

    var body: some View {
        VideoDetailTabPager(
            selectedTab: selectedTabBinding,
            headerContentRevision: headerContentRevision,
            continuationHeader: AnyView(continuationHeader()),
            continuationProgress: continuationProgress,
            isContinuationHeaderInteractive: isContinuationHeaderInteractive,
            pinHeader: AnyView(pinHeader),
            introduction: tabPage(
                .introduction,
                contentBottomPadding: introductionContentBottomPadding,
                contentUpdateRevision: introductionContentRevision,
                content: introduction
            ),
            comments: commentsPage
        )
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onValueChange(of: collapseDistance) { newValue in
            mutateState { $0.clampCollapse(to: newValue) }
        }
    }

    private var pinHeader: some View {
        Picker("Content", selection: selectedTabBinding) {
            ForEach(VideoPageTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .frame(height: pinHeaderHeight)
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    private func tabPage<Content: View>(
        _ tab: VideoPageTab,
        contentBottomPadding: CGFloat,
        contentUpdateRevision: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> VideoDetailTabPage {
        VideoDetailTabPage(
            tab: tab,
            contentBottomPadding: contentBottomPadding,
            isSelected: state.selectedTab == tab,
            headerGeometry: VideoDetailSmoothHeaderGeometry(
                headerHeight: headerHeight,
                pinHeaderHeight: pinHeaderHeight,
                collapseDistance: collapseDistance,
                visualTopOffset: playerScrollAway,
                pinnedVisibleHeight: pinnedVisibleHeight
            ),
            contentUpdateRevision: contentUpdateRevision,
            onOffsetChange: { tab, offset in
                mutateState {
                    $0.updateTabOffset(tab, offset: offset, collapseDistance: collapseDistance)
                }
            },
            onInteractionBegan: { tab in
                mutateState {
                    $0.beginInteracting(with: tab, collapseDistance: collapseDistance)
                }
            },
            onTopPullDelta: { tab, delta in
                mutateState {
                    $0.handleTopPull(tab: tab, delta: delta, collapseDistance: collapseDistance)
                }
            },
            content: content
        )
    }

    private var commentsPage: VideoDetailTabPage {
        let geometry = VideoDetailSmoothHeaderGeometry(
            headerHeight: headerHeight,
            pinHeaderHeight: pinHeaderHeight,
            collapseDistance: collapseDistance,
            visualTopOffset: playerScrollAway,
            pinnedVisibleHeight: pinnedVisibleHeight
        )
        if let nativeCommentsListScrollView,
           let nativeCommentsAttachScrollDelegate,
           let nativeCommentsUpdate {
            return VideoDetailTabPage(
                tab: .comments,
                contentBottomPadding: commentsContentBottomPadding,
                isSelected: state.selectedTab == .comments,
                headerGeometry: geometry,
                contentUpdateRevision: commentsContentRevision,
                onOffsetChange: { tab, offset in
                    mutateState {
                        $0.updateTabOffset(tab, offset: offset, collapseDistance: collapseDistance)
                    }
                },
                onInteractionBegan: { tab in
                    mutateState {
                        $0.beginInteracting(with: tab, collapseDistance: collapseDistance)
                    }
                },
                onTopPullDelta: { tab, delta in
                    mutateState {
                        $0.handleTopPull(tab: tab, delta: delta, collapseDistance: collapseDistance)
                    }
                },
                listScrollView: nativeCommentsListScrollView,
                attachScrollDelegate: nativeCommentsAttachScrollDelegate,
                nativeUpdate: nativeCommentsUpdate
            )
        }
        return tabPage(
            .comments,
            contentBottomPadding: commentsContentBottomPadding,
            contentUpdateRevision: commentsContentRevision,
            content: comments
        )
    }

    private func mutateState(_ mutation: (inout VideoDetailPagerState) -> Void) {
        withTransaction(Transaction(animation: nil)) {
            var nextState = state
            mutation(&nextState)
            if nextState != state {
                state = nextState
            }
        }
    }
}

private final class VideoDetailVerticalScrollPageCoordinator: NSObject, UIScrollViewDelegate {
    var tab: VideoPageTab
    var onOffsetChange: (VideoPageTab, CGFloat) -> Void
    var onInteractionBegan: (VideoPageTab) -> Void
    var onTopPullDelta: (VideoPageTab, CGFloat) -> Void
    var onVerticalInteractionBegan: () -> Void = {}
    var onVisibleOffsetChange: (VideoPageTab, CGFloat) -> Void = { _, _ in }
    var visualTopContentOffsetY: CGFloat = 0
    var isApplyingExternalOffset = false
    private var lastReportedOffset: CGFloat?
    private var lastTopPullTranslationY: CGFloat = 0

    init(
        tab: VideoPageTab,
        onOffsetChange: @escaping (VideoPageTab, CGFloat) -> Void,
        onInteractionBegan: @escaping (VideoPageTab) -> Void,
        onTopPullDelta: @escaping (VideoPageTab, CGFloat) -> Void
    ) {
        self.tab = tab
        self.onOffsetChange = onOffsetChange
        self.onInteractionBegan = onInteractionBegan
        self.onTopPullDelta = onTopPullDelta
    }

    func scrollViewDidScroll(_ listScrollView: UIScrollView) {
        guard !isApplyingExternalOffset else { return }
        let offset = listScrollView.verticalContentOffsetExcludingBounce
        onVisibleOffsetChange(tab, offset)
        guard lastReportedOffset.map({ abs($0 - offset) > 0.5 }) ?? true else { return }
        lastReportedOffset = offset
        onOffsetChange(tab, offset)
    }

    func resetReportedOffset(_ offset: CGFloat) {
        lastReportedOffset = offset
    }

    @objc func handlePan(_ panGestureRecognizer: UIPanGestureRecognizer) {
        guard let listScrollView = panGestureRecognizer.view as? UIScrollView else { return }
        switch panGestureRecognizer.state {
        case .began:
            onVerticalInteractionBegan()
            onInteractionBegan(tab)
            lastTopPullTranslationY = 0
        case .changed:
            guard listScrollView.verticalContentOffsetExcludingBounce <= visualTopContentOffsetY + 0.5 else {
                lastTopPullTranslationY = panGestureRecognizer.translation(in: listScrollView).y
                return
            }
            let translationY = panGestureRecognizer.translation(in: listScrollView).y
            let delta = translationY - lastTopPullTranslationY
            lastTopPullTranslationY = translationY
            if delta > 0 {
                onTopPullDelta(tab, delta)
            }
        default:
            lastTopPullTranslationY = 0
        }
    }
}

private final class VideoDetailVerticalScrollPageViewController: UIViewController {
    private let coordinator: VideoDetailVerticalScrollPageCoordinator
    private let listScrollView: UIScrollView
    private let defaultScrollView: VerticalScrollView?
    private let usesNativeListScrollView: Bool
    private let contentView = UIView()
    private let listHeaderView = UIView()
    private let collapseSpacerView = UIView()
    private let contentBottomSpacerView = UIView()
    private let host = UIHostingController(rootView: AnyView(EmptyView()))
    private var hostMinimumHeightConstraint: NSLayoutConstraint?
    private var contentMinimumHeightConstraint: NSLayoutConstraint?
    private var collapseSpacerHeightConstraint: NSLayoutConstraint?
    private var contentBottomSpacerHeightConstraint: NSLayoutConstraint?
    private var contentUpdateRevision: Int?
    private var lastAppliedPage: VideoDetailTabPage?
    private var listScrollViewContentSizeObservation: NSKeyValueObservation?
    private var listScrollViewBoundsObservation: NSKeyValueObservation?
    private var nativeScrollDelegateAttachment: ((UIScrollViewDelegate?) -> Void)?
    var onHeaderOffsetChanged: (VideoPageTab, CGFloat) -> Void = { _, _ in }

    init(tab: VideoPageTab, listScrollView: UIScrollView? = nil) {
        let resolvedScrollView = listScrollView ?? VerticalScrollView()
        self.listScrollView = resolvedScrollView
        self.defaultScrollView = resolvedScrollView as? VerticalScrollView
        self.usesNativeListScrollView = listScrollView != nil
        coordinator = VideoDetailVerticalScrollPageCoordinator(
            tab: tab,
            onOffsetChange: { _, _ in },
            onInteractionBegan: { _ in },
            onTopPullDelta: { _, _ in }
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        nativeScrollDelegateAttachment?(nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        listScrollView.translatesAutoresizingMaskIntoConstraints = false
        listScrollView.backgroundColor = .clear
        listScrollView.bounces = true
        listScrollView.alwaysBounceVertical = true
        listScrollView.alwaysBounceHorizontal = false
        listScrollView.showsHorizontalScrollIndicator = false
        listScrollView.showsVerticalScrollIndicator = false
        listScrollView.isDirectionalLockEnabled = true
        listScrollView.contentInsetAdjustmentBehavior = .never
        listScrollView.keyboardDismissMode = .interactive
        if defaultScrollView != nil {
            listScrollView.delegate = coordinator
        }
        listScrollView.panGestureRecognizer.addTarget(coordinator, action: #selector(VideoDetailVerticalScrollPageCoordinator.handlePan(_:)))
        defaultScrollView?.onGeometryChange = { [weak self] in
            self?.handleScrollGeometryChange()
        }
        listScrollViewContentSizeObservation = listScrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
            self?.handleScrollGeometryChange()
        }
        listScrollViewBoundsObservation = listScrollView.observe(\.bounds, options: [.new]) { [weak self] _, _ in
            self?.handleScrollGeometryChange()
        }
        defaultScrollView?.shouldBeginVerticalPan = { [weak self] panGestureRecognizer, view in
            self?.handleVerticalInteractionBegan()
            let velocity = panGestureRecognizer.velocity(in: view)
            return abs(velocity.x) <= abs(velocity.y) * 1.05
        }
        view.addSubview(listScrollView)

        listHeaderView.backgroundColor = .clear
        listHeaderView.isUserInteractionEnabled = true
        listScrollView.addSubview(listHeaderView)

        var constraints = [
            listScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            listScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]

        if !usesNativeListScrollView {
            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.backgroundColor = .clear
            listScrollView.addSubview(contentView)

            addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            host.view.backgroundColor = .clear
            contentView.addSubview(host.view)
            host.didMove(toParent: self)

            collapseSpacerView.translatesAutoresizingMaskIntoConstraints = false
            collapseSpacerView.backgroundColor = .clear
            contentView.addSubview(collapseSpacerView)

            contentBottomSpacerView.translatesAutoresizingMaskIntoConstraints = false
            contentBottomSpacerView.backgroundColor = .clear
            contentView.addSubview(contentBottomSpacerView)

            let hostMinimumHeightConstraint = host.view.heightAnchor.constraint(greaterThanOrEqualTo: listScrollView.frameLayoutGuide.heightAnchor)
            let contentMinimumHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1)
            let collapseSpacerHeightConstraint = collapseSpacerView.heightAnchor.constraint(equalToConstant: 1)
            let contentBottomSpacerHeightConstraint = contentBottomSpacerView.heightAnchor.constraint(equalToConstant: 0)
            self.hostMinimumHeightConstraint = hostMinimumHeightConstraint
            self.contentMinimumHeightConstraint = contentMinimumHeightConstraint
            self.collapseSpacerHeightConstraint = collapseSpacerHeightConstraint
            self.contentBottomSpacerHeightConstraint = contentBottomSpacerHeightConstraint

            constraints.append(contentsOf: [
                contentView.leadingAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.bottomAnchor),
                contentView.widthAnchor.constraint(equalTo: listScrollView.frameLayoutGuide.widthAnchor),
                contentMinimumHeightConstraint,

                host.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostMinimumHeightConstraint,

                collapseSpacerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                collapseSpacerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                collapseSpacerView.topAnchor.constraint(equalTo: host.view.bottomAnchor),
                collapseSpacerHeightConstraint,

                contentBottomSpacerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                contentBottomSpacerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                contentBottomSpacerView.topAnchor.constraint(equalTo: collapseSpacerView.bottomAnchor),
                contentBottomSpacerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                contentBottomSpacerHeightConstraint
            ])
        }
        NSLayoutConstraint.activate(constraints)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyListHeaderFrame()
        handleScrollGeometryChange()
    }

    func update(page: VideoDetailTabPage) {
        loadViewIfNeeded()
        coordinator.tab = page.tab
        coordinator.onOffsetChange = page.onOffsetChange
        coordinator.onInteractionBegan = page.onInteractionBegan
        coordinator.onTopPullDelta = page.onTopPullDelta
        coordinator.onVerticalInteractionBegan = { [weak self] in
            self?.handleVerticalInteractionBegan()
        }
        coordinator.onVisibleOffsetChange = { [weak self] tab, offset in
            self?.onHeaderOffsetChanged(tab, offset)
        }
        switch page.content {
        case .nativeScrollView(let nativePage):
            if nativeScrollDelegateAttachment == nil {
                nativeScrollDelegateAttachment = nativePage.attachScrollDelegate
                nativePage.attachScrollDelegate(coordinator)
            }
        case .swiftUI:
            break
        }
        if contentUpdateRevision != page.contentUpdateRevision {
            contentUpdateRevision = page.contentUpdateRevision
            switch page.content {
            case .swiftUI(let content):
                host.view.isHidden = false
                host.rootView = content()
            case .nativeScrollView:
                if !usesNativeListScrollView {
                    host.view.isHidden = true
                    host.rootView = AnyView(EmptyView())
                }
            }
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        let geometry = page.headerGeometry
        let offsetContext = geometry.listOffsetContext(in: listScrollView.bounds.height)
        let visualTopOffset = offsetContext.initialNormalizedOffsetY
        lastAppliedPage = page
        coordinator.visualTopContentOffsetY = visualTopOffset
        applyTopContentInset(offsetContext.contentTopInset)
        applyListHeaderFrame()
        switch page.content {
        case .swiftUI:
            applyBottomContentSpacing(page.contentBottomPadding, usesContentSpacer: true)
            collapseSpacerHeightConstraint?.constant = offsetContext.collapseSpacerHeight
            contentMinimumHeightConstraint?.constant = offsetContext.minimumContentHeight
            hostMinimumHeightConstraint?.isActive = true
        case .nativeScrollView:
            applyBottomContentSpacing(page.contentBottomPadding, usesContentSpacer: true)
            collapseSpacerHeightConstraint?.constant = 0
            contentMinimumHeightConstraint?.constant = 1
            hostMinimumHeightConstraint?.isActive = false
            if case .nativeScrollView(let nativePage) = page.content {
                nativePage.update()
                applyCurrentPageGeometryRules()
            }
        }
    }

    private func handleScrollGeometryChange() {
        applyCurrentPageGeometryRules()
    }

    private func applyCurrentPageGeometryRules() {
        guard let page = lastAppliedPage else { return }
        let geometry = page.headerGeometry
        let offsetContext = geometry.listOffsetContext(in: listScrollView.bounds.height)
        let isNativeScrollView: Bool
        if case .nativeScrollView = page.content {
            isNativeScrollView = true
        } else {
            isNativeScrollView = false
        }
        if let contentMinimumHeightConstraint,
           abs(contentMinimumHeightConstraint.constant - offsetContext.minimumContentHeight) > 0.5 {
            contentMinimumHeightConstraint.constant = isNativeScrollView ? 1 : offsetContext.minimumContentHeight
        }
        applyNativeMinimumContentSizeIfNeeded(
            page: page,
            offsetContext: offsetContext
        )
    }

    private func applyTopContentInset(_ topInset: CGFloat) {
        let resolvedTopInset = max(topInset, 0)
        guard abs(listScrollView.contentInset.top - resolvedTopInset) > 0.5 else { return }
        listScrollView.contentInset.top = resolvedTopInset
        listScrollView.verticalScrollIndicatorInsets.top = resolvedTopInset
        applyListHeaderFrame()
    }

    private func applyBottomContentSpacing(_ bottomSpacing: CGFloat, usesContentSpacer: Bool) {
        let resolvedBottomSpacing = max(bottomSpacing, 0)
        let contentSpacerHeight = usesContentSpacer ? resolvedBottomSpacing : 0
        if let contentBottomSpacerHeightConstraint,
           abs(contentBottomSpacerHeightConstraint.constant - contentSpacerHeight) > 0.5 {
            contentBottomSpacerHeightConstraint.constant = contentSpacerHeight
        }
        let bottomInset = usesContentSpacer ? 0 : resolvedBottomSpacing
        if abs(listScrollView.contentInset.bottom - bottomInset) > 0.5 {
            listScrollView.contentInset.bottom = bottomInset
            clampOffsetAfterInsetChangeIfNeeded()
        }
        if abs(listScrollView.verticalScrollIndicatorInsets.bottom - resolvedBottomSpacing) > 0.5 {
            listScrollView.verticalScrollIndicatorInsets.bottom = resolvedBottomSpacing
        }
    }

    private func clampOffsetAfterInsetChangeIfNeeded() {
        guard !listScrollView.isTracking, !listScrollView.isDragging, !listScrollView.isDecelerating else { return }
        let clampedRawOffsetY = listScrollView.clampedRawVerticalContentOffsetY(listScrollView.contentOffset.y)
        setRawContentOffsetYSilentlyIfNeeded(clampedRawOffsetY)
    }

    @discardableResult
    private func applyNativeMinimumContentSizeIfNeeded(
        page: VideoDetailTabPage,
        offsetContext: VideoDetailListOffsetContext
    ) -> Bool {
        guard case .nativeScrollView = page.content else {
            return false
        }
        let requiredContentHeight = offsetContext.minimumListContentHeight
        guard listScrollView.contentSize.height < requiredContentHeight - 0.5 else {
            return false
        }
        listScrollView.contentSize = CGSize(
            width: listScrollView.contentSize.width,
            height: requiredContentHeight
        )
        return true
    }

    private func applyListHeaderFrame() {
        let topInset = max(listScrollView.contentInset.top, 0)
        let nextFrame = CGRect(
            x: 0,
            y: -topInset,
            width: listScrollView.bounds.width,
            height: topInset
        )
        guard !listHeaderView.frame.isApproximatelyEqual(to: nextFrame) else { return }
        listHeaderView.frame = nextFrame
    }

    private func handleVerticalInteractionBegan() {
        guard let page = lastAppliedPage else { return }
        coordinator.visualTopContentOffsetY = page.headerGeometry.resolvedVisualTopOffset
    }

    var normalizedContentOffsetY: CGFloat {
        loadViewIfNeeded()
        return listScrollView.verticalContentOffsetExcludingBounce
    }

    @discardableResult
    func syncHeaderOffsetFromActivePage(_ syncMode: VideoDetailPagerOffsetModel.InactiveSyncMode) -> Bool {
        loadViewIfNeeded()
        guard !listScrollView.isTracking, !listScrollView.isDragging, !listScrollView.isDecelerating else {
            return false
        }
        let syncOffsetY = syncMode.normalizedOffsetY
        return setNormalizedContentOffsetYIfReachable(syncOffsetY)
    }

    func setScrollsToTop(_ scrollsToTop: Bool) {
        loadViewIfNeeded()
        listScrollView.scrollsToTop = scrollsToTop
    }

    func reportCurrentOffset() {
        loadViewIfNeeded()
        let offset = listScrollView.verticalContentOffsetExcludingBounce
        coordinator.resetReportedOffset(offset)
        coordinator.onOffsetChange(coordinator.tab, offset)
    }

    @discardableResult
    private func setNormalizedContentOffsetYIfReachable(_ offsetY: CGFloat) -> Bool {
        let rawTopOffsetY = clampedRawContentOffsetY(forNormalizedOffsetY: offsetY)
        guard abs(normalizedContentOffsetY(forRawOffsetY: rawTopOffsetY) - offsetY) <= 0.5 else {
            return false
        }
        setRawContentOffsetYSilentlyIfNeeded(rawTopOffsetY)
        return true
    }

    private func setRawContentOffsetYSilentlyIfNeeded(_ rawTopOffsetY: CGFloat) {
        guard abs(listScrollView.contentOffset.y - rawTopOffsetY) > 0.5 else { return }
        coordinator.isApplyingExternalOffset = true
        defer { coordinator.isApplyingExternalOffset = false }
        listScrollView.setContentOffset(CGPoint(x: listScrollView.contentOffset.x, y: rawTopOffsetY), animated: false)
        coordinator.resetReportedOffset(listScrollView.verticalContentOffsetExcludingBounce)
    }

    private func clampedRawContentOffsetY(forNormalizedOffsetY offsetY: CGFloat) -> CGFloat {
        guard let page = lastAppliedPage else { return 0 }
        return page.headerGeometry.rawContentOffsetY(forNormalizedOffsetY: offsetY, in: listScrollView)
    }

    private func normalizedContentOffsetY(forRawOffsetY rawOffsetY: CGFloat) -> CGFloat {
        guard let page = lastAppliedPage else { return rawOffsetY + listScrollView.contentInset.top }
        return page.headerGeometry.normalizedContentOffsetY(forRawOffsetY: rawOffsetY, in: listScrollView)
    }

}

private final class VerticalScrollView: UIScrollView {
    var shouldBeginVerticalPan: ((UIPanGestureRecognizer, UIView) -> Bool)?
    var onGeometryChange: (() -> Void)?

    override var bounds: CGRect {
        didSet {
            guard abs(bounds.height - oldValue.height) > 0.5
                || abs(bounds.width - oldValue.width) > 0.5 else { return }
            onGeometryChange?()
        }
    }

    override var contentSize: CGSize {
        didSet {
            guard abs(contentSize.height - oldValue.height) > 0.5
                || abs(contentSize.width - oldValue.width) > 0.5 else { return }
            onGeometryChange?()
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
           panGestureRecognizer === self.panGestureRecognizer {
            return shouldBeginVerticalPan?(panGestureRecognizer, self) ?? true
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

private extension UIScrollView {
    var verticalContentOffsetExcludingBounce: CGFloat {
        clampedRawVerticalContentOffsetY(contentOffset.y) + contentInset.top
    }

    func clampedRawVerticalContentOffsetY(_ rawOffsetY: CGFloat) -> CGFloat {
        let inset = contentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, contentSize.height - bounds.height + inset.bottom)
        return min(max(rawOffsetY, minOffsetY), maxOffsetY)
    }
}

private extension CGRect {
    func isApproximatelyEqual(to other: CGRect) -> Bool {
        abs(origin.x - other.origin.x) <= 0.5
            && abs(origin.y - other.origin.y) <= 0.5
            && abs(size.width - other.size.width) <= 0.5
            && abs(size.height - other.size.height) <= 0.5
    }
}

private struct VideoDetailTabPager: UIViewControllerRepresentable {
    @Binding var selectedTab: VideoPageTab
    let headerContentRevision: Int
    let continuationHeader: AnyView
    let continuationProgress: CGFloat
    let isContinuationHeaderInteractive: Bool
    let pinHeader: AnyView
    let introduction: VideoDetailTabPage
    let comments: VideoDetailTabPage

    init(
        selectedTab: Binding<VideoPageTab>,
        headerContentRevision: Int,
        continuationHeader: AnyView,
        continuationProgress: CGFloat,
        isContinuationHeaderInteractive: Bool,
        pinHeader: AnyView,
        introduction: VideoDetailTabPage,
        comments: VideoDetailTabPage
    ) {
        _selectedTab = selectedTab
        self.headerContentRevision = headerContentRevision
        self.continuationHeader = continuationHeader
        self.continuationProgress = continuationProgress
        self.isContinuationHeaderInteractive = isContinuationHeaderInteractive
        self.pinHeader = pinHeader
        self.introduction = introduction
        self.comments = comments
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedTab: $selectedTab)
    }

    func makeUIViewController(context: Context) -> PagingViewController {
        PagingViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: PagingViewController, context: Context) {
        context.coordinator.selectedTab = $selectedTab
        uiViewController.updatePages(
            headerContentRevision: headerContentRevision,
            continuationHeader: continuationHeader,
            continuationProgress: continuationProgress,
            isContinuationHeaderInteractive: isContinuationHeaderInteractive,
            pinHeader: pinHeader,
            introduction: introduction,
            comments: comments,
            selectedIndex: selectedTab.pageIndex,
            animated: context.coordinator.shouldAnimateProgrammaticSelection(to: selectedTab.pageIndex)
        )
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var selectedTab: Binding<VideoPageTab>
        var onSelectedIndexSettled: ((Int) -> Void)?
        var onPagingActivityChanged: ((Bool) -> Void)?
        private var lastProgrammaticIndex: Int?

        init(selectedTab: Binding<VideoPageTab>) {
            self.selectedTab = selectedTab
        }

        func shouldAnimateProgrammaticSelection(to index: Int) -> Bool {
            defer { lastProgrammaticIndex = index }
            guard let lastProgrammaticIndex else { return false }
            return lastProgrammaticIndex != index
        }

        func scrollViewWillBeginDragging(_ listScrollView: UIScrollView) {
            onPagingActivityChanged?(true)
        }

        func scrollViewDidScroll(_ listScrollView: UIScrollView) {
            let width = listScrollView.bounds.width
            guard width > 0 else { return }
            guard abs(listScrollView.contentOffset.x - CGFloat(selectedTab.wrappedValue.pageIndex) * width) > 0.5 else {
                return
            }
            onPagingActivityChanged?(true)
        }

        func scrollViewDidEndDecelerating(_ listScrollView: UIScrollView) {
            settleSelectedIndex(from: listScrollView)
            onPagingActivityChanged?(false)
        }

        func scrollViewDidEndScrollingAnimation(_ listScrollView: UIScrollView) {
            settleSelectedIndex(from: listScrollView)
            onPagingActivityChanged?(false)
        }

        func scrollViewDidEndDragging(_ listScrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                settleSelectedIndex(from: listScrollView)
                onPagingActivityChanged?(false)
            }
        }

        func shouldBeginHorizontalPagingPan(
            panGestureRecognizer: UIPanGestureRecognizer,
            in view: UIView
        ) -> Bool {
            let startLocation = panGestureRecognizer.location(in: view)
            guard startLocation.x > 24 else { return false }
            guard !view.hasScrollableHorizontalDescendant(at: startLocation, excluding: view) else {
                return false
            }

            let translation = panGestureRecognizer.translation(in: view)
            let velocity = panGestureRecognizer.velocity(in: view)
            let horizontal = max(abs(translation.x), abs(velocity.x) * 0.05)
            let vertical = max(abs(translation.y), abs(velocity.y) * 0.05)
            return horizontal > 8 && horizontal > vertical * 1.18
        }

        private func settleSelectedIndex(from listScrollView: UIScrollView) {
            let width = listScrollView.bounds.width
            guard width > 0 else { return }
            let index = Int(round(listScrollView.contentOffset.x / width))
            onSelectedIndexSettled?(index)
            let tab = VideoPageTab.page(at: index)
            if selectedTab.wrappedValue != tab {
                selectedTab.wrappedValue = tab
            }
        }
    }

    final class PagingViewController: UIViewController {
        private let coordinator: Coordinator
        private let scrollView = PagingScrollView()
        private let contentView = UIView()
        private let headerContainerView = PagingHeaderContainerView()
        private let continuationHeaderHost = UIHostingController(rootView: AnyView(EmptyView()))
        private let pinHeaderHost = UIHostingController(rootView: AnyView(EmptyView()))
        private let introductionPage = VideoDetailVerticalScrollPageViewController(tab: .introduction)
        private var commentsPage: VideoDetailVerticalScrollPageViewController?
        private weak var commentsListScrollView: UIScrollView?
        private var pagerPosition = VideoDetailHorizontalPagerPosition()
        private var pendingSelectedIndex: Int?
        private var lastLaidOutWidth: CGFloat = 0
        private var headerContentRevision: Int?
        private var latestPages: [VideoPageTab: VideoDetailTabPage] = [:]

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear

            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.backgroundColor = .clear
            scrollView.isPagingEnabled = true
            scrollView.bounces = false
            scrollView.alwaysBounceHorizontal = false
            scrollView.alwaysBounceVertical = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.isDirectionalLockEnabled = true
            scrollView.contentInsetAdjustmentBehavior = .never
            scrollView.delegate = coordinator
            coordinator.onSelectedIndexSettled = { [weak self] index in
                self?.settlePageAfterHorizontalSelection(index)
            }
            scrollView.shouldBeginPagingPan = { [weak self] panGestureRecognizer, view in
                self?.coordinator.shouldBeginHorizontalPagingPan(
                    panGestureRecognizer: panGestureRecognizer,
                    in: view
                ) ?? true
            }
            coordinator.onPagingActivityChanged = { [weak self] isActive in
                self?.setHorizontalPagingActive(isActive)
            }
            view.addSubview(scrollView)

            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.backgroundColor = .clear
            scrollView.addSubview(contentView)
            addPage(introductionPage)

            headerContainerView.backgroundColor = .clear
            headerContainerView.pinHeaderHeight = 48
            addChild(continuationHeaderHost)
            continuationHeaderHost.view.backgroundColor = .clear
            headerContainerView.addSubview(continuationHeaderHost.view)
            continuationHeaderHost.didMove(toParent: self)
            addChild(pinHeaderHost)
            pinHeaderHost.view.backgroundColor = .clear
            headerContainerView.addSubview(pinHeaderHost.view)
            pinHeaderHost.didMove(toParent: self)
            view.addSubview(headerContainerView)

            updateScrollsToTop(for: VideoPageTab.page(at: pagerPosition.selectedIndex))
            introductionPage.onHeaderOffsetChanged = { [weak self] tab, offset in
                self?.updateHeaderContainerPosition(for: tab, offsetY: offset)
            }

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

                introductionPage.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                introductionPage.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                introductionPage.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                introductionPage.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                introductionPage.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let width = scrollView.bounds.width
            let widthChanged = abs(width - lastLaidOutWidth) > 0.5
            lastLaidOutWidth = width
            layoutHeaderHosts()
            updateHeaderAttachmentForCurrentState()
            if isHorizontalSelectionInProgress {
                return
            }
            if let pendingSelectedIndex {
                self.pendingSelectedIndex = nil
                setSelectedIndex(pendingSelectedIndex, animated: false)
            } else if widthChanged {
                setSelectedIndex(pagerPosition.selectedIndex, animated: false)
            }
        }

        func updatePages(
            headerContentRevision: Int,
            continuationHeader: AnyView,
            continuationProgress: CGFloat,
            isContinuationHeaderInteractive: Bool,
            pinHeader: AnyView,
            introduction: VideoDetailTabPage,
            comments: VideoDetailTabPage,
            selectedIndex: Int,
            animated: Bool
        ) {
            loadViewIfNeeded()
            if isHorizontalSelectionInProgress {
                pendingSelectedIndex = selectedIndex == pagerPosition.selectedIndex ? nil : selectedIndex
            } else {
                pagerPosition.setSelectedIndex(selectedIndex)
            }
            latestPages[.introduction] = introduction
            latestPages[.comments] = comments
            prepareCommentsPageIfNeeded(for: comments)
            updateHeaderHosts(
                headerContentRevision: headerContentRevision,
                continuationHeader: continuationHeader,
                continuationProgress: continuationProgress,
                isContinuationHeaderInteractive: isContinuationHeaderInteractive,
                pinHeader: pinHeader,
                page: VideoPageTab.page(at: pagerPosition.selectedIndex)
            )
            introductionPage.update(page: introduction)
            commentsPage?.update(page: comments)
            updateScrollsToTop(for: VideoPageTab.page(at: pagerPosition.selectedIndex))
            updateHeaderAttachmentForCurrentState()
            if !pagerPosition.isPagingActive {
                syncInactivePageHeaderOffset()
            }
            guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating else { return }
            setSelectedIndex(pagerPosition.selectedIndex, animated: animated)
        }

        private func addPage(_ page: UIViewController) {
            addChild(page)
            page.view.translatesAutoresizingMaskIntoConstraints = false
            page.view.backgroundColor = .clear
            contentView.addSubview(page.view)
            page.didMove(toParent: self)
        }

        private func setSelectedIndex(_ index: Int, animated: Bool) {
            pagerPosition.setSelectedIndex(index)
            let width = scrollView.bounds.width
            guard width > 0 else {
                pendingSelectedIndex = pagerPosition.selectedIndex
                return
            }
            let targetOffset = CGPoint(x: CGFloat(pagerPosition.selectedIndex) * width, y: 0)
            guard abs(scrollView.contentOffset.x - targetOffset.x) > 0.5 else { return }
            if animated {
                setHorizontalPagingActive(true)
            }
            scrollView.setContentOffset(targetOffset, animated: animated)
        }

        private var isHorizontalSelectionInProgress: Bool {
            pagerPosition.isPagingActive
                || scrollView.isTracking
                || scrollView.isDragging
                || scrollView.isDecelerating
        }

        private func settlePageAfterHorizontalSelection(_ index: Int) {
            let clampedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            finishHorizontalPaging(at: clampedIndex)
        }

        private func finishHorizontalPaging(at index: Int) {
            let clampedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            let settlement = pagerPosition.settleHorizontalPaging(at: clampedIndex)
            guard clampedIndex != settlement.previousSelectedIndex || settlement.wasPagingActive else {
                pendingSelectedIndex = nil
                return
            }
            pendingSelectedIndex = nil
            refreshPageSelectionSnapshots(selectedTab: VideoPageTab.page(at: clampedIndex))
            updateScrollsToTop(for: VideoPageTab.page(at: clampedIndex))
            layoutHeaderHosts()
            verticalPageController(for: VideoPageTab.page(at: clampedIndex))?.reportCurrentOffset()
            syncInactivePageHeaderOffset()
            updateHeaderAttachmentForCurrentState()
        }

        private func refreshPageSelectionSnapshots(selectedTab: VideoPageTab) {
            for tab in VideoPageTab.allCases {
                guard let page = latestPages[tab] else { continue }
                let isSelected = tab == selectedTab
                guard page.isSelected != isSelected else { continue }
                latestPages[tab] = page.withSelection(isSelected)
            }
        }

        private func updateScrollsToTop(for activeTab: VideoPageTab) {
            introductionPage.setScrollsToTop(activeTab == .introduction)
            commentsPage?.setScrollsToTop(activeTab == .comments)
        }

        private func setHorizontalPagingActive(_ isActive: Bool) {
            guard pagerPosition.setPagingActive(isActive) else { return }
            updateHeaderAttachmentForCurrentState()
            if !isActive {
                syncInactivePageHeaderOffset()
            }
        }

        private func syncInactivePageHeaderOffset(activeOffset providedActiveOffset: CGFloat? = nil) {
            guard !pagerPosition.isPagingActive else {
                return
            }
            guard let activePage = verticalPageController(for: VideoPageTab.page(at: pagerPosition.selectedIndex)) else {
                return
            }
            let activeOffset = providedActiveOffset ?? activePage.normalizedContentOffsetY
            guard let page = latestPages[VideoPageTab.page(at: pagerPosition.selectedIndex)] else { return }
            let nextSyncState = page.headerGeometry.smoothHeaderSyncState(activeOffset: activeOffset)
            for tab in VideoPageTab.allCases where tab.pageIndex != pagerPosition.selectedIndex {
                verticalPageController(for: tab)?.syncHeaderOffsetFromActivePage(nextSyncState.inactiveSyncMode)
            }
        }

        private func verticalPageController(for tab: VideoPageTab) -> VideoDetailVerticalScrollPageViewController? {
            switch tab {
            case .introduction:
                return introductionPage
            case .comments:
                return commentsPage
            }
        }

        private func prepareCommentsPageIfNeeded(for comments: VideoDetailTabPage) {
            let nativeScrollView = comments.nativeListScrollView
            if let commentsPage, commentsListScrollView === nativeScrollView {
                return
            }
            if let commentsPage {
                commentsPage.willMove(toParent: nil)
                commentsPage.view.removeFromSuperview()
                commentsPage.removeFromParent()
            }
            let nextCommentsPage = VideoDetailVerticalScrollPageViewController(
                tab: .comments,
                listScrollView: nativeScrollView
            )
            nextCommentsPage.onHeaderOffsetChanged = { [weak self] tab, offset in
                self?.updateHeaderContainerPosition(for: tab, offsetY: offset)
            }
            addPage(nextCommentsPage)
            NSLayoutConstraint.activate([
                nextCommentsPage.view.leadingAnchor.constraint(equalTo: introductionPage.view.trailingAnchor),
                nextCommentsPage.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                nextCommentsPage.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                nextCommentsPage.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                nextCommentsPage.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                nextCommentsPage.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
            commentsPage = nextCommentsPage
            commentsListScrollView = nativeScrollView
        }

        private func updateHeaderHosts(
            headerContentRevision: Int,
            continuationHeader: AnyView,
            continuationProgress: CGFloat,
            isContinuationHeaderInteractive: Bool,
            pinHeader: AnyView,
            page tab: VideoPageTab
        ) {
            guard let page = latestPages[tab] else { return }
            headerContainerView.pinHeaderHeight = page.headerGeometry.pinHeaderHeight
            headerContainerView.continuationHeaderHeight = continuationHeaderHeight(for: page)
            headerContainerView.isContinuationHeaderInteractive = isContinuationHeaderInteractive
            if self.headerContentRevision != headerContentRevision {
                self.headerContentRevision = headerContentRevision
                continuationHeaderHost.rootView = continuationHeader
                pinHeaderHost.rootView = pinHeader
            }
            layoutHeaderHosts()
            applyContinuationHeaderPresentation(progress: continuationProgress)
        }

        private func layoutHeaderHosts() {
            guard let page = latestPages[activeHeaderTab] else { return }
            let width = view.bounds.width
            let contentTopInset = page.headerGeometry.contentTopInset
            let continuationHeight = continuationHeaderHeight(for: page)
            headerContainerView.continuationHeaderHeight = continuationHeight
            headerContainerView.pinHeaderHeight = page.headerGeometry.pinHeaderHeight
            headerContainerView.frame = CGRect(
                x: 0,
                y: headerContainerView.frame.origin.y,
                width: width,
                height: contentTopInset
            )
            continuationHeaderHost.view.frame = CGRect(
                x: 0,
                y: max(page.headerGeometry.headerHeight - continuationHeight, 0),
                width: width,
                height: continuationHeight
            )
            pinHeaderHost.view.frame = CGRect(
                x: 0,
                y: page.headerGeometry.headerHeight,
                width: width,
                height: page.headerGeometry.pinHeaderHeight
            )
        }

        private func continuationHeaderHeight(for page: VideoDetailTabPage) -> CGFloat {
            max(page.headerGeometry.pinnedVisibleHeight - page.headerGeometry.pinHeaderHeight, 0)
        }

        private func applyContinuationHeaderPresentation(progress: CGFloat) {
            let clampedProgress = min(max(progress, 0), 1)
            continuationHeaderHost.view.alpha = clampedProgress
            continuationHeaderHost.view.transform = CGAffineTransform(
                translationX: 0,
                y: -8 * (1 - clampedProgress)
            )
        }

        private func updateHeaderAttachmentForCurrentState() {
            let headerTab = activeHeaderTab
            guard let page = latestPages[headerTab] else { return }
            layoutHeaderHosts()
            guard let pageController = verticalPageController(for: headerTab) else { return }
            let offset = pageController.normalizedContentOffsetY
            let syncState = page.headerGeometry.smoothHeaderSyncState(activeOffset: offset)
            attachHeader(originY: syncState.headerContainerY)
        }

        private var activeHeaderTab: VideoPageTab {
            VideoPageTab.page(at: pagerPosition.selectedIndex)
        }

        private func attachHeader(originY: CGFloat) {
            if headerContainerView.superview == nil {
                view.addSubview(headerContainerView)
            }
            var frame = headerContainerView.frame
            frame.origin = CGPoint(x: 0, y: originY)
            frame.size.width = view.bounds.width
            headerContainerView.frame = frame
            view.bringSubviewToFront(headerContainerView)
        }

        private func updateHeaderContainerPosition(for tab: VideoPageTab, offsetY: CGFloat) {
            guard tab == activeHeaderTab else { return }
            guard let page = latestPages[tab] else { return }
            let syncState = page.headerGeometry.smoothHeaderSyncState(activeOffset: offsetY)
            if !pagerPosition.isPagingActive {
                syncInactivePageHeaderOffset(activeOffset: offsetY)
            }
            attachHeader(originY: syncState.headerContainerY)
        }
    }

    final class PagingScrollView: UIScrollView {
        var shouldBeginPagingPan: ((UIPanGestureRecognizer, UIView) -> Bool)?

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
               panGestureRecognizer === self.panGestureRecognizer {
                return shouldBeginPagingPan?(panGestureRecognizer, self) ?? true
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }

    final class PagingHeaderContainerView: UIView {
        var pinHeaderHeight: CGFloat = 0
        var continuationHeaderHeight: CGFloat = 0
        var isContinuationHeaderInteractive = false

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            containsInteractiveHeaderPoint(point)
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard containsInteractiveHeaderPoint(point) else {
                return nil
            }
            return super.hitTest(point, with: event)
        }

        private func containsInteractiveHeaderPoint(_ point: CGPoint) -> Bool {
            let continuationHeaderFrame = CGRect(
                x: 0,
                y: max(bounds.height - pinHeaderHeight - continuationHeaderHeight, 0),
                width: bounds.width,
                height: continuationHeaderHeight
            )
            let pinHeaderFrame = CGRect(
                x: 0,
                y: bounds.height - pinHeaderHeight,
                width: bounds.width,
                height: pinHeaderHeight
            )
            return pinHeaderFrame.contains(point)
                || (isContinuationHeaderInteractive && continuationHeaderFrame.contains(point))
        }
    }
}

private extension UIView {
    func hasScrollableHorizontalDescendant(at location: CGPoint, excluding excludedView: UIView) -> Bool {
        guard let hitView = hitTest(location, with: nil) else { return false }
        var current: UIView? = hitView
        while let view = current, view !== excludedView {
            if let listScrollView = view as? UIScrollView,
               listScrollView.isScrollEnabled,
               listScrollView.panGestureRecognizer.isEnabled,
               listScrollView.contentSize.width > listScrollView.bounds.width + 1,
               listScrollView.contentSize.width > listScrollView.contentSize.height {
                return true
            }
            current = view.superview
        }
        return false
    }
}
