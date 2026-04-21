import SwiftUI
import PhotosUI

/// Entry point for the scan flow. Lets the user pick a source (camera or library),
/// runs OCR + parsing, then hands off to ScanPreviewView.
struct ImageScannerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var parsedTasks: [ParsedTask] = []
    @State private var showPreview = false
    @State private var processingDots = 0

    private let ocr    = OCRService()
    private let parser = TaskParserService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.orynBackground.ignoresSafeArea()

                if isProcessing {
                    processingOverlay
                } else {
                    sourcePickerContent
                }
            }
            .navigationTitle("Scan List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                    .foregroundColor(.orynTextSecondary)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    capturedImage = image
                    showCamera = false
                    Task { await processImage(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data  = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await processImage(image)
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                ScanPreviewView(tasks: $parsedTasks, onDismiss: { dismiss() })
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Source Picker

    private var sourcePickerContent: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.orynAccent)
                .padding(.bottom, Spacing.sm)

            VStack(spacing: Spacing.xs) {
                Text("Import a To-Do List")
                    .orynFont(.orynTitle2)
                Text("Take a photo or choose an image of\nyour handwritten tasks.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.md) {
                // Camera button
                Button {
                    HapticManager.shared.medium()
                    showCamera = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "camera.fill")
                        Text("Take a Photo")
                            .orynFont(.orynButton, color: .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.orynAccent))
                }
                .buttonStyle(.plain)

                // Photo library picker
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.orynAccent)
                        Text("Choose from Library")
                            .orynFont(.orynButton, color: .orynAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(Color.orynAccent, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Processing overlay

    private var processingOverlay: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.orynAccentSoft)
                    .frame(width: 88, height: 88)
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.orynAccent)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: Spacing.xs) {
                Text("Reading your list")
                    .orynFont(.orynHeadline)
                Text("Detecting tasks" + String(repeating: ".", count: processingDots + 1))
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .animation(.orynSmooth, value: processingDots)
                    .onAppear { animateDots() }
            }
        }
    }

    // MARK: - Processing pipeline

    @MainActor
    private func processImage(_ image: UIImage) async {
        withAnimation(.orynSmooth) { isProcessing = true }
        HapticManager.shared.medium()

        let lines = await ocr.extractLines(from: image)
        let tasks = parser.parse(lines: lines)

        withAnimation(.orynSmooth) { isProcessing = false }

        if tasks.isEmpty {
            // Nothing recognised — bounce back to picker
            HapticManager.shared.error()
            return
        }

        parsedTasks = tasks
        HapticManager.shared.success()
        showPreview = true
    }

    private func animateDots() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
            guard isProcessing else { t.invalidate(); return }
            processingDots = (processingDots + 1) % 3
        }
    }
}

// MARK: - Camera picker wrapper

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
