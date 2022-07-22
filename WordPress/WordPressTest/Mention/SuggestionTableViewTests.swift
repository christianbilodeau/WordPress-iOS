import Foundation

@testable import WordPress
import XCTest

final class SuggestionTableViewTests: CoreDataTestCase {

    private var view: SuggestionsTableView!
    private var delegate: SuggestionsTableViewDelegateMock!
    private var viewModel: SuggestionsListViewModelType {
        return view.viewModel
    }

    override func setUpWithError() throws {
        let blog = Blog(context: mainContext)
        let viewModel = SuggestionsListViewModel(blog: blog)
        viewModel.context = mainContext
        viewModel.userSuggestionService = SuggestionServiceMock(context: mainContext)
        viewModel.siteSuggestionService = SiteSuggestionServiceMock(context: mainContext)
        self.delegate = SuggestionsTableViewDelegateMock()
        self.view = SuggestionsTableView(viewModel: viewModel, delegate: delegate)
    }

    // MARK: - Test Row Selection

    /// Tests that selecting a user suggestion row pass the right params to view's delegate
    func testUserSuggestionRowSelected() {
        // Given
        let word = "@"
        let position = 0
        self.viewModel.suggestionType = .mention

        // When
        self.viewModel.reloadData()
        self.view.showSuggestions(forWord: word)
        self.view.selectSuggestion(atPosition: position)

        // Then
        XCTAssertEqual(delegate.selectedSuggestion, "ghaskayne0")
        XCTAssertEqual(delegate.searchText, "")
    }

    /// Tests that selecting a site suggestion row pass the right params to view's delegate
    func testSiteSuggestionRowSelected() {
        // Given
        let word = "+"
        let position = 0
        self.viewModel.suggestionType = .xpost

        // When
        self.viewModel.reloadData()
        self.view.showSuggestions(forWord: word)
        self.view.selectSuggestion(atPosition: position)

        // Then
        XCTAssertEqual(delegate.selectedSuggestion, "pen.io")
        XCTAssertEqual(delegate.searchText, "")
    }
}
