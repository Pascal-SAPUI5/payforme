//
//  BillCommentTests.swift
//  PayForMeTests
//
//  Cospend bills carry a free-text comment. PayForMe never read it and never
//  sent it, so a note written in the Cospend web UI was invisible in the app —
//  and there was no way to add one on the go.
//
//  Issue #41 asks for Cospend bill types as well. Those are not an API concept:
//  Cospend derives custom and personal-part splits from the owers' weights, so
//  supporting them means reimplementing that arithmetic. The comment field is
//  the part the reporter explicitly asked for as a fallback, and it stands on
//  its own.
//

import XCTest
@testable import PayForMe

final class BillCommentTests: XCTestCase {

    private let member = Person(id: 1, weight: 1, name: "Alice", activated: true)
    private var testDate: Date { DateFormatter.cospend.date(from: "2026-05-14")! }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.cospend)
        return decoder
    }

    // MARK: Decoding

    func testCommentIsDecoded() throws {
        let json = """
        [{"id":42,"amount":12.5,"what":"Groceries","date":"2026-05-14","payer_id":1,
          "owers":[],"repeat":"n","comment":"Bob paid the deposit separately"}]
        """.data(using: .utf8)!

        let bills = try decoder().decode([Bill].self, from: json)
        XCTAssertEqual(bills.first?.comment, "Bob paid the deposit separately")
    }

    /// iHateMoney never sends a comment, and neither do older Cospend versions.
    func testPayloadWithoutCommentStillDecodes() throws {
        let json = """
        [{"id":7,"amount":12.5,"what":"Tea","date":"2026-05-04","payer_id":1,
          "owers":[],"repeat":"n"}]
        """.data(using: .utf8)!

        let bills = try decoder().decode([Bill].self, from: json)
        XCTAssertEqual(bills.count, 1)
        XCTAssertNil(bills.first?.comment)
    }

    // MARK: Request parameters

    func testParamsCarryTheComment() {
        let bill = Bill(id: 9, amount: 5, what: "Rent", date: testDate, payer_id: 1,
                        owers: [member], repeat: "n", lastchanged: nil,
                        categoryid: nil, paymentmode: nil,
                        comment: "Split unevenly, see chat")

        let params = bill.paramsFor(.cospend)
        XCTAssertEqual(params["comment"] as? String, "Split unevenly, see chat")
    }

    /// A bill without a comment sends an empty one rather than omitting the key,
    /// so clearing a comment in the app actually clears it on the server.
    func testParamsFallBackToAnEmptyComment() {
        let bill = Bill(id: -1, amount: 5, what: "New", date: testDate, payer_id: 1,
                        owers: [member], repeat: "n")

        XCTAssertEqual(bill.paramsFor(.cospend)["comment"] as? String, "")
    }

    /// iHateMoney has no comment field; sending one would be noise.
    func testIHateMoneyParamsCarryNoComment() {
        let bill = Bill(id: 9, amount: 5, what: "Rent", date: testDate, payer_id: 1,
                        owers: [member], repeat: "n", lastchanged: nil,
                        categoryid: nil, paymentmode: nil, comment: "ignored")

        XCTAssertNil(bill.paramsFor(.iHateMoney)["comment"])
    }

    // MARK: The edit path

    /// Editing a bill must not silently drop a comment written elsewhere — the
    /// same failure mode categories and payment modes had.
    func testEditingABillKeepsItsComment() throws {
        let json = """
        [{"id":42,"amount":12.5,"what":"Groceries","date":"2026-05-14","payer_id":1,
          "owers":[],"repeat":"n","comment":"Deposit paid separately"}]
        """.data(using: .utf8)!
        let original = try decoder().decode([Bill].self, from: json)[0]

        let viewModel = makeViewModel(for: original)
        // The user changes only the amount.
        viewModel.amount = "18.00"

        let edited = try XCTUnwrap(viewModel.createBill())
        XCTAssertEqual(edited.amount, 18.0, accuracy: 0.001, "the edit itself still applies")
        XCTAssertEqual(edited.comment, "Deposit paid separately", "the comment must survive")
    }

    /// The point of the feature: a comment typed into the form reaches the server.
    func testCommentEnteredInTheFormIsSent() throws {
        let viewModel = makeViewModel(for: Bill.newBill())
        viewModel.topic = "Taxi"
        viewModel.amount = "24.00"
        viewModel.comment = "Airport run, Bob owes his half in cash"

        let created = try XCTUnwrap(viewModel.createBill())
        XCTAssertEqual(created.paramsFor(.cospend)["comment"] as? String,
                       "Airport run, Bob owes his half in cash")
    }

    /// An existing comment is shown in the form rather than starting blank.
    func testExistingCommentPrefillsTheForm() throws {
        let bill = Bill(id: 3, amount: 5, what: "Rent", date: testDate, payer_id: 1,
                        owers: [member], repeat: "n", lastchanged: nil,
                        categoryid: nil, paymentmode: nil, comment: "Half of March")

        XCTAssertEqual(makeViewModel(for: bill).comment, "Half of March")
    }

    // MARK: Helpers

    private func makeViewModel(for bill: Bill) -> BillDetailViewModel {
        let viewModel = BillDetailViewModel(currentBill: bill)
        let project = Project(name: "test", password: "pw", token: "tok",
                              backend: .cospend, url: URL(string: "https://test.de")!,
                              projectId: "test")
        project.members = [member.id: member]
        viewModel.currentProject = project
        viewModel.selectedPayer = member.id
        if viewModel.topic.isEmpty { viewModel.topic = bill.what }
        viewModel.povm.members = [member]
        viewModel.povm.isOwing = [true]
        return viewModel
    }
}
