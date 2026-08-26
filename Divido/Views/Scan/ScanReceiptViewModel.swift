//
//  ScanReceiptViewModel.swift
//  Divido
//
//  Haelt den Zustand des Bonscans und die Zuordnung der Positionen.
//
//  Die Erkennung wird hereingereicht statt fest verdrahtet. Das ist nicht
//  Zeremonie: ReceiptRecognizer braucht Kamera und Sprachmodell und laeuft
//  nirgends ausser auf einem Geraet. So bleibt der Zustandsautomat und die
//  ganze Zuordnungslogik pruefbar, und nur das Lesen des Fotos nicht.
//

import Foundation
import UIKit

@MainActor
final class ScanReceiptViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recognizing
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var receipt: ScannedReceipt?

    let participants: [Person]
    private let recognizer: (UIImage) async throws -> ScannedReceipt

    init(participants: [Person],
         recognizer: @escaping (UIImage) async throws -> ScannedReceipt = {
             try await ReceiptRecognizer.recognize($0)
         }) {
        self.participants = participants.filter(\.activated)
        self.recognizer = recognizer
    }

    // MARK: - Erkennung

    func scan(_ image: UIImage) async {
        phase = .recognizing
        do {
            let read = try await recognizer(image)
            receipt = read
            phase = read.items.isEmpty && read.total == nil ? .failed(unreadableMessage) : .ready
        } catch {
            receipt = nil
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        receipt = nil
        phase = .idle
    }

    // MARK: - Zuordnung

    func isAssigned(_ person: Person, to item: ScannedItem) -> Bool {
        item.assignedTo.contains(person.id)
    }

    /// Antippen schaltet um. Bleibt niemand uebrig, gehoert die Position wieder
    /// allen — das ist der haeufigste Zustand und braucht keinen eigenen Griff.
    func toggle(_ person: Person, on item: ScannedItem) {
        guard let index = receipt?.items.firstIndex(where: { $0.id == item.id }) else { return }
        if receipt?.items[index].assignedTo.contains(person.id) == true {
            receipt?.items[index].assignedTo.remove(person.id)
        } else {
            receipt?.items[index].assignedTo.insert(person.id)
        }
    }

    /// Eine Zeile, die die Texterkennung erfunden hat, muss weg koennen.
    func remove(_ item: ScannedItem) {
        receipt?.items.removeAll { $0.id == item.id }
    }

    // MARK: - Endbetrag

    /// Der Endbetrag, wie ihn die Erkennung gelesen hat.
    var total: Double? { receipt?.total }

    /// Uebernimmt einen von Hand eingetippten Endbetrag.
    ///
    /// Ohne diesen Weg haengt der Nutzer fest, sobald die Erkennung den Betrag
    /// verfehlt — und dass sie das gelegentlich tut, ist keine Frage, sondern
    /// eine Gewissheit. Eine leere Eingabe loescht den Betrag, dann gilt die
    /// Summe der Positionen.
    func updateTotal(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        receipt?.total = trimmed.isEmpty ? nil : ReceiptTotals.amount(from: trimmed)
    }

    /// Ob eine Position allen gehoert. Eine leere Zuordnung heisst geteilt.
    func isShared(_ item: ScannedItem) -> Bool {
        item.assignedTo.isDisjoint(with: Set(participants.map(\.id)))
    }

    // MARK: - Ergebnis

    var drafts: [BillDraft] {
        guard let receipt else { return [] }
        return ReceiptSplitter.drafts(for: receipt, participants: participants.map(\.id))
    }

    /// Was der Bon ausweist, aber keine Position erklaert.
    var unaccounted: Double {
        guard let receipt else { return 0 }
        return ReceiptSplitter.unaccounted(in: receipt)
    }

    var canCreateBills: Bool { !drafts.isEmpty }

    // MARK: - Intern

    private var unreadableMessage: String {
        NSLocalizedString("scan_failed_message", comment: "")
    }
}
