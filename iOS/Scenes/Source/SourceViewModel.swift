//
//  SourceViewModel.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 1/3/23.
//

import Foundation

class SourceViewModel {

    weak var source: Source?

    var manga: [MangaInfo] = []
    var listings: [Listing] = []
    var filters: [FilterBase] = []

    var currentListing: Listing?
    let selectedFilters = SelectedFilters() // TODO: improve filtering system
    var titleQuery: String?

    var currentPage: Int?
    var hasMore = true // indicates if there is more manga to load

    private var savedSelectedFilters: [FilterBase]?
    private var searchTask: Task<(), any Error>?

    func loadListings() async {
        guard let source = source else { return }
        listings = source.listings
        // check for current listing
        let sourceListing = await CoreDataManager.shared.getListing(sourceId: source.id) ?? 0
        if sourceListing > 0 && sourceListing - 1 < listings.count {
            currentListing = listings[sourceListing - 1]
        }
    }

    func loadFilters() async {
        guard let source = source else { return }
        let reset = source.needsFilterRefresh
        filters = (try? await source.getFilters()) ?? []
        if selectedFilters.filters.isEmpty || reset {
            resetSelectedFilters()
        }
    }

    func loadNextMangaPage() async {
        guard let source = source else { return }
        if currentPage == nil {
            await MainActor.run {
                manga = []
            }
        }
        let page = (currentPage ?? 0) + 1
        let result: MangaPageResult?
        if let currentListing = currentListing {
            // load current listing
            result = try? await source.getMangaListing(listing: currentListing, page: page)
        } else if let titleQuery = titleQuery {
            // load search results
            guard !(searchTask?.isCancelled ?? true) else { return }
            result = try? await source.fetchSearchManga(query: titleQuery, filters: selectedFilters.filters, page: page)
        } else {
            // load regular manga list
            result = try? await source.getMangaList(filters: selectedFilters.filters, page: page)
        }
        let mangaInfo = result?.manga.map { $0.toInfo() } ?? []
        await MainActor.run {
            currentPage = page
            hasMore = result?.hasNextPage ?? false
            manga.append(contentsOf: mangaInfo)
        }
    }

    func search(titleQuery: String?) async -> Bool {
        manga = []
        currentPage = nil
        hasMore = true
        self.titleQuery = titleQuery?.isEmpty ?? true ? nil : titleQuery
        if searchTask != nil {
            searchTask?.cancel()
        }
        let task = Task {
            // delay search in case it's cancelled immediately
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            await loadNextMangaPage()
        }
        searchTask = task
        try? await task.value
        if task == searchTask {
            searchTask = nil
        }
        return !task.isCancelled
    }

    func resetFilters(filters: [FilterBase]) {
        for filter in filters {
            if let filter = filter as? CheckFilter {
                filter.value = filter.defaultValue
            } else if let filter = filter as? SortFilter {
                filter.value = filter.defaultValue
            } else if let filter = filter as? SelectFilter {
                filter.value = filter.defaultValue
            } else if let filter = filter as? GroupFilter {
                resetFilters(filters: filter.filters)
            }
        }
    }

    func resetSelectedFilters() {
        guard let source = source else { return }
        resetFilters(filters: filters)
        selectedFilters.filters = source.getDefaultFilters()
    }

    func saveSelectedFilters() {
        // deep clone filters to prevent being saved as references
        savedSelectedFilters = selectedFilters.filters.compactMap { $0.copy() as? FilterBase }
    }

    func clearSavedFilters() {
        savedSelectedFilters = nil
    }

    /// Returns a boolean indicating if saved filters differ from selected filters.
    func savedFiltersDiffer() -> Bool {
        guard let savedSelectedFilters = savedSelectedFilters else { return true }
        if savedSelectedFilters.count != selectedFilters.filters.count {
            return true
        } else {
            for filter in savedSelectedFilters {
                // get matching filter
                let targetFilter = selectedFilters.filters.first { filter.type == $0.type && filter.name == $0.name }
                if let target = targetFilter {
                    if let target = target as? SortFilter, let filter = filter as? SortFilter {
                        // compare sort filters
                        if filter.value.index != target.value.index || filter.value.ascending != target.value.ascending {
                            return true
                        }
                    } else {
                        // compare filter values
                        let newValue = target.valueByPropertyName(name: "value") as? AnyHashable?
                        let oldValue = filter.valueByPropertyName(name: "value") as? AnyHashable?
                        if newValue != oldValue {
                            return true
                        }
                    }
                } else {
                    // equivalent filter doesn't exist, they differ
                    return true
                }
            }
        }
        return false
    }
}
