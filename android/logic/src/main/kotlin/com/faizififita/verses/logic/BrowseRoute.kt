package com.faizififita.verses.logic

sealed interface BrowseRoute {
    data object Browse : BrowseRoute
    data class Collection(val name: String) : BrowseRoute
    data class Section(val name: String) : BrowseRoute
    data class Category(val section: String, val name: String) : BrowseRoute
    data class Prayer(val id: Long) : BrowseRoute
}
