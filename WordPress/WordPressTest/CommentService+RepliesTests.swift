import Foundation
import Nimble
import OHHTTPStubs
import XCTest

@testable import WordPress

final class CommentService_RepliesTests: CoreDataTestCase {
    private let commentID: Int = 1
    private let siteID: Int = 2
    private let authorID: Int = 99
    private let timeout: TimeInterval = 2
    private let commentsV2SuccessFilename = "comments-v2-success.json"
    private let emptyArrayFilename = "empty-array.json"

    private var endpoint: String {
        "sites/\(siteID)/comments"
    }

    private var commentService: CommentService!
    private var accountService: AccountService!


    override func setUp() {
        super.setUp()

        commentService = CommentService(coreDataStack: contextManager)
        accountService = makeAccountService()
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()

        commentService = nil
        accountService = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_getReplies_givenSuccessfulResult_callsSuccessBlock() {
        let expectation = expectation(description: "Fetch latest reply ID should succeed")
        let expectedReplyID = 54 // from comments-v2-success.json
        HTTPStubs.stubRequest(forEndpoint: endpoint, withFileAtPath: stubFilePath(commentsV2SuccessFilename))

        commentService.getLatestReplyID(for: commentID, siteID: siteID, accountService: accountService) { replyID in
            expect(replyID).to(equal(expectedReplyID))
            expectation.fulfill()
        } failure: { _ in
            XCTFail("This block shouldn't get called.")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    func test_getReplies_givenEmptyResult_callsSuccessBlock() {
        let expectation = expectation(description: "Fetch latest reply ID should succeed")
        let expectedReplyID = 0
        HTTPStubs.stubRequest(forEndpoint: endpoint, withFileAtPath: stubFilePath(emptyArrayFilename))

        commentService.getLatestReplyID(for: commentID, siteID: siteID, accountService: accountService) { replyID in
            expect(replyID).to(equal(expectedReplyID))
            expectation.fulfill()
        } failure: { _ in
            XCTFail("This block shouldn't get called.")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    func test_getReplies_givenFailureResult_callsFailureBlock() {
        let expectation = expectation(description: "Fetch latest reply ID should fail")
        stub(condition: isMethodGET()) { _ in
            return HTTPStubsResponse(data: Data(), statusCode: 500, headers: nil)
        }

        commentService.getLatestReplyID(for: commentID, siteID: siteID, accountService: accountService) { _ in
            XCTFail("This block shouldn't get called.")
            expectation.fulfill()
        } failure: { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    func test_getReplies_addsCommentIdInParameter() {
        let (mockService, mockApi) = makeMockService()
        let parentKey = CommentServiceRemoteREST.RequestKeys.parent.rawValue

        mockService.getLatestReplyID(for: commentID,
                                     siteID: siteID,
                                     accountService: accountService,
                                     success: { _ in },
                                     failure: { _ in })

        var parameters = [String: Any]()
        expect(mockApi.parametersPassedIn).toNot(beNil())
        expect { parameters = mockApi.parametersPassedIn! as! [String: Any] }.toNot(throwError())
        expect(parameters[parentKey] as? Int).to(equal(commentID))
    }

    func test_replyToPost_givenSuccessfulAPICall_insertsNewComment() throws {
        let post = ReaderPost(context: mainContext)
        post.siteID = 1
        post.postID = 2
        contextManager.saveContextAndWait(mainContext)

        stub(condition: isPath("/rest/v1.1/sites/1/posts/2/replies/new")) { _ in
            HTTPStubsResponse(
                jsonObject: [
                    "id": 19,
                    "post": 2,
                    "status": "approved",
                    "type": "comment",
                    "content": "<p>test comment</p>\n",
                ] as [String: Any],
                statusCode: 200,
                headers: nil
            )
        }

        // No comment before calling the reply function
        try XCTAssertEqual(mainContext.count(for: Comment.safeFetchRequest()), 0)

        // Call the reply function and wait for the HTTP API to complete
        waitUntil { done in
            self.commentService.reply(to: post, content: "test comment") {
                done()
            } failure: { error in
                XCTFail("Unexpected error: \(String(describing: error))")
                done()
            }
        }

        // The new comment should be inserted into the database
        try XCTAssertEqual(mainContext.count(for: Comment.safeFetchRequest()), 1)
    }

    func test_replyToPost_givenFailureAPICall_callsFailureBlock() throws {
        let post = ReaderPost(context: mainContext)
        post.siteID = 1
        post.postID = 2
        contextManager.saveContextAndWait(mainContext)

        stub(condition: isPath("/rest/v1.1/sites/1/posts/2/replies/new")) { _ in
            HTTPStubsResponse(
                jsonObject: [String: Any](),
                statusCode: 400,
                headers: nil
            )
        }

        // No comment before calling the reply function
        try XCTAssertEqual(mainContext.count(for: Comment.safeFetchRequest()), 0)

        // Call the reply function and wait for the HTTP API to complete
        waitUntil { done in
            self.commentService.reply(to: post, content: "test comment") {
                XCTFail("The failure should be called instead")
                done()
            } failure: { error in
                done()
            }
        }

        // The HTTP API call failed and no comment was inserted into the database
        try XCTAssertEqual(mainContext.count(for: Comment.safeFetchRequest()), 0)
    }
}

// MARK: - Test Helpers

private extension CommentService_RepliesTests {
    // returns a mock service that never calls the success or failure block.
    // primarily used for testing the passed in parameters – see MockWordPressComRestApi
    func makeMockService() -> (CommentService, MockWordPressComRestApi) {
        let mockApi = MockWordPressComRestApi()
        let mockFactory = CommentServiceRemoteFactoryMock(restApi: mockApi)
        return (.init(coreDataStack: contextManager, commentServiceRemoteFactory: mockFactory), mockApi)
    }

    func makeAccountService() -> AccountService {
        let service = AccountService(coreDataStack: contextManager)
        let accountID = service.createOrUpdateAccount(withUsername: "testuser", authToken: "authtoken")
        let account = try! contextManager.mainContext.existingObject(with: accountID) as! WPAccount
        account.userID = NSNumber(value: authorID)
        service.setDefaultWordPressComAccount(account)

        return service
    }

    func stubFilePath(_ filename: String) -> String {
        return OHPathForFile(filename, type(of: self))!
    }
}

private class CommentServiceRemoteFactoryMock: CommentServiceRemoteFactory {
    var restApi: WordPressComRestApi

    init(restApi: WordPressComRestApi) {
        self.restApi = restApi
    }

    override func restRemote(siteID: NSNumber, api: WordPressComRestApi) -> CommentServiceRemoteREST {
        return CommentServiceRemoteREST(wordPressComRestApi: restApi, siteID: siteID)
    }
}
