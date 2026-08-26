//
//  ScanReceiptView.swift
//  Divido
//
//  Bon fotografieren, Positionen zuordnen, Rechnungen anlegen.
//
//  Die Zuordnung passiert direkt an der Position: Unter jedem Artikel steht die
//  Runde als Avatare, Antippen schaltet um. Kein Blatt, kein Menue, kein
//  Navigieren. Wer nichts antippt, teilt — das ist der haeufigste Fall und
//  kostet deshalb keinen Handgriff.
//

import PhotosUI
import SwiftUI

struct ScanReceiptView: View {
    @Environment(\.pfmTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: ScanReceiptViewModel
    @State private var showsCamera = false
    @State private var pickedPhoto: PhotosPickerItem?

    private let currency: String?
    private let onCreate: ([BillDraft], Date) -> Void

    init(participants: [Person],
         currency: String?,
         recognizer: ((UIImage) async throws -> ScannedReceipt)? = nil,
         onCreate: @escaping ([BillDraft], Date) -> Void) {
        self.currency = currency
        self.onCreate = onCreate
        if let recognizer {
            _model = StateObject(wrappedValue: ScanReceiptViewModel(participants: participants,
                                                                    recognizer: recognizer))
        } else {
            _model = StateObject(wrappedValue: ScanReceiptViewModel(participants: participants))
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                PFMBackground()
                content
            }
            .navigationBarTitle(Text("scan_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Text("Cancel")
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showsCamera) {
            ReceiptCamera(onScan: { image in
                showsCamera = false
                Task { await model.scan(image) }
            }, onCancel: {
                showsCamera = false
            })
            .ignoresSafeArea()
        }
        .onChange(of: pickedPhoto) { item in
            guard let item else { return }
            Task { await loadAndScan(item) }
        }
    }

    // MARK: - Zustände

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            start
        case .recognizing:
            recognizing
        case .ready:
            result
        case .failed(let message):
            failure(message)
        }
    }

    private var start: some View {
        VStack(spacing: 20) {
            Spacer()
            PFMEmptyState(systemImage: "doc.text.viewfinder",
                          titleKey: "scan_empty_title",
                          messageKey: "scan_empty_message")
            VStack(spacing: 12) {
                Button(action: { showsCamera = true }) {
                    Label("scan_start_camera", systemImage: "camera.fill")
                }
                .buttonStyle(PFMPrimaryButtonStyle())

                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Label("scan_choose_photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PFMSecondaryButtonStyle())
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var recognizing: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("scan_recognizing")
                .font(.subheadline)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            PFMEmptyState(systemImage: "exclamationmark.triangle",
                          titleKey: "scan_failed_title")
            Text(message)
                .font(.subheadline)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: model.reset) {
                Text("scan_retry")
            }
            .buttonStyle(PFMPrimaryButtonStyle())
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    // MARK: - Ergebnis

    private var result: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: theme.metrics.sectionSpacing) {
                    header
                    items
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let retailer = model.receipt?.retailer {
                    PFMChip(text: retailer, systemImage: "storefront")
                }
                Spacer()
                if let date = model.receipt?.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
            }

            Text(MoneyFormatter.string(model.receipt?.effectiveTotal ?? 0, currency: currency))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(theme.palette.textPrimary)
                .pfmTabularNumbers()

            if abs(model.unaccounted) > 0.005 {
                // Der Bon weist mehr aus, als die Positionen erklaeren. Fast
                // immer eine verschluckte Zeile. Sichtbar machen statt still
                // dazurechnen.
                Label {
                    Text("scan_unaccounted \(MoneyFormatter.string(model.unaccounted, currency: currency))")
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                }
                .font(.caption.weight(.medium))
                .foregroundColor(theme.palette.negative)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pfmCard()
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: 8) {
            PFMSectionHeader(titleKey: "scan_items", subtitleKey: "scan_assign_hint")
            ForEach(model.receipt?.items ?? []) { item in
                itemRow(item)
            }
        }
    }

    private func itemRow(_ item: ScannedItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.palette.textPrimary)
                if item.quantity > 1 {
                    PFMChip(text: "×\(item.quantity)", tint: theme.palette.textSecondary)
                }
                Spacer(minLength: 8)
                Text(MoneyFormatter.string(item.price * Double(item.quantity), currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.palette.textPrimary)
                    .pfmTabularNumbers()
            }

            HStack(spacing: 8) {
                ForEach(model.participants) { person in
                    Button(action: { model.toggle(person, on: item) }) {
                        PFMAvatar(person: person, size: 30)
                            .opacity(model.isAssigned(person, to: item) ? 1 : 0.28)
                            .overlay(
                                Circle()
                                    .strokeBorder(theme.palette.accent,
                                                  lineWidth: model.isAssigned(person, to: item) ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(person.name)
                }
                Spacer()
                if model.isShared(item) {
                    PFMChip(text: NSLocalizedString("scan_shared", comment: ""),
                            systemImage: "person.2.fill")
                }
            }
        }
        .pfmCardRow()
        .contextMenu {
            Button(action: { model.remove(item) }) {
                Label("scan_remove_item", systemImage: "trash")
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("scan_bills_preview \(model.drafts.count)")
                .font(.caption)
                .foregroundColor(theme.palette.textSecondary)
            Button(action: { onCreate(model.drafts, model.receipt?.date ?? Date()); dismiss() }) {
                Text("scan_create_bills")
            }
            .buttonStyle(PFMPrimaryButtonStyle())
            .disabled(!model.canCreateBills)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(theme.palette.backgroundSecondary.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Intern

    private func loadAndScan(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        pickedPhoto = nil
        await model.scan(image)
    }
}
