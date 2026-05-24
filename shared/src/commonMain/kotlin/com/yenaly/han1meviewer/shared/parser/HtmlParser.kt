package com.yenaly.han1meviewer.shared.parser

import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.model.PageResult
import com.yenaly.han1meviewer.shared.model.HanimeInfo
import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.model.MySubscriptions

interface HtmlParser {
    fun parseHome(html: String): HomePage
    fun parseSearch(html: String, params: SearchParams, page: Int): PageResult<HanimeInfo>
    fun parseVideo(html: String, videoCode: String): HanimeVideo
    fun parseSubscriptions(html: String): MySubscriptions
}
