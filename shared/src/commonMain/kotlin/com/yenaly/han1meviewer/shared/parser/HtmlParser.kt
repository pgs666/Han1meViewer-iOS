package com.yenaly.han1meviewer.shared.parser

import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.model.PageResult
import com.yenaly.han1meviewer.shared.model.HanimeInfo
import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.model.MySubscriptions
import com.yenaly.han1meviewer.shared.model.UserPlaylistPage
import com.yenaly.han1meviewer.shared.model.UserVideoListPage
import com.yenaly.han1meviewer.shared.model.VideoComments

interface HtmlParser {
    fun parseHome(html: String, isAlreadyLogin: Boolean = false): HomePage
    fun parseSearch(html: String, params: SearchParams, page: Int): PageResult<HanimeInfo>
    fun parseVideo(html: String, videoCode: String): HanimeVideo
    fun parseSubscriptions(html: String): MySubscriptions
    fun parseUserVideoList(html: String, page: Int): UserVideoListPage
    fun parseUserPlaylists(html: String, page: Int): UserPlaylistPage
    fun parseComments(json: String): VideoComments
    fun parseCommentReplies(json: String): VideoComments
}
