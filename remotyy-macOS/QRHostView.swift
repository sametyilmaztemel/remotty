import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRHostView: View {
    @ObservedObject var host: HostManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Share Access")
                .font(.headline)
            
            if let qrImage = generateQR() {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 100))
                    .foregroundColor(.secondary)
            }
            
            Text("Scan this QR code with your phone")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(host.hostName.isEmpty ? ProcessInfo.processInfo.hostName : host.hostName)
                .font(.caption.monospaced())
                .foregroundColor(.accentColor)
            
            Text(host.signalURL)
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding()
        .frame(width: 320, height: 400)
    }
    
    private func generateQR() -> NSImage? {
        let data = "remotyy://connect/\(host.signalURL)?host=\(host.hostName)".data(using: .utf8)
        
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = ciImage.transformed(by: transform)
        
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
