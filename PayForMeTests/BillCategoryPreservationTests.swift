//
//  BillCategoryPreservationTests.swift
//  PayForMeTests
//
//  Regression tests for a data-loss bug: editing any bill in a Cospend project
//  reset its category and payment mode on the server.
//
//  Two things went wrong together. `Bill` never decoded `categoryid` or
//  `paymentmode`, so the values were lost the moment a bill arrived; and
//  `paramsFor(_:)` hardcoded `"categoryid": "0"` and `"paymentmode": "n"` into
//  every PUT. Changing a bill's amount therefore also silently moved it to
//  "uncategorised" — and the category statistics in Cospend degraded a little
//  more with each edit.
//

import XCTest
@testable import PayForMe

final class BillCategoryPreservationTests: XCTestCase {

    private let member = Person(id: 1, weight: 1, name: "Alice", activated: true)
    private var testDate: Date { DateFormatter.cospend.date(from: "2026-05-14")! }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.cospend)
        return decoder
    }

    // MARK: Decoding

    func testCategoryAndPaymentModeAreDecoded() throws {
        let json = """
        [{"id":42,"amount":12.5,"what":"Grocery run","date":"2026-05-14","payer_id":1,
          "owers":[],"repeat":"n","categoryid":-1,"paymentmode":"c"}]
        """.data(using: .utf8)!

        let bills = try decoder().decode([Bill].self, from: json)
        XCTAssertEqual(bills.first?.categoryid, -1)
        XCTAssertEqual(bills.first?.paymentmode, "c")
    }

    /// iHateMoney never sends either field, and older Cospend payloads may not
    /// either — their absence must not fail the whole response.
    func testPayloadWithoutTheFieldsStillDecodes() throws {
        let json = """
        [{"id":7,"amount":12.5,"what":"Tea","date":"2026-05-04","payer_id":1,
          "owers":[],"repeat":"n"}]
        """.data(using: .utf8)!

        let bills = try decoder().decode([Bill].self, from: json)
        XCTAssertEqual(bills.count, 1)
        XCTAssertNil(bills.first?.categoryid)
        XCTAssertNil(bills.first?.paymentmode)
    }

    // MARK: Request parameters

    func testParamsPreserveCategoryAndPaymentMode() {
        let bill = Bill(id: 9, amount: 5, what: "Rent", date: testDate, payer_id: 1,
                        owers: [member], repeat: "n", lastchanged: nil,
                        categoryid: -3, paymentmode: "c")

        let params = bill.paramsFor(.cospend)
        XCTAssertEqual(params["categoryid"] as? String, "-3",
                       "editing a bill must not move it to 'uncategorised'")
        XCTAssertEqual(params["paymentmode"] as? String, "c")
    }

    /// A brand new bill has neither, and the server expects the documented
    /// defaults rather than an empty value.
    func testParamsFallBackToCospendDefaults() {
        let bill = Bill(id: -1, amount: 5, what: "New", date: testDate, payer_id: 1,
                        owers: [member], repeat: "n")

        let params = bill.paramsFor(.cospend)
        XCTAssertEqual(params["categoryid"] as? String, "0")
        XCTAssertEqual(params["paymentmode"] as? String, "n")
    }

    /// iHateMoney has no such concepts; sending them would be noise.
    func testIHateMoneyParamsCarryNeitherField() {
        let bill = Bill(id: 9, amount: 5, what: "Rent", date: testDate, payer_id: 1,
                        owers: [member], repeat: "n", lastchanged: nil,
                        categoryid: -3, paymentmode: "c")

        let params = bill.paramsFor(.iHateMoney)
        XCTAssertNil(params["categoryid"])
        XCTAssertNil(params["paymentmode"])
    }

    // MARK: The edit path

    /// The regression itself: load a categorised bill, edit it through the
    /// detail view model, and the outgoing parameters must still carry the
    /// original category.
    func testEditingABillKeepsItsCategory() throws {
        let json = """
        [{"id":42,"amount":12.5,"what":"Grocery run","date":"2026-05-14","payer_id":1,
          "owers":[],"repeat":"n","categoryid":-1,"paymentmode":"c"}]
        """.data(using: .utf8)!
        let original = try decoder().decode([Bill].self, from: json)[0]

        let viewModel = BillDetailViewModel(currentBill: original)
        let project = Project(name: "test", password: "pw", token: "tok",
                              backend: .cospend, url: URL(string: "https://test.de")!,
                              projectId: "test")
        project.members = [member.id: member]
        viewModel.currentProject = project
        viewModel.selectedPayer = member.id
        viewModel.topic = "Grocery run"
        // The user changes only the amount.
        viewModel.amount = "18.00"
        viewModel.povm.members = [member]
        viewModel.povm.isOwing = [true]

        let edited = try XCTUnwrap(viewModel.createBill())
        XCTAssertEqual(edited.amount, 18.0, accuracy: 0.001, "the edit itself still applies")
        XCTAssertEqual(edited.categoryid, -1, "the category must survive the edit")
        XCTAssertEqual(edited.paymentmode, "c", "the payment mode must survive the edit")
        XCTAssertEqual(edited.paramsFor(.cospend)["categoryid"] as? String, "-1")
    }
}
