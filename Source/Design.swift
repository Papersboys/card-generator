import SwiftUI

extension Color {
    static let linkInk=Color(red:0.055,green:0.15,blue:0.20)
    static let linkTeal=Color(nsColor:NSColor(name:nil) {appearance in
        appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(srgbRed:0.48,green:0.94,blue:0.81,alpha:1) : NSColor(srgbRed:0.04,green:0.39,blue:0.40,alpha:1)
    })
    static let linkMint=Color(red:0.48,green:0.94,blue:0.81)
}
struct LinkMark:View {
    var body:some View {
        ZStack {
            RoundedRectangle(cornerRadius:12).fill(Color.linkInk.gradient)
            RoundedRectangle(cornerRadius:4).stroke(Color.linkMint.opacity(0.6),lineWidth:2).frame(width:21,height:15).offset(x:-4,y:-4)
            RoundedRectangle(cornerRadius:4).fill(Color.linkMint).frame(width:21,height:15).offset(x:4,y:4)
            Capsule().fill(Color.linkInk).frame(width:10,height:2).offset(x:4,y:3)
        }.accessibilityHidden(true)
    }
}
struct PanelSurface:ViewModifier {
    func body(content:Content)->some View {
        content.padding(16).background(Color(nsColor:.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.primary.opacity(0.06)))
    }
}
extension View {func panelSurface()->some View {modifier(PanelSurface())}}

func menuBarMark()->NSImage {
    let image=NSImage(size:NSSize(width:19,height:19),flipped:false) {_ in
        NSColor.black.setStroke()
        let back=NSBezierPath(roundedRect:NSRect(x:2,y:7,width:12,height:9),xRadius:2,yRadius:2)
        back.lineWidth=1.4;back.stroke()
        let front=NSBezierPath(roundedRect:NSRect(x:6,y:3,width:12,height:9),xRadius:2,yRadius:2)
        NSColor.black.setFill();front.fill()
        return true
    }
    image.isTemplate=true;image.accessibilityDescription="Link Card"
    return image
}
