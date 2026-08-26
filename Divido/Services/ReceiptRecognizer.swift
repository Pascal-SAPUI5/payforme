//
//  ReceiptRecognizer.swift
//  Divido
//
//  Liest einen fotografierten Kassenbon und macht daraus eine Bonstruktur.
//
//  Der Weg ist bewusst zweistufig: Apples Vision liest den Text zeichengenau
//  aus dem Bild, und erst dieser Text geht an das Sprachmodell. Ein Bild direkt
//  an ein multimodales Modell zu geben klingt eleganter, ist bei Kassenbons aber
//  schlechter — Modelle raten bei Ziffern, waehrend eine Texterkennung gedruckte
//  Spalten zuverlaessig liest.
//
//  Alles hier braucht ein Geraet und laesst sich in der Pipeline nicht pruefen.
//  Deshalb steht hier so wenig wie moeglich: Das Zusammensetzen der Zeilen liegt
//  in TextLineGrouper, das Auswerten der Modellantwort in ReceiptParser, und
//  beide haben Tests.
//

import Foundation
import FoundationModels
import ImageIO
import UIKit
import Vision

enum ReceiptRecognizerError: LocalizedError {
    case noImageData
    case noTextFound
    case intelligenceUnavailable(String)
    case unreadableAnswer

    var errorDescription: String? {
        switch self {
        case .noImageData:
            return "Das Foto konnte nicht gelesen werden."
        case .noTextFound:
            return "Auf dem Foto ist kein Text zu erkennen. Halte den Bon flach und sorge für Licht."
        case .intelligenceUnavailable(let reason):
            return reason
        case .unreadableAnswer:
            return "Der Bon konnte nicht ausgewertet werden. Trage die Rechnung von Hand ein."
        }
    }
}

enum ReceiptRecognizer {

    /// Mehr Zeilen als das nimmt kein Bon ein, und mehr passt auch nicht
    /// verlaesslich in das Kontextfenster des Modells.
    static let maximumLines = 120

    /// Der ganze Weg vom Foto zur Bonstruktur.
    ///
    /// Der Endbetrag bekommt eine zweite Quelle. Ein Sprachmodell laesst sich
    /// nicht pruefen, und der Endbetrag ist der wichtigste Wert der ganzen
    /// Rechnung — er darf nicht allein daran haengen. ReceiptTotals sucht ihn
    /// deterministisch im erkannten Text, und die Summe der Positionen
    /// entscheidet, wer recht hat.
    static func recognize(_ image: UIImage, now: Date = Date()) async throws -> ScannedReceipt {
        let lines = try recognizeLines(in: image)
        guard !lines.isEmpty else { throw ReceiptRecognizerError.noTextFound }

        var receipt = try await interpret(lines.joined(separator: "\n"), now: now)
        receipt.total = ReceiptTotals.preferred(model: receipt.total,
                                                fromText: ReceiptTotals.total(in: lines),
                                                sumOfItems: receipt.sumOfItems)
        return receipt
    }

    // MARK: - Schritt 1: Text aus dem Bild

    /// Liest den Text und gibt ihn zeilenweise zurueck, von oben nach unten.
    ///
    /// Die Sprachkorrektur ist abgeschaltet. Sie ist fuer Fliesstext gedacht und
    /// verschlimmbessert auf einem Bon genau das, worauf es ankommt: Artikel-
    /// kuerzel und Betraege.
    static func recognizeLines(in image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw ReceiptRecognizerError.noImageData
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage,
                                            orientation: orientation(of: image),
                                            options: [:])
        try handler.perform([request])

        // Die Umwandlung ist je nach SDK ueberfluessig, aber nie falsch: Vision
        // typisiert `results` nicht in allen Fassungen gleich.
        let observations = (request.results ?? []).compactMap { $0 as? VNRecognizedTextObservation }

        let fragments: [TextFragment] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return TextFragment(text: candidate.string,
                                midY: Double(box.midY),
                                minX: Double(box.minX),
                                height: Double(box.height))
        }

        return Array(TextLineGrouper.lines(from: fragments).prefix(maximumLines))
    }

    // MARK: - Schritt 2: Text zur Bonstruktur

    /// Legt dem Modell den erkannten Text vor und wertet seine Antwort aus.
    static func interpret(_ text: String, now: Date = Date()) async throws -> ScannedReceipt {
        try checkAvailability()

        let session = LanguageModelSession()
        let response = try await session.respond(to: "\(ReceiptParser.prompt)\n\n\(text)")

        guard let receipt = ReceiptParser.parse(response.content, now: now) else {
            throw ReceiptRecognizerError.unreadableAnswer
        }
        return receipt
    }

    /// Prueft, ob das Modell auf diesem Geraet ueberhaupt laeuft.
    ///
    /// Ohne diese Pruefung scheitert erst der Aufruf, und der Nutzer sieht einen
    /// Fehler, gegen den er nichts tun kann. Die drei Gruende hier sind
    /// unterschiedlich behebbar, deshalb bekommt jeder seinen eigenen Satz.
    static func checkAvailability() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(let reason):
            throw ReceiptRecognizerError.intelligenceUnavailable(message(for: reason))
        @unknown default:
            throw ReceiptRecognizerError.intelligenceUnavailable(
                "Die Bonerkennung steht auf diesem Gerät nicht zur Verfügung."
            )
        }
    }

    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Dieses Gerät unterstützt die Bonerkennung nicht. Trage die Rechnung von Hand ein."
        case .appleIntelligenceNotEnabled:
            return "Schalte Apple Intelligence in den Einstellungen ein, dann liest Divido Bons für dich."
        case .modelNotReady:
            return "Das Modell wird noch geladen. Versuche es in ein paar Minuten erneut."
        @unknown default:
            return "Die Bonerkennung steht gerade nicht zur Verfügung."
        }
    }

    // MARK: - Intern

    /// Ein Foto aus der Kamera kommt fast nie aufrecht an. Vision liest die
    /// Ausrichtung nicht selbst aus, sie muss mitgegeben werden, sonst steht der
    /// Bon quer und die Zeilen laufen senkrecht.
    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
