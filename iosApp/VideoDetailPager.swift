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
    static func initialNormalizedOffsetY(
        visualTopOffset: CGFloat,
        collapseDistance: CGFloat
    ) -> CGFloat {
        clamp(visualTopOffset, upperBound: collapseDistance)
    }

    static func inactiveSyncNormalizedOffsetY(
        activeOffset: CGFloat?,
        initialOffset: CGFloat,
        collapseDistance: CGFloat
    ) -> CGFloat {
        guard let activeOffset else { return initialOffset }
        return clamp(activeOffset, upperBound: collapseDistance)
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
        return VideoDetailListOffsetContext(
            contentTopInset: contentTopInset,
            initialNormalizedOffsetY: visualTopOffset,
            inactiveSyncNormalizedOffsetY: VideoDetailPagerOffsetModel.inactiveSyncNormalizedOffsetY(
                activeOffset: activeOffset,
                initialOffset: visualTopOffset,
                collapseDistance: collapseDistance
            ),
            collapseSpacerHeight: collapseSpacerHeight,
            minimumContentHeight: minimumContentHeight(in: scrollBoundsHeight)
        )
    }

    func minimumContentHeight(in scrollBoundsHeight: CGFloat) -> CGFloat {
        VideoDetailPagerOffsetModel.minimumContentHeight(
            scrollBoundsHeight: scrollBoundsHeight,
            pinnedVisibleHeight: pinnedVisibleHeight,
            collapseDistance: collapseDistance
        )
    }

    func rawContentOffsetY(forNormalizedOffsetY offsetY: CGFloat, in scrollView: UIScrollView) -> CGFloat {
        let inset = scrollView.adjustedContentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
        let rawOffsetY = offsetY - inset.top
        return min(max(rawOffsetY, minOffsetY), maxOffsetY)
    }

    func normalizedContentOffsetY(forRawOffsetY rawOffsetY: CGFloat, in scrollView: UIScrollView) -> CGFloat {
        rawOffsetY + scrollView.adjustedContentInset.top
    }

}

private struct VideoDetailListOffsetContext: Equatable {
    let contentTopInset: CGFloat
    let initialNormalizedOffsetY: CGFloat
    let inactiveSyncNormalizedOffsetY: CGFloat
    let collapseSpacerHeight: CGFloat
    let minimumContentHeight: CGFloat
}

private enum VideoDetailPendingTopAlignment {
    case initial
    case explicit(CGFloat)
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
    let content: () -> AnyView

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
        self.content = { AnyView(content()) }
    }
}

struct VideoDetailPagerContainer<Introduction: View, Comments: View>: View {
    @Binding var state: VideoDetailPagerState
    let collapseDistance: CGFloat
    let headerHeight: CGFloat
    let pinHeaderHeight: CGFloat
    let pinnedVisibleHeight: CGFloat
    let playerScrollAway: CGFloat
    let introductionContentBottomPadding: CGFloat
    let commentsContentBottomPadding: CGFloat
    let introductionContentRevision: Int
    let commentsContentRevision: Int
    let introduction: () -> Introduction
    let comments: () -> Comments

    private var selectedTabBinding: Binding<VideoPageTab> {
        Binding(
            get: { state.selectedTab },
            set: { newTab in
                mutateState { $0.selectTab(newTab, collapseDistance: collapseDistance) }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            VideoDetailTabPager(
                selectedTab: selectedTabBinding,
                introduction: tabPage(
                    .introduction,
                    contentBottomPadding: introductionContentBottomPadding,
                    contentUpdateRevision: introductionContentRevision,
                    content: introduction
                ),
                comments: tabPage(
                    .comments,
                    contentBottomPadding: commentsContentBottomPadding,
                    contentUpdateRevision: commentsContentRevision,
                    content: comments
                )
            )
            .frame(maxHeight: .infinity)

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
            .offset(y: max(headerHeight - playerScrollAway, pinnedVisibleHeight - pinHeaderHeight))
            .zIndex(1)
        }
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onValueChange(of: collapseDistance) { newValue in
            mutateState { $0.clampCollapse(to: newValue) }
        }
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isApplyingExternalOffset, !isHorizontalPagingActive else { return }
        let offset = scrollView.verticalContentOffsetExcludingBounce
        guard lastReportedOffset.map({ abs($0 - offset) > 0.5 }) ?? true else { return }
        lastReportedOffset = offset
        onOffsetChange(tab, offset)
    }

    func resetReportedOffset(_ offset: CGFloat) {
        lastReportedOffset = offset
    }

    @objc func handlePan(_ panGestureRecognizer: UIPanGestureRecognizer) {
        guard let scrollView = panGestureRecognizer.view as? UIScrollView else { return }
        switch panGestureRecognizer.state {
        case .began:
            onVerticalInteractionBegan()
            onInteractionBegan(tab)
            lastTopPullTranslationY = 0
        case .changed:
            guard scrollView.verticalContentOffsetExcludingBounce <= visualTopContentOffsetY + 0.5 else {
                lastTopPullTranslationY = panGestureRecognizer.translation(in: scrollView).y
                return
            }
            let translationY = panGestureRecognizer.translation(in: scrollView).y
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
    private let scrollView = VerticalScrollView()
    private let contentView = UIView()
    private let listHeaderView = UIView()
    private let collapseSpacerView = UIView()
    private let host = UIHostingController(rootView: AnyView(EmptyView()))
    private var hostMinimumHeightConstraint: NSLayoutConstraint!
    private var contentMinimumHeightConstraint: NSLayoutConstraint!
    private var collapseSpacerHeightConstraint: NSLayoutConstraint!
    private var contentUpdateRevision: Int?
    private var lastAppliedPage: VideoDetailTabPage?
    private var topAlignmentGeneration = 0
    private var pendingTopAlignment: VideoDetailPendingTopAlignment?
    private var needsInitialHeaderOffsetReset = true

    init(tab: VideoPageTab) {
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.keyboardDismissMode = .interactive
        scrollView.delegate = coordinator
        scrollView.panGestureRecognizer.addTarget(coordinator, action: #selector(VideoDetailVerticalScrollPageCoordinator.handlePan(_:)))
        scrollView.onGeometryChange = { [weak self] in
            self?.handleScrollGeometryChange()
        }
        scrollView.shouldBeginVerticalPan = { [weak self] panGestureRecognizer, view in
            self?.resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
            let velocity = panGestureRecognizer.velocity(in: view)
            return abs(velocity.x) <= abs(velocity.y) * 1.05
        }
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)

        listHeaderView.backgroundColor = .clear
        listHeaderView.isUserInteractionEnabled = false
        scrollView.addSubview(listHeaderView)

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        contentView.addSubview(host.view)
        host.didMove(toParent: self)

        collapseSpacerView.translatesAutoresizingMaskIntoConstraints = false
        collapseSpacerView.backgroundColor = .clear
        contentView.addSubview(collapseSpacerView)

        hostMinimumHeightConstraint = host.view.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        contentMinimumHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1)
        collapseSpacerHeightConstraint = collapseSpacerView.heightAnchor.constraint(equalToConstant: 1)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentMinimumHeightConstraint,

            host.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostMinimumHeightConstraint,

            collapseSpacerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collapseSpacerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collapseSpacerView.topAnchor.constraint(equalTo: host.view.bottomAnchor),
            collapseSpacerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collapseSpacerHeightConstraint
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
            self?.resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
        }
        if !page.isSelected, !hasExplicitPendingTopAlignment {
            cancelPendingTopAlignment()
        }
        if contentUpdateRevision != page.contentUpdateRevision {
            contentUpdateRevision = page.contentUpdateRevision
            host.rootView = page.content()
            needsInitialHeaderOffsetReset = true
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        let previousVisualTopContentOffsetY = coordinator.visualTopContentOffsetY
        let geometry = page.headerGeometry
        let offsetContext = geometry.listOffsetContext(in: scrollView.bounds.height)
        let visualTopOffset = offsetContext.initialNormalizedOffsetY
        lastAppliedPage = page
        coordinator.visualTopContentOffsetY = visualTopOffset
        applyTopContentInset(offsetContext.contentTopInset)
        applyListHeaderFrame()
        applyBottomContentInset(page.contentBottomPadding)
        collapseSpacerHeightConstraint.constant = offsetContext.collapseSpacerHeight
        contentMinimumHeightConstraint.constant = offsetContext.minimumContentHeight
        if needsInitialHeaderOffsetReset {
            applyInitialHeaderOffsetResetIfNeeded()
        } else if pendingTopAlignment != nil {
            resolvePendingTopAlignmentSoon()
        } else {
            preserveVisualTopIfNeeded(
                previousOffsetY: previousVisualTopContentOffsetY,
                targetOffsetY: visualTopOffset
            )
        }
    }

    private func handleScrollGeometryChange() {
        applyCurrentPageGeometryRules()
        resolvePendingTopAlignmentIfPossible()
    }

    private func applyCurrentPageGeometryRules() {
        guard let page = lastAppliedPage else { return }
        let geometry = page.headerGeometry
        let offsetContext = geometry.listOffsetContext(in: scrollView.bounds.height)
        if abs(contentMinimumHeightConstraint.constant - offsetContext.minimumContentHeight) > 0.5 {
            contentMinimumHeightConstraint.constant = offsetContext.minimumContentHeight
        }
        let visualTopOffset = offsetContext.initialNormalizedOffsetY
        if pendingTopAlignment != nil {
            resolvePendingTopAlignmentIfPossible()
            return
        }
        if needsInitialHeaderOffsetReset {
            applyInitialHeaderOffsetResetIfNeeded()
            return
        }
        guard page.isSelected else { return }
        guard scrollView.verticalContentOffsetExcludingBounce <= visualTopOffset + 8 else { return }
        requestTopAlignment(targetOffsetY: visualTopOffset)
    }

    private func applyTopContentInset(_ topInset: CGFloat) {
        let resolvedTopInset = max(topInset, 0)
        guard abs(scrollView.contentInset.top - resolvedTopInset) > 0.5 else { return }
        scrollView.contentInset.top = resolvedTopInset
        scrollView.verticalScrollIndicatorInsets.top = resolvedTopInset
        applyListHeaderFrame()
    }

    private func applyBottomContentInset(_ bottomInset: CGFloat) {
        let resolvedBottomInset = max(bottomInset, 0)
        guard abs(scrollView.contentInset.bottom - resolvedBottomInset) > 0.5 else { return }
        scrollView.contentInset.bottom = resolvedBottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = resolvedBottomInset
    }

    private func applyListHeaderFrame() {
        let topInset = max(scrollView.contentInset.top, 0)
        let nextFrame = CGRect(
            x: 0,
            y: -topInset,
            width: scrollView.bounds.width,
            height: topInset
        )
        guard !listHeaderView.frame.isApproximatelyEqual(to: nextFrame) else { return }
        listHeaderView.frame = nextFrame
    }

    private func requestTopAlignment(targetOffsetY: CGFloat) {
        topAlignmentGeneration &+= 1
        pendingTopAlignment = .explicit(targetOffsetY)
        resolvePendingTopAlignmentSoon()
    }

    private func resolvePendingTopAlignmentSoon() {
        let generation = topAlignmentGeneration
        resolvePendingTopAlignmentIfPossible()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.topAlignmentGeneration == generation else { return }
            self.resolvePendingTopAlignmentIfPossible()
        }
    }

    private func resolvePendingTopAlignmentIfPossible(allowDuringInteraction: Bool = false) {
        guard let targetOffsetY = pendingTopAlignmentTargetOffsetY() else { return }
        if !allowDuringInteraction {
            guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating else { return }
        }
        guard setNormalizedContentOffsetYIfReachable(targetOffsetY) else { return }
        if abs(scrollView.verticalContentOffsetExcludingBounce - targetOffsetY) <= 0.5 {
            needsInitialHeaderOffsetReset = false
            cancelPendingTopAlignment()
        }
    }

    private func applyInitialHeaderOffsetResetIfNeeded(allowDuringInteraction: Bool = false) {
        guard needsInitialHeaderOffsetReset, let page = lastAppliedPage else { return }
        if !allowDuringInteraction {
            guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating else { return }
        }
        let targetOffsetY = page.headerGeometry.listOffsetContext(
            in: scrollView.bounds.height
        ).initialNormalizedOffsetY
        guard setNormalizedContentOffsetYIfReachable(targetOffsetY) else {
            pendingTopAlignment = .initial
            return
        }
        if abs(scrollView.verticalContentOffsetExcludingBounce - targetOffsetY) <= 0.5 {
            needsInitialHeaderOffsetReset = false
            cancelPendingTopAlignment()
        }
    }

    private func cancelPendingTopAlignment() {
        pendingTopAlignment = nil
    }

    private func pendingTopAlignmentTargetOffsetY() -> CGFloat? {
        guard let pendingTopAlignment, let page = lastAppliedPage else { return nil }
        switch pendingTopAlignment {
        case .initial:
            return page.headerGeometry.listOffsetContext(in: scrollView.bounds.height).initialNormalizedOffsetY
        case .explicit(let offsetY):
            return offsetY
        }
    }

    private var hasExplicitPendingTopAlignment: Bool {
        guard let pendingTopAlignment else { return false }
        if case .explicit = pendingTopAlignment {
            return true
        }
        return false
    }

    func settleAfterHorizontalActivation() {
        loadViewIfNeeded()
        let targetOffsetY = coordinator.visualTopContentOffsetY
        if needsInitialHeaderOffsetReset {
            applyInitialHeaderOffsetResetIfNeeded(allowDuringInteraction: true)
            guard !needsInitialHeaderOffsetReset else { return }
        }
        guard VideoDetailPagerOffsetModel.shouldAlignToVisualTopAfterHorizontalActivation(
            currentOffset: scrollView.verticalContentOffsetExcludingBounce,
            visualTopOffset: targetOffsetY
        ) else {
            cancelPendingTopAlignment()
            return
        }
        requestTopAlignment(targetOffsetY: targetOffsetY)
        resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
    }

    var normalizedContentOffsetY: CGFloat {
        loadViewIfNeeded()
        return scrollView.verticalContentOffsetExcludingBounce
    }

    func headerSyncOffset(fromActiveOffset activeOffset: CGFloat) -> CGFloat {
        lastAppliedPage?.headerGeometry.listOffsetContext(
            in: scrollView.bounds.height,
            activeOffset: activeOffset
        ).inactiveSyncNormalizedOffsetY ?? 0
    }

    func syncHeaderOffsetFromActivePage(_ offsetY: CGFloat) {
        loadViewIfNeeded()
        guard let page = lastAppliedPage else { return }
        cancelPendingTopAlignment()
        let syncOffsetY = page.headerGeometry.listOffsetContext(
            in: scrollView.bounds.height,
            activeOffset: offsetY
        ).inactiveSyncNormalizedOffsetY
        guard setNormalizedContentOffsetYIfReachable(syncOffsetY) else {
            pendingTopAlignment = .explicit(syncOffsetY)
            return
        }
        needsInitialHeaderOffsetReset = false
    }

    func setHorizontalPagingActive(_ isActive: Bool) {
        coordinator.isHorizontalPagingActive = isActive
        if !isActive {
            coordinator.resetReportedOffset(scrollView.verticalContentOffsetExcludingBounce)
        }
    }

    private func preserveVisualTopIfNeeded(previousOffsetY: CGFloat, targetOffsetY: CGFloat) {
        guard abs(previousOffsetY - targetOffsetY) > 0.5 else { return }
        guard abs(scrollView.verticalContentOffsetExcludingBounce - previousOffsetY) <= 1 else { return }
        setNormalizedContentOffsetY(targetOffsetY)
    }

    private func setNormalizedContentOffsetY(_ offsetY: CGFloat) {
        guard let page = lastAppliedPage else { return }
        let rawTopOffsetY = page.headerGeometry.rawContentOffsetY(forNormalizedOffsetY: offsetY, in: scrollView)
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
        guard abs(scrollView.contentOffset.y - rawTopOffsetY) > 0.5 else { return }
        coordinator.isApplyingExternalOffset = true
        defer { coordinator.isApplyingExternalOffset = false }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: rawTopOffsetY), animated: false)
        coordinator.resetReportedOffset(scrollView.verticalContentOffsetExcludingBounce)
    }

    private func clampedRawContentOffsetY(forNormalizedOffsetY offsetY: CGFloat) -> CGFloat {
        guard let page = lastAppliedPage else { return 0 }
        return page.headerGeometry.rawContentOffsetY(forNormalizedOffsetY: offsetY, in: scrollView)
    }

    private func normalizedContentOffsetY(forRawOffsetY rawOffsetY: CGFloat) -> CGFloat {
        guard let page = lastAppliedPage else { return rawOffsetY + scrollView.adjustedContentInset.top }
        return page.headerGeometry.normalizedContentOffsetY(forRawOffsetY: rawOffsetY, in: scrollView)
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
    let introduction: VideoDetailTabPage
    let comments: VideoDetailTabPage

    init(
        selectedTab: Binding<VideoPageTab>,
        introduction: VideoDetailTabPage,
        comments: VideoDetailTabPage
    ) {
        _selectedTab = selectedTab
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
        private var pendingSettledIndex: Int?

        init(selectedTab: Binding<VideoPageTab>) {
            self.selectedTab = selectedTab
        }

        func shouldAnimateProgrammaticSelection(to index: Int) -> Bool {
            defer { lastProgrammaticIndex = index }
            guard let lastProgrammaticIndex else { return false }
            return lastProgrammaticIndex != index
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            onPagingActivityChanged?(true)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            onPagingActivityChanged?(false)
            updateSelectedTab(from: scrollView)
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            onPagingActivityChanged?(false)
            updateSelectedTab(from: scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                onPagingActivityChanged?(false)
                updateSelectedTab(from: scrollView)
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

        private func updateSelectedTab(from scrollView: UIScrollView) {
            let width = scrollView.bounds.width
            guard width > 0 else { return }
            let index = Int(round(scrollView.contentOffset.x / width))
            let tab = VideoPageTab.page(at: index)
            if selectedTab.wrappedValue != tab {
                pendingSettledIndex = index
                selectedTab.wrappedValue = tab
            } else {
                onSelectedIndexSettled?(index)
            }
        }

        func consumePendingSettledIndex(for selectedIndex: Int) -> Bool {
            guard pendingSettledIndex == selectedIndex else { return false }
            pendingSettledIndex = nil
            onSelectedIndexSettled?(selectedIndex)
            return true
        }
    }

    final class PagingViewController: UIViewController {
        private let coordinator: Coordinator
        private let scrollView = PagingScrollView()
        private let contentView = UIView()
        private let introductionPage = VideoDetailVerticalScrollPageViewController(tab: .introduction)
        private let commentsPage = VideoDetailVerticalScrollPageViewController(tab: .comments)
        private var selectedIndex = 0
        private var lastSettledSelectedIndex: Int?
        private var pendingSelectedIndex: Int?
        private var lastLaidOutWidth: CGFloat = 0
        private var isHorizontalPagingActive = false

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
            addPage(commentsPage)

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
                introductionPage.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

                commentsPage.view.leadingAnchor.constraint(equalTo: introductionPage.view.trailingAnchor),
                commentsPage.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                commentsPage.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                commentsPage.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                commentsPage.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                commentsPage.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let width = scrollView.bounds.width
            let widthChanged = abs(width - lastLaidOutWidth) > 0.5
            lastLaidOutWidth = width
            if let pendingSelectedIndex {
                self.pendingSelectedIndex = nil
                setSelectedIndex(pendingSelectedIndex, animated: false)
            } else if widthChanged {
                setSelectedIndex(selectedIndex, animated: false)
            }
        }

        func updatePages(
            introduction: VideoDetailTabPage,
            comments: VideoDetailTabPage,
            selectedIndex: Int,
            animated: Bool
        ) {
            loadViewIfNeeded()
            self.selectedIndex = min(max(selectedIndex, 0), VideoPageTab.allCases.count - 1)
            introductionPage.update(page: introduction)
            commentsPage.update(page: comments)
            syncInactivePageHeaderOffset()
            let consumedSettledIndex = coordinator.consumePendingSettledIndex(for: self.selectedIndex)
            guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating else { return }
            setSelectedIndex(self.selectedIndex, animated: animated)
            if !animated && !consumedSettledIndex {
                settleSelectedPageIfNeeded(self.selectedIndex)
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
            selectedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            let width = scrollView.bounds.width
            guard width > 0 else {
                pendingSelectedIndex = selectedIndex
                return
            }
            let targetOffset = CGPoint(x: CGFloat(selectedIndex) * width, y: 0)
            guard abs(scrollView.contentOffset.x - targetOffset.x) > 0.5 else { return }
            if animated {
                setHorizontalPagingActive(true)
            }
            scrollView.setContentOffset(targetOffset, animated: animated)
        }

        private func settleSelectedPageIfNeeded(_ index: Int) {
            let clampedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            guard lastSettledSelectedIndex != clampedIndex else { return }
            lastSettledSelectedIndex = clampedIndex
            settlePageAfterHorizontalSelection(clampedIndex)
        }

        private func settlePageAfterHorizontalSelection(_ index: Int) {
            lastSettledSelectedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            syncInactivePageHeaderOffset()
            switch VideoPageTab.page(at: index) {
            case .introduction:
                introductionPage.settleAfterHorizontalActivation()
            case .comments:
                commentsPage.settleAfterHorizontalActivation()
            }
        }

        private func setHorizontalPagingActive(_ isActive: Bool) {
            guard isHorizontalPagingActive != isActive else { return }
            isHorizontalPagingActive = isActive
            introductionPage.setHorizontalPagingActive(isActive)
            commentsPage.setHorizontalPagingActive(isActive)
            if !isActive {
                syncInactivePageHeaderOffset()
            }
        }

        private func syncInactivePageHeaderOffset() {
            guard let activePage = verticalPageController(for: VideoPageTab.page(at: selectedIndex)) else {
                return
            }
            let activeOffset = activePage.normalizedContentOffsetY
            let syncOffset = activePage.headerSyncOffset(fromActiveOffset: activeOffset)
            for tab in VideoPageTab.allCases where tab.pageIndex != selectedIndex {
                verticalPageController(for: tab)?.syncHeaderOffsetFromActivePage(syncOffset)
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
}

private extension UIView {
    func hasScrollableHorizontalDescendant(at location: CGPoint, excluding excludedView: UIView) -> Bool {
        guard let hitView = hitTest(location, with: nil) else { return false }
        var current: UIView? = hitView
        while let view = current, view !== excludedView {
            if let scrollView = view as? UIScrollView,
               scrollView.isScrollEnabled,
               scrollView.panGestureRecognizer.isEnabled,
               scrollView.contentSize.width > scrollView.bounds.width + 1,
               scrollView.contentSize.width > scrollView.contentSize.height {
                return true
            }
            current = view.superview
        }
        return false
    }
}
