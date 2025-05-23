import SwiftUI
import AVFoundation
import UIKit
import Inject

struct ContentView: View {
    @ObserveInjection var inject
    @State private var showingNewView = false
    var body: some View {
        ZStack {
            Button(action: {
                // Action for the button
                print("Camera button tapped")
                self.showingNewView = true
            }) {
                Image(systemName: "camera.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 10)
            }
        }
        .sheet(isPresented: $showingNewView) {
            LiveCameraView()
        }
        .enableInjection()
    }
}
