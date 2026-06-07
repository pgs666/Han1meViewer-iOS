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
        pinHeaderHeight: CGFloat
    ) -> CGFloat {
        max(scrollBoundsHeight - max(pinHeaderHeight, 0), 1)
    }

    static func shouldAlignToVisualTopAfterHorizontalActivation(
        currentOffset: CGFloat,
        visualTopOffset: CGFloat
    ) -> Bool {
        currentOffset <= visualTopOffset + 0.5
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

private enum VideoDetailHeaderAttachmentState: Equatable {
    case listHeader
    case pagerContainer(CGFloat)

    static func state(
        isHorizontalPagingActive: Bool,
        selectedOffset: CGFloat,
        syncState: VideoDetailSmoothHeaderSyncState,
        collapseDistance: CGFloat
    ) -> VideoDetailHeaderAttachmentState {
        if isHorizontalPagingActive {
            return .pagerContainer(syncState.headerContainerY)
        }
        if selectedOffset <= collapseDistance + 0.5 {
            return .listHeader
        }
        return .pagerContainer(syncState.headerContainerY)
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
            pinHeaderHeight: pinHeaderHeight
        )
    }

    func rawContentOffsetY(forNormalizedOffsetY offsetY: CGFloat, in listScrollView: UIScrollView) -> CGFloat {
        let inset = listScrollView.adjustedContentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, listScrollView.contentSize.height - listScrollView.bounds.height + inset.bottom)
        let rawOffsetY = offsetY - inset.top
        return min(max(rawOffsetY, minOffsetY), maxOffsetY)
    }

    func normalizedContentOffsetY(forRawOffsetY rawOffsetY: CGFloat, in listScrollView: UIScrollView) -> CGFloat {
        rawOffsetY + listScrollView.adjustedContentInset.top
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

private enum VideoDetailPendingTopAlignment {
    case initial
    case explicit(CGFloat)
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

private struct VideoDetailListAlignmentState {
    var pendingTopAlignment: VideoDetailPendingTopAlignment?
    var needsInitialHeaderOffsetReset = true
    var hasAppliedInitialListOffset = false
    var hasCompletedFirstActiveAlignment = false
    var isFirstActiveAlignmentStabilizing = false
    var firstActiveAlignedContentHeight: CGFloat?
    var hasUserInteractedSinceFirstActiveAlignment = false

    var hasExplicitPendingTopAlignment: Bool {
        guard let pendingTopAlignment else { return false }
        if case .explicit = pendingTopAlignment {
            return true
        }
        return false
    }

    mutating func cancelPendingTopAlignment() {
        pendingTopAlignment = nil
    }

    mutating func resetForContentUpdate() {
        hasCompletedFirstActiveAlignment = false
        isFirstActiveAlignmentStabilizing = false
        firstActiveAlignedContentHeight = nil
        hasUserInteractedSinceFirstActiveAlignment = false
    }

    mutating func reopenFirstActiveAlignmentAfterContentSizeChange() {
        hasCompletedFirstActiveAlignment = false
        isFirstActiveAlignmentStabilizing = false
        firstActiveAlignedContentHeight = nil
    }

    mutating func markInitialOffsetApplied() {
        needsInitialHeaderOffsetReset = false
        hasAppliedInitialListOffset = true
    }

    mutating func markFirstActiveAlignmentCompleted(contentHeight: CGFloat) {
        hasCompletedFirstActiveAlignment = true
        isFirstActiveAlignmentStabilizing = true
        firstActiveAlignedContentHeight = contentHeight
        hasUserInteractedSinceFirstActiveAlignment = false
    }

    mutating func markFirstActiveAlignmentStabilized(contentHeight: CGFloat) {
        hasCompletedFirstActiveAlignment = true
        isFirstActiveAlignmentStabilizing = false
        firstActiveAlignedContentHeight = contentHeight
        hasUserInteractedSinceFirstActiveAlignment = false
    }

    mutating func markUserInteractionAfterFirstActiveAlignment() {
        guard hasCompletedFirstActiveAlignment, !isFirstActiveAlignmentStabilizing else { return }
        hasUserInteractedSinceFirstActiveAlignment = true
    }

    func shouldReopenFirstActiveAlignment(
        isSelected: Bool,
        contentHeight: CGFloat
    ) -> Bool {
        guard isSelected,
              hasCompletedFirstActiveAlignment,
              !hasUserInteractedSinceFirstActiveAlignment,
              let firstActiveAlignedContentHeight else {
            return false
        }
        return abs(contentHeight - firstActiveAlignedContentHeight) > 0.5
    }
}

private struct VideoDetailHorizontalPagerPosition: Equatable {
    private(set) var selectedIndex = 0
    private(set) var visibleIndex = 0
    private(set) var settledIndex: Int?
    private(set) var isPagingActive = false

    var activeHeaderIndex: Int {
        isPagingActive ? visibleIndex : selectedIndex
    }

    mutating func setSelectedIndex(_ index: Int) {
        selectedIndex = clamped(index)
        if !isPagingActive {
            visibleIndex = selectedIndex
        }
    }

    mutating func setVisibleIndex(_ index: Int) -> Bool {
        let nextIndex = clamped(index)
        guard visibleIndex != nextIndex else { return false }
        visibleIndex = nextIndex
        return true
    }

    mutating func setPagingActive(_ isActive: Bool, settledIndex: Int?) -> Bool {
        guard isPagingActive != isActive else { return false }
        isPagingActive = isActive
        if !isActive, let settledIndex {
            visibleIndex = clamped(settledIndex)
        }
        return true
    }

    mutating func markSettled(_ index: Int) -> Bool {
        let nextIndex = clamped(index)
        selectedIndex = nextIndex
        visibleIndex = nextIndex
        guard settledIndex != nextIndex else { return false }
        settledIndex = nextIndex
        return true
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
    var isHorizontalPagingActive = false
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
        guard !isApplyingExternalOffset, !isHorizontalPagingActive else { return }
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
    private let contentView = UIView()
    private let listHeaderView = UIView()
    private let collapseSpacerView = UIView()
    private let contentBottomSpacerView = UIView()
    private let host = UIHostingController(rootView: AnyView(EmptyView()))
    private var hostMinimumHeightConstraint: NSLayoutConstraint!
    private var contentMinimumHeightConstraint: NSLayoutConstraint!
    private var collapseSpacerHeightConstraint: NSLayoutConstraint!
    private var contentBottomSpacerHeightConstraint: NSLayoutConstraint!
    private var contentUpdateRevision: Int?
    private var lastAppliedPage: VideoDetailTabPage?
    private var alignmentState = VideoDetailListAlignmentState()
    private var pendingTopAlignmentRetryCount = 0
    private var firstActiveAlignmentVerificationPass = 0
    private var listScrollViewContentSizeObservation: NSKeyValueObservation?
    private var listScrollViewBoundsObservation: NSKeyValueObservation?
    private var nativeScrollDelegateAttachment: ((UIScrollViewDelegate?) -> Void)?
    var onHeaderOffsetChanged: (VideoPageTab, CGFloat) -> Void = { _, _ in }

    init(tab: VideoPageTab, listScrollView: UIScrollView? = nil) {
        let resolvedScrollView = listScrollView ?? VerticalScrollView()
        self.listScrollView = resolvedScrollView
        self.defaultScrollView = resolvedScrollView as? VerticalScrollView
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
            self?.resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
            let velocity = panGestureRecognizer.velocity(in: view)
            return abs(velocity.x) <= abs(velocity.y) * 1.05
        }
        view.addSubview(listScrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        listScrollView.addSubview(contentView)

        listHeaderView.backgroundColor = .clear
        listHeaderView.isUserInteractionEnabled = true
        listScrollView.addSubview(listHeaderView)

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

        hostMinimumHeightConstraint = host.view.heightAnchor.constraint(greaterThanOrEqualTo: listScrollView.frameLayoutGuide.heightAnchor)
        contentMinimumHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1)
        collapseSpacerHeightConstraint = collapseSpacerView.heightAnchor.constraint(equalToConstant: 1)
        contentBottomSpacerHeightConstraint = contentBottomSpacerView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            listScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            listScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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
            self?.alignmentState.markUserInteractionAfterFirstActiveAlignment()
            self?.resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
        }
        coordinator.onVisibleOffsetChange = { [weak self] tab, offset in
            self?.onHeaderOffsetChanged(tab, offset)
        }
        if !page.isSelected, !hasExplicitPendingTopAlignment {
            cancelPendingTopAlignment()
        }
        switch page.content {
        case .nativeScrollView(let nativePage):
            if nativeScrollDelegateAttachment == nil {
                nativeScrollDelegateAttachment = nativePage.attachScrollDelegate
                nativePage.attachScrollDelegate(coordinator)
            }
            nativePage.update()
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
                host.view.isHidden = true
                host.rootView = AnyView(EmptyView())
            }
            alignmentState.resetForContentUpdate()
            if !alignmentState.hasAppliedInitialListOffset && !alignmentState.hasExplicitPendingTopAlignment {
                alignmentState.needsInitialHeaderOffsetReset = true
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
            collapseSpacerHeightConstraint.constant = offsetContext.collapseSpacerHeight
            contentMinimumHeightConstraint.constant = offsetContext.minimumContentHeight
            hostMinimumHeightConstraint.isActive = true
        case .nativeScrollView:
            applyBottomContentSpacing(page.contentBottomPadding, usesContentSpacer: false)
            collapseSpacerHeightConstraint.constant = 0
            contentMinimumHeightConstraint.constant = 1
            hostMinimumHeightConstraint.isActive = false
        }
        if alignmentState.needsInitialHeaderOffsetReset {
            applyInitialHeaderOffsetResetIfNeeded()
        } else if alignmentState.pendingTopAlignment != nil {
            resolvePendingTopAlignmentSoon()
        }
    }

    private func handleScrollGeometryChange() {
        applyCurrentPageGeometryRules()
        resolvePendingTopAlignmentIfPossible()
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
        if abs(contentMinimumHeightConstraint.constant - offsetContext.minimumContentHeight) > 0.5 {
            contentMinimumHeightConstraint.constant = isNativeScrollView ? 1 : offsetContext.minimumContentHeight
        }
        applyNativeMinimumContentSizeIfNeeded(page: page, offsetContext: offsetContext)
        if alignmentState.shouldReopenFirstActiveAlignment(
            isSelected: page.isSelected,
            contentHeight: listScrollView.contentSize.height
        ) {
            alignmentState.reopenFirstActiveAlignmentAfterContentSizeChange()
        }
        if alignmentState.pendingTopAlignment != nil {
            resolvePendingTopAlignmentIfPossible()
            return
        }
        if page.isSelected, !alignmentState.hasCompletedFirstActiveAlignment {
            applyFirstActiveAlignmentIfNeeded()
            return
        }
        if alignmentState.needsInitialHeaderOffsetReset {
            applyInitialHeaderOffsetResetIfNeeded()
        }
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
        if abs(contentBottomSpacerHeightConstraint.constant - contentSpacerHeight) > 0.5 {
            contentBottomSpacerHeightConstraint.constant = contentSpacerHeight
        }
        let bottomInset = usesContentSpacer ? 0 : resolvedBottomSpacing
        if abs(listScrollView.contentInset.bottom - bottomInset) > 0.5 {
            listScrollView.contentInset.bottom = bottomInset
        }
        if abs(listScrollView.verticalScrollIndicatorInsets.bottom - resolvedBottomSpacing) > 0.5 {
            listScrollView.verticalScrollIndicatorInsets.bottom = resolvedBottomSpacing
        }
    }

    private func applyNativeMinimumContentSizeIfNeeded(
        page: VideoDetailTabPage,
        offsetContext: VideoDetailListOffsetContext
    ) {
        guard case .nativeScrollView = page.content else {
            return
        }
        let requiredContentHeight = offsetContext.minimumListContentHeight
        guard listScrollView.contentSize.height < requiredContentHeight - 0.5 else {
            return
        }
        listScrollView.contentSize = CGSize(
            width: listScrollView.contentSize.width,
            height: requiredContentHeight
        )
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

    private func resolvePendingTopAlignmentSoon() {
        resolvePendingTopAlignmentIfPossible()
        schedulePendingTopAlignmentRetry()
    }

    private func schedulePendingTopAlignmentRetry() {
        guard alignmentState.pendingTopAlignment != nil else {
            pendingTopAlignmentRetryCount = 0
            return
        }
        guard pendingTopAlignmentRetryCount < 8 else { return }
        pendingTopAlignmentRetryCount += 1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            self.resolvePendingTopAlignmentIfPossible()
            if self.alignmentState.pendingTopAlignment != nil {
                self.schedulePendingTopAlignmentRetry()
            }
        }
    }

    private func resolvePendingTopAlignmentIfPossible(allowDuringInteraction: Bool = false) {
        guard let targetOffsetY = pendingTopAlignmentTargetOffsetY() else { return }
        if !allowDuringInteraction {
            guard !listScrollView.isTracking, !listScrollView.isDragging, !listScrollView.isDecelerating else { return }
        }
        guard setNormalizedContentOffsetYIfReachable(targetOffsetY) else { return }
        if abs(listScrollView.verticalContentOffsetExcludingBounce - targetOffsetY) <= 0.5 {
            alignmentState.markInitialOffsetApplied()
            alignmentState.cancelPendingTopAlignment()
            pendingTopAlignmentRetryCount = 0
            if lastAppliedPage?.isSelected == true {
                markFirstActiveAlignmentCompleted()
            }
        }
    }

    private func applyInitialHeaderOffsetResetIfNeeded(allowDuringInteraction: Bool = false) {
        guard alignmentState.needsInitialHeaderOffsetReset, let page = lastAppliedPage else { return }
        if !allowDuringInteraction {
            guard !listScrollView.isTracking, !listScrollView.isDragging, !listScrollView.isDecelerating else { return }
        }
        let targetOffsetY = page.headerGeometry.listOffsetContext(
            in: listScrollView.bounds.height
        ).initialNormalizedOffsetY
        guard setNormalizedContentOffsetYIfReachable(targetOffsetY) else {
            alignmentState.pendingTopAlignment = .initial
            resolvePendingTopAlignmentSoon()
            return
        }
        if abs(listScrollView.verticalContentOffsetExcludingBounce - targetOffsetY) <= 0.5 {
            alignmentState.markInitialOffsetApplied()
            alignmentState.cancelPendingTopAlignment()
        }
    }

    private func cancelPendingTopAlignment() {
        alignmentState.cancelPendingTopAlignment()
    }

    private func pendingTopAlignmentTargetOffsetY() -> CGFloat? {
        guard let pendingTopAlignment = alignmentState.pendingTopAlignment,
              let page = lastAppliedPage else { return nil }
        switch pendingTopAlignment {
        case .initial:
            return page.headerGeometry.listOffsetContext(in: listScrollView.bounds.height).initialNormalizedOffsetY
        case .explicit(let offsetY):
            return offsetY
        }
    }

    private var hasExplicitPendingTopAlignment: Bool {
        alignmentState.hasExplicitPendingTopAlignment
    }

    func settleAfterHorizontalActivation() {
        loadViewIfNeeded()
        applyFirstActiveAlignmentIfNeeded(allowDuringInteraction: true)
    }

    private func applyFirstActiveAlignmentIfNeeded(allowDuringInteraction: Bool = false) {
        guard let page = lastAppliedPage else { return }
        let targetOffsetY = page.headerGeometry.listOffsetContext(
            in: listScrollView.bounds.height
        ).initialNormalizedOffsetY
        coordinator.visualTopContentOffsetY = targetOffsetY
        if alignmentState.needsInitialHeaderOffsetReset {
            applyInitialHeaderOffsetResetIfNeeded(allowDuringInteraction: allowDuringInteraction)
            guard !alignmentState.needsInitialHeaderOffsetReset else { return }
        }
        if !allowDuringInteraction {
            guard !listScrollView.isTracking, !listScrollView.isDragging, !listScrollView.isDecelerating else { return }
        }
        if !alignmentState.hasCompletedFirstActiveAlignment {
            guard setNormalizedContentOffsetYIfReachable(targetOffsetY) else {
                alignmentState.pendingTopAlignment = .initial
                resolvePendingTopAlignmentSoon()
                return
            }
            alignmentState.markInitialOffsetApplied()
            markFirstActiveAlignmentCompleted()
            cancelPendingTopAlignment()
            return
        }
        guard VideoDetailPagerOffsetModel.shouldAlignToVisualTopAfterHorizontalActivation(
            currentOffset: listScrollView.verticalContentOffsetExcludingBounce,
            visualTopOffset: targetOffsetY
        ) else {
            cancelPendingTopAlignment()
            return
        }
        setNormalizedContentOffsetY(targetOffsetY)
        alignmentState.markInitialOffsetApplied()
        markFirstActiveAlignmentCompleted()
    }

    private func markFirstActiveAlignmentCompleted() {
        alignmentState.markFirstActiveAlignmentCompleted(contentHeight: listScrollView.contentSize.height)
        scheduleFirstActiveAlignmentVerification()
    }

    private func scheduleFirstActiveAlignmentVerification() {
        guard firstActiveAlignmentVerificationPass == 0 else { return }
        firstActiveAlignmentVerificationPass = 1
        DispatchQueue.main.async { [weak self] in
            self?.runFirstActiveAlignmentVerification()
        }
    }

    private func runFirstActiveAlignmentVerification() {
        view.layoutIfNeeded()
        applyCurrentPageGeometryRules()
        guard alignmentState.hasCompletedFirstActiveAlignment,
              alignmentState.isFirstActiveAlignmentStabilizing,
              lastAppliedPage?.isSelected == true else {
            firstActiveAlignmentVerificationPass = 0
            return
        }
        if firstActiveAlignmentVerificationPass < 3 {
            firstActiveAlignmentVerificationPass += 1
            DispatchQueue.main.async { [weak self] in
                self?.runFirstActiveAlignmentVerification()
            }
            return
        }
        alignmentState.markFirstActiveAlignmentStabilized(contentHeight: listScrollView.contentSize.height)
        firstActiveAlignmentVerificationPass = 0
    }

    var normalizedContentOffsetY: CGFloat {
        loadViewIfNeeded()
        return listScrollView.verticalContentOffsetExcludingBounce
    }

    func syncHeaderOffsetFromActivePage(_ syncMode: VideoDetailPagerOffsetModel.InactiveSyncMode) {
        loadViewIfNeeded()
        cancelPendingTopAlignment()
        let syncOffsetY = syncMode.normalizedOffsetY
        guard setNormalizedContentOffsetYIfReachable(syncOffsetY) else {
            alignmentState.pendingTopAlignment = .explicit(syncOffsetY)
            resolvePendingTopAlignmentSoon()
            return
        }
        alignmentState.markInitialOffsetApplied()
    }

    func setHorizontalPagingActive(_ isActive: Bool) {
        coordinator.isHorizontalPagingActive = isActive
        if !isActive {
            coordinator.resetReportedOffset(listScrollView.verticalContentOffsetExcludingBounce)
        }
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

    private func setNormalizedContentOffsetY(_ offsetY: CGFloat) {
        guard let page = lastAppliedPage else { return }
        let rawTopOffsetY = page.headerGeometry.rawContentOffsetY(forNormalizedOffsetY: offsetY, in: listScrollView)
        setRawContentOffsetYIfNeeded(rawTopOffsetY)
    }

    @discardableResult
    private func setNormalizedContentOffsetYIfReachable(_ offsetY: CGFloat) -> Bool {
        let rawTopOffsetY = clampedRawContentOffsetY(forNormalizedOffsetY: offsetY)
        guard abs(normalizedContentOffsetY(forRawOffsetY: rawTopOffsetY) - offsetY) <= 0.5 else {
            return false
        }
        setRawContentOffsetYIfNeeded(rawTopOffsetY)
        return true
    }

    private func setRawContentOffsetYIfNeeded(_ rawTopOffsetY: CGFloat) {
        guard abs(listScrollView.contentOffset.y - rawTopOffsetY) > 0.5 else { return }
        coordinator.isApplyingExternalOffset = true
        defer { coordinator.isApplyingExternalOffset = false }
        listScrollView.setContentOffset(CGPoint(x: listScrollView.contentOffset.x, y: rawTopOffsetY), animated: false)
        coordinator.resetReportedOffset(listScrollView.verticalContentOffsetExcludingBounce)
        onHeaderOffsetChanged(coordinator.tab, listScrollView.verticalContentOffsetExcludingBounce)
    }

    func headerAttachmentView() -> UIView {
        loadViewIfNeeded()
        return listHeaderView
    }

    private func clampedRawContentOffsetY(forNormalizedOffsetY offsetY: CGFloat) -> CGFloat {
        guard let page = lastAppliedPage else { return 0 }
        return page.headerGeometry.rawContentOffsetY(forNormalizedOffsetY: offsetY, in: listScrollView)
    }

    private func normalizedContentOffsetY(forRawOffsetY rawOffsetY: CGFloat) -> CGFloat {
        guard let page = lastAppliedPage else { return rawOffsetY + listScrollView.adjustedContentInset.top }
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
        let inset = adjustedContentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, contentSize.height - bounds.height + inset.bottom)
        return min(max(contentOffset.y, minOffsetY), maxOffsetY) + inset.top
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
        var onHorizontalVisibleIndexChanged: ((Int) -> Void)?
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
            let index = Int(listScrollView.contentOffset.x / width)
            onHorizontalVisibleIndexChanged?(min(max(index, 0), VideoPageTab.allCases.count - 1))
        }

        func scrollViewDidEndDecelerating(_ listScrollView: UIScrollView) {
            updateSelectedTab(from: listScrollView)
            onPagingActivityChanged?(false)
        }

        func scrollViewDidEndScrollingAnimation(_ listScrollView: UIScrollView) {
            updateSelectedTab(from: listScrollView)
            onPagingActivityChanged?(false)
        }

        func scrollViewDidEndDragging(_ listScrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                updateSelectedTab(from: listScrollView)
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

        private func updateSelectedTab(from listScrollView: UIScrollView) {
            let width = listScrollView.bounds.width
            guard width > 0 else { return }
            let index = Int(round(listScrollView.contentOffset.x / width))
            let tab = VideoPageTab.page(at: index)
            if selectedTab.wrappedValue != tab {
                selectedTab.wrappedValue = tab
            }
            onSelectedIndexSettled?(index)
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
        private var headerSyncState = VideoDetailSmoothHeaderSyncState.state(
            activeOffset: 0,
            collapseDistance: 0
        )
        private var hasSyncedInactivePages = false
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
            coordinator.onHorizontalVisibleIndexChanged = { [weak self] index in
                self?.setHeaderVisibleIndex(index)
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
            pagerPosition.setSelectedIndex(selectedIndex)
            if introduction.contentUpdateRevision != latestPages[.introduction]?.contentUpdateRevision
                || comments.contentUpdateRevision != latestPages[.comments]?.contentUpdateRevision {
                hasSyncedInactivePages = false
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
            if !animated {
                settleSelectedPageIfNeeded(pagerPosition.selectedIndex)
            }
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

        private func settleSelectedPageIfNeeded(_ index: Int) {
            let clampedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            guard pagerPosition.settledIndex != clampedIndex else {
                finishHorizontalPaging(at: clampedIndex)
                return
            }
            finishHorizontalPaging(at: clampedIndex)
        }

        private func settlePageAfterHorizontalSelection(_ index: Int) {
            finishHorizontalPaging(at: index)
        }

        private func finishHorizontalPaging(at index: Int) {
            let clampedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            let didChangeSettledIndex = pagerPosition.markSettled(clampedIndex)
            updateScrollsToTop(for: VideoPageTab.page(at: clampedIndex))
            layoutHeaderHosts()
            switch VideoPageTab.page(at: clampedIndex) {
            case .introduction:
                if didChangeSettledIndex {
                    introductionPage.settleAfterHorizontalActivation()
                }
                introductionPage.reportCurrentOffset()
            case .comments:
                if didChangeSettledIndex {
                    commentsPage?.settleAfterHorizontalActivation()
                }
                commentsPage?.reportCurrentOffset()
            }
            updateHeaderAttachmentForCurrentState()
            syncInactivePageHeaderOffset()
        }

        private func updateScrollsToTop(for activeTab: VideoPageTab) {
            introductionPage.setScrollsToTop(activeTab == .introduction)
            commentsPage?.setScrollsToTop(activeTab == .comments)
        }

        private func setHorizontalPagingActive(_ isActive: Bool) {
            guard pagerPosition.setPagingActive(
                isActive,
                settledIndex: isActive ? nil : settledIndexFromHorizontalOffset()
            ) else { return }
            introductionPage.setHorizontalPagingActive(isActive)
            commentsPage?.setHorizontalPagingActive(isActive)
            updateHeaderAttachmentForCurrentState()
            if !isActive {
                syncInactivePageHeaderOffset()
            }
        }

        private func setHeaderVisibleIndex(_ index: Int) {
            guard pagerPosition.setVisibleIndex(index) else { return }
            updateHeaderAttachmentForCurrentState()
        }

        private func settledIndexFromHorizontalOffset() -> Int {
            let width = scrollView.bounds.width
            guard width > 0 else { return pagerPosition.selectedIndex }
            let index = Int(round(scrollView.contentOffset.x / width))
            return min(max(index, 0), VideoPageTab.allCases.count - 1)
        }

        private func syncInactivePageHeaderOffset(activeOffset providedActiveOffset: CGFloat? = nil) {
            guard let activePage = verticalPageController(for: VideoPageTab.page(at: pagerPosition.selectedIndex)) else {
                return
            }
            let activeOffset = providedActiveOffset ?? activePage.normalizedContentOffsetY
            let previousSyncState = headerSyncState
            let nextSyncState = updateHeaderSyncState(activeOffset: activeOffset)
            guard let syncMode = inactiveSyncMode(
                previousState: previousSyncState,
                nextState: nextSyncState
            ) else { return }
            hasSyncedInactivePages = true
            for tab in VideoPageTab.allCases where tab.pageIndex != pagerPosition.selectedIndex {
                verticalPageController(for: tab)?.syncHeaderOffsetFromActivePage(syncMode)
            }
        }

        private func inactiveSyncMode(
            previousState: VideoDetailSmoothHeaderSyncState,
            nextState: VideoDetailSmoothHeaderSyncState
        ) -> VideoDetailPagerOffsetModel.InactiveSyncMode? {
            if !hasSyncedInactivePages {
                return nextState.inactiveSyncMode
            }
            if nextState.isSyncingListOffsets {
                return nextState.inactiveSyncMode
            }
            if previousState.isSyncingListOffsets {
                return nextState.inactiveSyncMode
            }
            return nil
        }

        @discardableResult
        private func updateHeaderSyncState(activeOffset: CGFloat) -> VideoDetailSmoothHeaderSyncState {
            guard let page = latestPages[VideoPageTab.page(at: pagerPosition.selectedIndex)] else {
                return headerSyncState
            }
            headerSyncState = page.headerGeometry.smoothHeaderSyncState(activeOffset: activeOffset)
            return headerSyncState
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
            let attachmentState = VideoDetailHeaderAttachmentState.state(
                isHorizontalPagingActive: pagerPosition.isPagingActive,
                selectedOffset: offset,
                syncState: page.headerGeometry.smoothHeaderSyncState(activeOffset: offset),
                collapseDistance: page.headerGeometry.collapseDistance
            )
            applyHeaderAttachment(attachmentState, pageController: pageController)
        }

        private func applyHeaderAttachment(
            _ attachmentState: VideoDetailHeaderAttachmentState,
            pageController: VideoDetailVerticalScrollPageViewController
        ) {
            switch attachmentState {
            case .listHeader:
                attachHeader(to: pageController.headerAttachmentView(), originY: 0)
            case .pagerContainer(let originY):
                attachHeader(to: view, originY: originY)
            }
        }

        private var activeHeaderTab: VideoPageTab {
            VideoPageTab.page(at: pagerPosition.activeHeaderIndex)
        }

        private func attachHeader(to parentView: UIView, originY: CGFloat) {
            if headerContainerView.superview !== parentView {
                headerContainerView.removeFromSuperview()
                parentView.addSubview(headerContainerView)
            }
            var frame = headerContainerView.frame
            frame.origin = CGPoint(x: 0, y: originY)
            frame.size.width = parentView.bounds.width
            headerContainerView.frame = frame
            parentView.bringSubviewToFront(headerContainerView)
        }

        private func updateHeaderContainerPosition(for tab: VideoPageTab, offsetY: CGFloat) {
            guard tab == activeHeaderTab else { return }
            guard let page = latestPages[tab] else { return }
            guard let pageController = verticalPageController(for: tab) else { return }
            if pagerPosition.isPagingActive {
                let syncState = page.headerGeometry.smoothHeaderSyncState(activeOffset: offsetY)
                headerSyncState = syncState
                let attachmentState = VideoDetailHeaderAttachmentState.state(
                    isHorizontalPagingActive: true,
                    selectedOffset: offsetY,
                    syncState: syncState,
                    collapseDistance: page.headerGeometry.collapseDistance
                )
                applyHeaderAttachment(attachmentState, pageController: pageController)
            } else {
                if tab == VideoPageTab.page(at: pagerPosition.selectedIndex) {
                    syncInactivePageHeaderOffset(activeOffset: offsetY)
                }
                updateHeaderAttachmentForCurrentState()
            }
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

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
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
            guard pinHeaderFrame.contains(point)
                || (isContinuationHeaderInteractive && continuationHeaderFrame.contains(point)) else {
                return nil
            }
            return super.hitTest(point, with: event)
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
