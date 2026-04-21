import SwiftUI
import PhotosUI
import AVFoundation

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
    @State private var showPermissionAlert = false
    @State private var showOCRErrorAlert = false
    // Stored so it can be invalidated when the view disappears mid-processing.
    @State private var processingTimer: Timer?

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
            // fullScreenCover is required for UIImagePickerController — presenting it
            // inside a .sheet causes layout and dismissal issues on iOS 16+.
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(
                    onCapture: { image in
                        showCamera = false
                        Task { await processImage(image) }
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data  = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        showOCRErrorAlert = true
                        return
                    }
                    await processImage(image)
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                ScanPreviewView(tasks: $parsedTasks, onDismiss: { dismiss() })
            }
            // Camera permission denied
            .alert("Camera Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Oryn needs camera access to scan your task lists. Please enable it in Settings > Privacy & Security > Camera.")
            }
            // OCR returned no tasks
            .alert("No Tasks Detected", isPresented: $showOCRErrorAlert) {
                Button("Try Again", role: .cancel) {}
            } message: {
                Text("Oryn couldn't find any tasks in that image. Try better lighting, hold the camera steady, and make sure the text fills most of the frame.")
            }
            .onDisappear {
                processingTimer?.invalidate()
                processingTimer = nil
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
                // Camera button — checks permission before presenting
                Button {
                    HapticManager.shared.medium()
                    requestCameraAndPresent()
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
                    .onAppear { startDotsAnimation() }
            }
        }
    }

    // MARK: - Camera permission

    private func requestCameraAndPresent() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true } else { showPermissionAlert = true }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            showCamera = true
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
            HapticManager.shared.error()
            showOCRErrorAlert = true
            return
        }

        parsedTasks = tasks
        HapticManager.shared.success()
        showPreview = true
    }

    // Stores a reference so we can invalidate on demand rather than waiting
    // for the next 0.5 s tick after isProcessing flips to false.
    private func startDotsAnimation() {
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] t in
            guard isProcessing else { t.invalidate(); return }
            processingDots = (processingDots + 1) % 3
        }
    }
}

// MARK: - Camera picker wrapper

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Do NOT call picker.dismiss here — SwiftUI owns the presentation and
            // setting showCamera = false (via onCapture/onCancel) triggers teardown.
            // Calling dismiss a second time causes a double-dismiss crash.
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
