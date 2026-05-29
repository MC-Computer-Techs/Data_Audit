import SwiftUI
import AppKit

@MainActor
struct PDFGenerator {
    static func generatePDF(from pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String]), title: String, to url: URL) {
        
        let pdfView = VStack {
            Text(title)
                .font(.largeTitle)
                .bold()
                .padding()
            TopSheetView(pack: pack, isExporting: true)
                .frame(width: 800)
        }
        .padding()
        .background(Color.white)
        .fixedSize(horizontal: false, vertical: true)
        
        let renderer = ImageRenderer(content: pdfView)
        
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
    }
}
