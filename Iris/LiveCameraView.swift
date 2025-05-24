import SwiftUI
import AVFoundation

struct LiveCameraView: View {
    @Environment(\.dismiss) var dismiss
    @State private var capturedImage: UIImage?
    @StateObject private var cameraCoordinator = CameraCoordinator()
    
    // Modal state management
    @State private var showModal = false
    @State private var modalContent = ""
    @State private var isLoading = false
    @State private var currentTask: Task<Void, Never>?
    @AccessibilityFocusState private var isModalFocused: Bool
    @AccessibilityFocusState private var isTakePhotoButtonFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Always show camera preview in background
            CameraPreview(coordinator: cameraCoordinator)
                .edgesIgnoringSafeArea(.all)
            
            // Show captured image as floating thumbnail overlay
            if let image = capturedImage {
                VStack {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            .padding(.trailing, 20)
                            .padding(.top, 60) // Safe area padding
                            .accessibilityLabel(NSLocalizedString("captured_image", comment: "Accessibility label for captured image"))
                    }
                    Spacer()
                }
            }
            
            // Show modal as floating overlay
            if showModal {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView(NSLocalizedString("processing", comment: "Loading message"))
                                    .font(.headline)
                                    .accessibilityFocused($isModalFocused)
                                    .onAppear {
                                        // Focus VoiceOver on the modal content
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isModalFocused = false
                                        }
                                    }
                            } else {
                                Text(modalContent)
                                    .font(.headline)
                                    .multilineTextAlignment(.leading)
                                    .accessibilityLabel(modalContent)
                                    .accessibilityFocused($isModalFocused)
                            }
                        }
                        // .accessibilityAddTraits(.updatesFrequently)
                        .padding(20)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                        .frame(maxWidth: 300)
                        Spacer()
                    }
                    Spacer()
                }
                .onAppear {
                    // Focus VoiceOver on the modal content
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isModalFocused = true
                    }
                }
            }

            HStack {
                Button(action: {
                    cancelCurrentProcess()
                    cameraCoordinator.capturePhoto()
                }) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .accessibilityLabel(NSLocalizedString("take_photo", comment: "Take photo button"))
                .accessibilityFocused($isTakePhotoButtonFocused)

                if capturedImage != nil {
                    Button(action: {
                        cancelCurrentProcess()
                    }) {
                        Image(systemName: "xmark")
                            .font(.largeTitle)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(NSLocalizedString("cancel", comment: "Cancel button"))
                }
            }
            .padding(.bottom, 30)
        }
        .onReceive(cameraCoordinator.$capturedImage) { image in
            guard let image = image else { return }
            processCapturedImage(image)
        }
        .onAppear {
            // Focus on the take photo button when the view first loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTakePhotoButtonFocused = true
            }
        }
    }

    private func processCapturedImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to get JPEG data from image")
            return
        }

        print("Original image byte size: \(imageData.count) bytes")
        print("Original image dimensions: \(image.size.width) x \(image.size.height) pixels")

        // Resize the image
        let scaleFactor: CGFloat = 0.5
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let resizedImageData = resizedImage.jpegData(compressionQuality: 0.5) else {
            print("Failed to get JPEG data from resized image")
            return
        }
        let imageBase64 = resizedImageData.base64EncodedString()

        print("Resized image byte size: \(resizedImageData.count) bytes")
        print("Resized image dimensions: \(resizedImage.size.width) x \(resizedImage.size.height) pixels")

        // Update the UI with the resized image and show loading modal
        DispatchQueue.main.async {
            self.capturedImage = resizedImage
            self.showModal = true
            self.isLoading = true
            self.modalContent = ""
        }

        // Start the image processing task
        currentTask = Task {
            do {
                let description = try await GemmaService.shared.processImage(imageBase64)
                print("description: \(description)")
                
                // Update modal with description
                await MainActor.run {
                    self.modalContent = description
                    self.isLoading = false
                    self.isModalFocused = false
                    // Refocus on the updated content
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isModalFocused = true
                    }
                }
            } catch {
                print("Error processing image: \(error)")
                await MainActor.run {
                    self.modalContent = NSLocalizedString("image_processing_error", comment: "Error message when image processing fails")
                    self.isLoading = false
                    self.isModalFocused = false
                    // Refocus on the error message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isModalFocused = true
                    }
                }
            }
        }
    }

    private func cancelCurrentProcess() {
        // Cancel ongoing API call if any
        currentTask?.cancel()
        currentTask = nil
        
        // Cancel any ongoing request in GemmaService
        GemmaService.shared.cancelCurrentRequest()
        
        // Reset all state to fresh state
        capturedImage = nil
        showModal = false
        modalContent = ""
        isLoading = false
        isModalFocused = false
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var coordinator: CameraCoordinator

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        #if targetEnvironment(simulator)
        view.backgroundColor = .black
        let label = UILabel()
        label.text = NSLocalizedString("camera_not_available_simulator", comment: "Simulator camera message")
        label.textColor = .white
        label.textAlignment = .center
        label.frame = view.bounds
        view.addSubview(label)
        #else
        guard let captureSession = coordinator.captureSession else {
            view.backgroundColor = .black
            let label = UILabel()
            label.text = NSLocalizedString("capture_session_not_initialized", comment: "Capture session error message")
            label.textColor = .white
            label.textAlignment = .center
            label.frame = view.bounds
            view.addSubview(label)
            return view
        }

        // Try to use ultra-wide camera (0.5x) first, fallback to wide-angle if not available
        let videoDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) ??
                         AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        guard let device = videoDevice,
              let videoInput = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(videoInput) else {
            view.backgroundColor = .black
            let label = UILabel()
            label.text = NSLocalizedString("failed_to_access_camera", comment: "Camera access error message")
            label.textColor = .white
            label.textAlignment = .center
            label.frame = view.bounds
            view.addSubview(label)
            return view
        }
        captureSession.addInput(videoInput)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        if captureSession.canAddOutput(coordinator.photoOutput) {
            captureSession.addOutput(coordinator.photoOutput)
        }

        DispatchQueue.global(qos: .userInitiated).async {
             captureSession.startRunning()
        }
        #endif

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class CameraCoordinator: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    @Published var capturedImage: UIImage?
    var captureSession: AVCaptureSession?
    let photoOutput = AVCapturePhotoOutput()

    override init() {
        super.init()
        self.captureSession = AVCaptureSession()
        self.captureSession?.sessionPreset = .photo
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            print("Error capturing photo: \\(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("Could not get image data.")
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = UIImage(data: imageData)
        }
    }
} 
