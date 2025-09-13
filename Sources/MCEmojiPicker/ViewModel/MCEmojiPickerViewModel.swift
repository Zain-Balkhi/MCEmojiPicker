// The MIT License (MIT)
//
// Copyright © 2022 Ivan Izyumkin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// Protocol for the `MCEmojiPickerViewModel`.
protocol MCEmojiPickerViewModelProtocol {
    /// Whether the picker shows empty categories. Default false.
    var showEmptyEmojiCategories: Bool { get set }
    /// The emoji categories being used
    var emojiCategories: [MCEmojiCategory] { get }
    /// The observed variable that is responsible for the choice of emoji.
    var selectedEmoji: Observable<MCEmoji?> { get set }
    /// The observed variable that is responsible for the choice of emoji category.
    var selectedEmojiCategoryIndex: Observable<Int> { get set }
    /// The observed variable that is responsible for the search text.
    var searchText: Observable<String> { get set }
    /// Whether the picker is currently in search mode.
    var isSearching: Observable<Bool> { get set }
    /// Clears the selected emoji, setting to `nil`.
    func clearSelectedEmoji()
    /// Returns the number of categories with emojis.
    func numberOfSections() -> Int
    /// Returns the number of emojis in the target section.
    func numberOfItems(in section: Int) -> Int
    /// Returns the `MCEmoji` for the target `IndexPath`.
    func emoji(at indexPath: IndexPath) -> MCEmoji
    /// Returns the localized section name for the target section.
    func sectionHeaderName(for section: Int) -> String
    /// Updates the emoji skin tone and returns the updated `MCEmoji`.
    func updateEmojiSkinTone(_ skinToneRawValue: Int, in indexPath: IndexPath) -> MCEmoji
    /// Updates the search text and filters emojis accordingly.
    func updateSearchText(_ text: String)
    /// Clears the search and returns to normal category view.
    func clearSearch()
}

/// View model which using in `MCEmojiPickerViewController`.
final class MCEmojiPickerViewModel: MCEmojiPickerViewModelProtocol {
    
    // MARK: - Public Properties
    
    public var selectedEmoji = Observable<MCEmoji?>(value: nil)
    public var selectedEmojiCategoryIndex = Observable<Int>(value: 0)
    public var searchText = Observable<String>(value: "")
    public var isSearching = Observable<Bool>(value: false)
    public var showEmptyEmojiCategories = false
    public var emojiCategories: [MCEmojiCategory] {
        if isSearching.value {
            return searchResults
        } else {
            return allEmojiCategories.filter({ showEmptyEmojiCategories || $0.emojis.count > 0 })
        }
    }
    
    // MARK: - Private Properties
    
    /// All emoji categories.
    private var allEmojiCategories = [MCEmojiCategory]()
    /// Search results when searching.
    private var searchResults = [MCEmojiCategory]()
    
    // MARK: - Initializers
    
    init(unicodeManager: MCUnicodeManagerProtocol = MCUnicodeManager()) {
        allEmojiCategories = unicodeManager.getEmojisForCurrentIOSVersion()
        // Increment usage of each emoji upon selection
        selectedEmoji.bind { emoji in
            emoji?.incrementUsageCount()
        }
    }
    
    // MARK: - Public Methods
    
    public func clearSelectedEmoji() {
        selectedEmoji.value = nil
    }
    
    public func numberOfSections() -> Int {
        return emojiCategories.count
    }
    
    public func numberOfItems(in section: Int) -> Int {
        return emojiCategories[section].emojis.count
    }
    
    public func emoji(at indexPath: IndexPath) -> MCEmoji {
        return emojiCategories[indexPath.section].emojis[indexPath.row]
    }
    
    public func sectionHeaderName(for section: Int) -> String {
        if isSearching.value {
            return "Search Results"
        } else {
            return emojiCategories[section].categoryName
        }
    }
    
    public func updateEmojiSkinTone(_ skinToneRawValue: Int, in indexPath: IndexPath) -> MCEmoji {
        let emoji = emojiCategories[indexPath.section].emojis[indexPath.row]
        
        // If we're in search mode, we need to find the original emoji in allEmojiCategories
        if isSearching.value {
            // Find the original emoji by matching emojiKeys (which uniquely identify each emoji)
            for categoryIndex in 0..<allEmojiCategories.count {
                for emojiIndex in 0..<allEmojiCategories[categoryIndex].emojis.count {
                    if allEmojiCategories[categoryIndex].emojis[emojiIndex].emojiKeys == emoji.emojiKeys {
                        allEmojiCategories[categoryIndex].emojis[emojiIndex].set(skinToneRawValue: skinToneRawValue)
                        return allEmojiCategories[categoryIndex].emojis[emojiIndex]
                    }
                }
            }
        } else {
            // Normal mode - use the original logic
            let categoryType: MCEmojiCategoryType = emojiCategories[indexPath.section].type
            let allCategoriesIndex: Int = allEmojiCategories.firstIndex { $0.type == categoryType } ?? 0
            allEmojiCategories[allCategoriesIndex].emojis[indexPath.row].set(skinToneRawValue: skinToneRawValue)
            return allEmojiCategories[allCategoriesIndex].emojis[indexPath.row]
        }
        
        // Fallback - update the emoji directly and return it
        emoji.set(skinToneRawValue: skinToneRawValue)
        return emoji
    }
    
    public func updateSearchText(_ text: String) {
        searchText.value = text
        isSearching.value = !text.isEmpty
        
        if text.isEmpty {
            searchResults = []
        } else {
            performSearch(with: text)
        }
    }
    
    public func clearSearch() {
        searchText.value = ""
        isSearching.value = false
        searchResults = []
    }
    
    // MARK: - Private Methods
    
    private func performSearch(with text: String) {
        let searchTerm = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        var allMatchingEmojis: [MCEmoji] = []
        
        // Search through all emoji categories
        for category in allEmojiCategories {
            for emoji in category.emojis {
                if emoji.searchKey.lowercased().contains(searchTerm) {
                    allMatchingEmojis.append(emoji)
                }
            }
        }
        
        // Create a single search results category
        if !allMatchingEmojis.isEmpty {
            let searchCategory = MCEmojiCategory(
                type: .frequentlyUsed, // Use frequentlyUsed as a generic type for search results
                emojis: allMatchingEmojis
            )
            searchResults = [searchCategory]
        } else {
            searchResults = []
        }
    }
}
