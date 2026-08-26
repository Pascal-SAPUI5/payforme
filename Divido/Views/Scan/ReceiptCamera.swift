//
//  ReceiptCamera.swift
//  Divido
//
//  Der Weg vom Bon zum Bild.
//
//  Bewusst der Dokumentenscanner aus VisionKit und nicht die gewoehnliche
//  Kamera. Er findet die Kanten des Bons, schneidet frei und rechnet die
//  Perspektive gerade. Genau das entscheidet, ob die Texterkennung danach
//  saubere Zeilen sieht oder ein schraeges Trapez.
//

import SwiftUI
import VisionKit

struct ReceiptCamera: UIViewControllerRepresentable {
    var onScan: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: ReceiptCamera

        init(_ parent: ReceiptCamera) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            // Ein Bon ist eine Seite. Wer mehrere aufnimmt, meint die erste.
            guard scan.pageCount > 0 else {
                parent.onCancel()
                return
            }
            parent.onScan(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
