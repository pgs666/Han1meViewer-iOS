package com.yenaly.han1meviewer.shared.parser

import com.fleeksoft.ksoup.Ksoup
import com.fleeksoft.ksoup.nodes.Element
import com.yenaly.han1meviewer.shared.model.HanimeInfo
import com.yenaly.han1meviewer.shared.model.HanimeItemType
import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.model.HomeBanner
import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.model.HomeSection
import com.yenaly.han1meviewer.shared.model.Artist
import com.yenaly.han1meviewer.shared.model.ArtistSubscription
import com.yenaly.han1meviewer.shared.model.MySubscriptions
import com.yenaly.han1meviewer.shared.model.PageResult
import com.yenaly.han1meviewer.shared.model.PlaybackSource
import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.model.SubscriptionItem
import com.yenaly.han1meviewer.shared.model.SubscriptionVideoItem
import com.yenaly.han1meviewer.shared.model.UserPlaylist
import com.yenaly.han1meviewer.shared.model.UserPlaylistPage
import com.yenaly.han1meviewer.shared.model.UserVideoListPage
import com.yenaly.han1meviewer.shared.model.VideoMyList
import com.yenaly.han1meviewer.shared.model.VideoMyListItem
import com.yenaly.han1meviewer.shared.model.VideoPlaylist
import kotlinx.datetime.LocalDate

class KsoupHtmlParser : HtmlParser {
    override fun parseHome(html: String): HomePage {
        val body = Ksoup.parse(html).body()
        val csrfToken = body.selectFirst("input[name=_token]")?.attr("value")
        val userInfo = body.selectFirst("div#user-modal-dp-wrapper")
        val avatarUrl = userInfo?.selectFirst("img")?.absUrl("src")
        val username = userInfo?.selectFirst("#user-modal-name")?.text()
        val userHref = body.selectFirst("#user-modal-trigger")?.attr("href")
        val userId = USER_ID_REGEX.find(userHref.orEmpty())?.groupValues?.getOrNull(1)

        val bannerWrapper = body.selectFirst("div#home-banner-wrapper")
        val bannerImage = bannerWrapper?.previousElementSibling()
        val bannerTitle = bannerImage?.selectFirst("img")?.attr("alt")
        val bannerPic = bannerImage?.select("img")?.let { images ->
            images.getOrNull(1)?.absUrl("src") ?: images.getOrNull(0)?.absUrl("src")
        }
        val banner = if (bannerTitle != null && bannerPic != null) {
            HomeBanner(
                title = bannerTitle,
                description = bannerWrapper.selectFirst("h4")?.ownText(),
                imageUrl = bannerPic,
                videoCode = body.select("script")
                    .firstOrNull { it.data().contains("watch?v=") }
                    ?.data()
                    ?.toVideoCode()
            )
        } else null

        val rows = body.select("div#home-rows-wrapper > div")
        val sections = DEFAULT_HOME_SECTION_KEYS.mapIndexedNotNull { index, key ->
            val items = rows.getOrNull(index).toHanimeInfoList()
            if (items.isEmpty()) null else HomeSection(key = key, title = key, items = items)
        }

        return HomePage(
            csrfToken = csrfToken,
            avatarUrl = avatarUrl,
            username = username,
            banner = banner,
            sections = sections,
            userId = userId,
        )
    }

    override fun parseSearch(
        html: String,
        params: SearchParams,
        page: Int,
    ): PageResult<HanimeInfo> {
        val body = Ksoup.parse(html).body()
        val normalContainer = body.selectFirst(".content-padding-new")
        val simplifiedContainer = body.selectFirst(".home-rows-videos-wrapper")
        val items = when {
            normalContainer != null -> normalContainer.toHanimeInfoList()
            simplifiedContainer != null -> simplifiedContainer.children()
                .mapNotNull { it.toSimplifiedHanimeInfo() }
            else -> emptyList()
        }
        return PageResult(
            items = items,
            page = page,
            hasNext = items.isNotEmpty(),
        )
    }

    override fun parseVideo(html: String, videoCode: String): HanimeVideo {
        val body = Ksoup.parse(html).body()
        val title = body.selectFirst("#shareBtn-title")?.text()?.trim().orEmpty()
        val detailWrapper = body.selectFirst("div.video-details-wrapper")
        val caption = detailWrapper?.selectFirst("div[class^=video-caption-text]")
        val uploadInfo = detailWrapper?.selectFirst("div > div > div")?.text()
        val uploadGroups = uploadInfo?.let { VIEW_AND_UPLOAD_TIME_REGEX.find(it)?.groups }
        val uploadTime = uploadGroups?.get(2)?.value?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
        val views = uploadGroups?.get(1)?.value?.trim()

        val sources = body.selectFirst("video#player")?.let { video ->
            video.children().mapNotNull { source ->
                val url = source.absUrl("src").ifBlank { source.attr("src") }
                if (url.isBlank()) return@mapNotNull null
                PlaybackSource(
                    label = source.attr("size").ifBlank { "auto" }.let { if (it.endsWith("P")) it else "${it}P" },
                    url = url,
                    contentType = source.attr("type").ifBlank { null },
                    isDefault = source.hasAttr("selected")
                )
            }
        }.orEmpty().ifEmpty {
            body.selectFirst("div#player-div-wrapper")
                ?.select("script")
                ?.firstNotNullOfOrNull { script ->
                    VIDEO_SOURCE_REGEX.find(script.data())?.groupValues?.getOrNull(1)
                }
                ?.let { listOf(PlaybackSource(label = "auto", url = it, isDefault = true)) }
                .orEmpty()
        }

        val tags = body.select(".single-video-tag a")
            .map { it.text().substringBefore(" (").removePrefix("#").trim() }
            .filter { it.isNotEmpty() }

        val myListItems = body.select("div[class~=playlist-checkbox-wrapper]").mapNotNull { wrapper ->
            val input = wrapper.selectFirst("input") ?: return@mapNotNull null
            val code = input.attr("id").takeIf { it.isNotBlank() } ?: return@mapNotNull null
            val listTitle = wrapper.selectFirst("span")?.ownText()?.trim()?.takeIf { it.isNotBlank() }
                ?: return@mapNotNull null
            VideoMyListItem(
                code = code,
                title = listTitle,
                isSelected = input.hasAttr("checked"),
            )
        }
        val myList = VideoMyList(
            isWatchLater = body.selectFirst("#playlist-save-checkbox input")?.hasAttr("checked") == true,
            items = myListItems,
        )

        val playlist = body.selectFirst("div#video-playlist-wrapper")?.let { wrapper ->
            val playlistVideos = wrapper.select("#playlist-scroll > div").mapNotNull { item ->
                val detailUrl = item.selectFirst("div > a")?.absUrl("href")
                    ?.ifBlank { item.selectFirst("div > a")?.attr("href") }
                    ?: return@mapNotNull null
                val playlistVideoCode = detailUrl.toVideoCode() ?: return@mapNotNull null
                val panel = item.selectFirst("div[class^=card-mobile-panel]")
                val coverElement = panel?.select("div > div > div > img")?.getOrNull(1)
                    ?: panel?.selectFirst("img")
                val coverUrl = coverElement?.absUrl("src")?.ifBlank { coverElement.attr("src") }
                val itemTitle = coverElement?.attr("alt")?.trim()
                    ?: panel?.selectFirst("div.title, h4.video-title")?.text()?.trim()
                    ?: return@mapNotNull null
                val durationParts = panel?.select("div[class*=card-mobile-duration]")
                HanimeInfo(
                    title = itemTitle,
                    videoCode = playlistVideoCode,
                    coverUrl = coverUrl,
                    detailUrl = detailUrl,
                    duration = durationParts?.firstOrNull()?.text()?.trim()?.ifBlank { null },
                    views = durationParts?.getOrNull(2)?.text()?.substringBefore("次")?.trim()?.ifBlank { null },
                    isPlaying = panel?.text()?.contains("播放") == true,
                    itemType = HanimeItemType.Normal,
                )
            }
            VideoPlaylist(
                name = wrapper.selectFirst("div > div > h4")?.text()?.trim(),
                videos = playlistVideos,
            )
        }

        val related = body.selectFirst("#related-tabcontent").toHanimeInfoList()
        val artist = body.selectFirst("#video-artist-name")?.let { nameElement ->
            val artistName = nameElement.text().trim().takeIf { it.isNotBlank() } ?: return@let null
            val artistGenre = nameElement.nextElementSibling()?.text()?.trim()?.takeIf { it.isNotBlank() }
                ?: return@let null
            val subscribeForm = body.selectFirst("#video-subscribe-form")
            val subscription = subscribeForm?.let { form ->
                val userId = form.selectFirst("input[name=subscribe-user-id]")?.attr("value")
                val artistId = form.selectFirst("input[name=subscribe-artist-id]")?.attr("value")
                val status = form.selectFirst("input[name=subscribe-status]")?.attr("value")
                if (userId != null && artistId != null && status != null) {
                    ArtistSubscription(
                        userId = userId,
                        artistId = artistId,
                        isSubscribed = status == "1",
                    )
                } else {
                    null
                }
            }
            Artist(
                name = artistName,
                avatarUrl = body
                    .select("div.video-details-wrapper > div > a > div > img[style*='position: absolute'][style*='border-radius: 50%']")
                    .attr("src"),
                genre = artistGenre,
                subscription = subscription,
            )
        }

        return HanimeVideo(
            videoCode = videoCode,
            title = title,
            coverUrl = body.selectFirst("video#player")?.absUrl("poster")?.ifBlank { null },
            chineseTitle = caption?.previousElementSibling()?.ownText(),
            description = caption?.ownText(),
            uploadTime = uploadTime,
            views = views,
            tags = tags,
            sources = sources,
            myList = myList,
            playlist = playlist,
            relatedHanimes = related,
            artist = artist,
            favTimes = body.selectFirst("input[name=likes-count]")?.attr("value")?.toIntOrNull(),
            isFav = body.selectFirst("[name=like-status]")?.attr("value").isNullOrEmpty().not(),
            csrfToken = body.selectFirst("input[name=_token]")?.attr("value"),
            currentUserId = body.selectFirst("input[name=like-user-id]")?.attr("value"),
            originalComic = body.selectFirst("a.video-comic-btn")?.attr("href"),
        )
    }

    override fun parseSubscriptions(html: String): MySubscriptions {
        val body = Ksoup.parse(html).body()
        val subscriptionsRoot = body.selectFirst("div.subscriptions-nav")
            ?: return MySubscriptions(
                subscriptions = emptyList(),
                subscriptionVideos = emptyList(),
                maxPage = 1,
                authRequired = true,
            )
        val subscriptionVideosRoot = body.selectFirst("div.content-padding-new")
            ?: return MySubscriptions(
                subscriptions = emptyList(),
                subscriptionVideos = emptyList(),
                maxPage = 1,
                authRequired = true,
            )

        val artists = subscriptionsRoot.select("div.subscriptions-artist-card").mapNotNull { card ->
            val avatarUrl = card.select("img").getOrNull(1)?.absUrl("src")
                ?.ifBlank { card.select("img").getOrNull(1)?.attr("src") }
                ?: return@mapNotNull null
            val artistName = card.selectFirst("div.card-mobile-title")?.text()?.trim()
                ?: return@mapNotNull null

            SubscriptionItem(
                artistName = artistName,
                avatarUrl = avatarUrl,
            )
        }

        val videos = subscriptionVideosRoot.select("div[class^=video-item-container]").mapNotNull { videoCard ->
            val detailUrl = videoCard.selectFirst("a[class^=video-link]")?.absUrl("href")
                ?.ifBlank { videoCard.selectFirst("a[class^=video-link]")?.attr("href") }
                ?: return@mapNotNull null
            val videoCode = detailUrl.toVideoCode() ?: return@mapNotNull null
            val coverUrl = videoCard.select("img[class^=main-thumb]").getOrNull(0)?.absUrl("src")
                ?.ifBlank { videoCard.select("img[class^=main-thumb]").getOrNull(0)?.attr("src") }
                ?: return@mapNotNull null
            val title = videoCard.attr("title").trim().ifBlank {
                videoCard.selectFirst("div.title, h4.video-title")?.text()?.trim().orEmpty()
            }
            if (title.isBlank()) return@mapNotNull null

            val thumbContainer = videoCard.select("div[class^=thumb-container]")
            val artistUploadParts = videoCard.select("div.subtitle a").toSubtitleMetadataParts()

            SubscriptionVideoItem(
                title = title,
                coverUrl = coverUrl,
                videoCode = videoCode,
                duration = thumbContainer.select("div[class^=duration]").text().ifBlank { null },
                views = thumbContainer.select("div[class^=stat-item]").getOrNull(1)?.text(),
                reviews = videoCard.selectFirst(".stats-container .stat-item")?.text()?.replace("thumb_up", "")?.trim(),
                currentArtist = artistUploadParts.getOrNull(0),
                uploadTime = artistUploadParts.getOrNull(1),
            )
        }

        return MySubscriptions(
            subscriptions = artists,
            subscriptionVideos = videos,
            maxPage = body.parseMaxPage(),
        )
    }

    override fun parseUserVideoList(html: String, page: Int): UserVideoListPage {
        val body = Ksoup.parse(html).body()
        val csrfToken = body.selectFirst("input[name=_token]")?.attr("value")
        val description = body.selectFirst("#playlist-show-description")?.ownText()
            ?: body.selectFirst("p.playlist-description")?.text()
        val container = body.selectFirst(".horizontal-row")
            ?: body.selectFirst(".playlist-video-list")
        val items = container.toHanimeInfoList("div[class^=user-tab-item-wrapper]")

        return UserVideoListPage(
            items = items,
            listDescription = description,
            csrfToken = csrfToken,
            page = page,
            hasNext = items.isNotEmpty(),
        )
    }

    override fun parseUserPlaylists(html: String, page: Int): UserPlaylistPage {
        val body = Ksoup.parse(html).body()
        val csrfToken = body.selectFirst("input[name=_token]")?.attr("value")
        val playlists = body.select(".user-tab-item-wrapper").mapNotNull { item ->
            val detailUrl = item.selectFirst("a.video-link")?.absUrl("href")
                ?.ifBlank { item.selectFirst("a.video-link")?.attr("href") }
                ?: return@mapNotNull null
            val listCode = detailUrl.substringAfter("list=", missingDelimiterValue = "").takeIf { it.isNotBlank() }
                ?: return@mapNotNull null
            val title = item.selectFirst(".title")?.ownText()?.trim()?.takeIf { it.isNotBlank() }
                ?: return@mapNotNull null
            val total = item.selectFirst(".stat-item")
                ?.text()
                ?.filter { char -> char.isDigit() }
                ?.toIntOrNull() ?: 0
            val coverUrl = item.selectFirst("img.main-thumb")?.absUrl("src")
                ?.ifBlank { item.selectFirst("img.main-thumb")?.attr("src") }

            UserPlaylist(
                listCode = listCode,
                title = title,
                total = total,
                coverUrl = coverUrl,
            )
        }

        return UserPlaylistPage(
            playlists = playlists,
            csrfToken = csrfToken,
            page = page,
            hasNext = playlists.isNotEmpty(),
        )
    }

    private fun Element?.toHanimeInfoList(
        selector: String = "div[class^=horizontal-card]",
    ): List<HanimeInfo> = this?.select(selector)?.mapNotNull { it.toNormalHanimeInfo() }.orEmpty()

    private fun Element.toNormalHanimeInfo(): HanimeInfo? {
        val title = selectFirst("div.title, h4.video-title")?.text()?.trim()
        val coverUrl = select("img").getOrNull(0)?.absUrl("src")?.ifBlank { select("img").getOrNull(0)?.attr("src") }
        val detailUrl = select("a").getOrNull(0)?.absUrl("href")?.ifBlank { select("a").getOrNull(0)?.attr("href") }
        val videoCode = detailUrl?.toVideoCode()
        if (title == null || coverUrl == null || videoCode == null) return null

        val durationAndViews = select("div[class^=thumb-container]")
        val artistUploadParts = select("div.subtitle a, div.video-meta-data a").toSubtitleMetadataParts()

        return HanimeInfo(
            title = title,
            coverUrl = coverUrl,
            videoCode = videoCode,
            detailUrl = detailUrl,
            duration = durationAndViews.select("div[class^=duration]").text().ifBlank { null },
            views = durationAndViews.select("div[class^=stat-item]").getOrNull(1)?.text(),
            uploadTime = artistUploadParts.getOrNull(1),
            currentArtist = artistUploadParts.getOrNull(0),
            reviews = selectFirst(".stats-container .stat-item")?.text()?.replace("thumb_up", "")?.trim(),
            itemType = HanimeItemType.Normal,
        )
    }

    private fun Element.toSimplifiedHanimeInfo(): HanimeInfo? {
        val detailUrl = absUrl("href").ifBlank { attr("href") }
        val videoCode = detailUrl.toVideoCode()
        val coverUrl = selectFirst("img")?.absUrl("src")?.ifBlank { selectFirst("img")?.attr("src") }
        val title = selectFirst("div.home-rows-videos-title, div[class$=title]")?.text()
        if (videoCode == null || coverUrl == null || title == null) return null
        return HanimeInfo(
            title = title,
            videoCode = videoCode,
            coverUrl = coverUrl,
            detailUrl = detailUrl,
            itemType = HanimeItemType.Simplified,
        )
    }

    private fun String.toVideoCode(): String? = VIDEO_CODE_REGEX.find(this)?.groupValues?.getOrNull(1)

    private fun List<Element>.toSubtitleMetadataParts(): List<String> {
        val parts = map { it.text().trim() }.filter { it.isNotEmpty() }
        if (parts.size != 1) return parts

        val value = parts.single()
        val date = ISO_DATE_REGEX.find(value)?.value ?: return parts
        val artist = value.substringBefore(date).trim().trim('-', '/', '|', ' ', '•')
        return listOf(artist, date).filter { it.isNotEmpty() }
    }

    private fun Element.parseMaxPage(): Int {
        return select("ul.pagination")
            .lastOrNull()
            ?.select("a.page-link[href]")
            ?.mapNotNull { link ->
                PAGE_REGEX.find(link.attr("href"))?.groupValues?.getOrNull(1)?.toIntOrNull()
            }
            ?.maxOrNull() ?: 1
    }

    private companion object {
        val VIDEO_CODE_REGEX = Regex("""(?:watch\?v=|/videos/|/watch/)(\d+)""")
        val PAGE_REGEX = Regex("""\?page=(\d+)""")
        val ISO_DATE_REGEX = Regex("""\d{4}-\d{2}-\d{2}""")
        val USER_ID_REGEX = Regex("""/user/(\d+)""")
        val VIDEO_SOURCE_REGEX = Regex("""const source = '(.+)'""")
        val VIEW_AND_UPLOAD_TIME_REGEX = Regex("""(.+?)\s*(\d{4}-\d{2}-\d{2})""")
        val DEFAULT_HOME_SECTION_KEYS = listOf(
            "latestRelease",
            "latestHanime",
            "ecchiAnime",
            "shortEpisodeAnime",
            "unknown4",
            "motionAnime",
            "threeDCG",
            "twoPointFiveDAnime",
            "twoDAnime",
            "unknown9",
            "aiGenerated",
            "mmd",
            "cosplay",
            "watchingNow",
        )
    }
}
