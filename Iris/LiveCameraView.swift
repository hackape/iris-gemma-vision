import SwiftUI
import AVFoundation

struct LiveCameraView: View {
    @Environment(\.dismiss) var dismiss
    @State private var capturedImage: UIImage?
    @StateObject private var cameraCoordinator = CameraCoordinator()
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack(alignment: .bottom) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
            } else {
                CameraPreview(coordinator: cameraCoordinator)
                    .edgesIgnoringSafeArea(.all)
            }

            HStack {
                if capturedImage != nil {
                    Button(action: {
                        capturedImage = nil  // Reset to continue capturing
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.largeTitle)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                
                Button(action: {
                    cameraCoordinator.capturePhoto()
                }) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 30)
        }
        .onReceive(cameraCoordinator.$capturedImage) { image in
            guard let image = image else { return }
            processCapturedImage(image)
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

        // Update the UI with the resized image
        DispatchQueue.main.async {
            self.capturedImage = resizedImage
        }

        Task {
            do {
                let description = try await GemmaService.shared.processImage(imageBase64)
                print("description: \(description)")
                speakDescription(description)
            } catch {
                print("Error processing image: \(error)")
                speakDescription("Sorry, I could not describe the image.")
            }
        }
    }

    private func speakDescription(_ text: String) {
        print("speaking: \(text)")
        let utterance = AVSpeechUtterance(string: text)
        
        // Attempt to use the desired voice, with a fallback
        if let voice = AVSpeechSynthesisVoice(language: "zh-CN") {
            utterance.voice = voice
        } else {
            print("Chinese voice (zh-CN) not available, using default.")
            // Optionally set to another preferred voice or let the system use its default
             utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        }
        
        // Use the stored synthesizer instance
        synthesizer.speak(utterance)
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var coordinator: CameraCoordinator

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        #if targetEnvironment(simulator)
        view.backgroundColor = .black
        let label = UILabel()
        label.text = "Camera not available on simulator"
        label.textColor = .white
        label.textAlignment = .center
        label.frame = view.bounds
        view.addSubview(label)
        #else
        guard let captureSession = coordinator.captureSession else {
            view.backgroundColor = .black
            let label = UILabel()
            label.text = "Capture session not initialized"
            label.textColor = .white
            label.textAlignment = .center
            label.frame = view.bounds
            view.addSubview(label)
            return view
        }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            view.backgroundColor = .black
            let label = UILabel()
            label.text = "Failed to access camera"
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
        if let error = error {
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
