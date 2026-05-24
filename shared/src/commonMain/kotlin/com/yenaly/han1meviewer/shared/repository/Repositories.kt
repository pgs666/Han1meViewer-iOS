package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HanimeInfo
import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.model.PageResult
import com.yenaly.han1meviewer.shared.model.SearchParams

interface HomeRepository {
    suspend fun getHomePage(): HomePage
}

interface SearchRepository {
    suspend fun search(params: SearchParams, page: Int): PageResult<HanimeInfo>
}

interface VideoRepository {
    suspend fun getVideo(videoCode: String): HanimeVideo
}
