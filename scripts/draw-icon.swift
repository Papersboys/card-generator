import AppKit
// Native vector artwork: two linked payment cards, built for small-size legibility.
let size=1024
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat)->NSColor {NSColor(srgbRed:r,green:g,blue:b,alpha:1)}
let ink=color(0.035,0.13,0.18),mint=color(0.48,0.94,0.81)
let tile=NSBezierPath(roundedRect:NSRect(x:64,y:64,width:896,height:896),xRadius:202,yRadius:202)
NSGradient(starting:color(0.10,0.29,0.34),ending:ink)!.draw(in:tile,angle:-65)
NSColor.white.withAlphaComponent(0.15).setStroke();tile.lineWidth=3;tile.stroke()
let back=NSBezierPath(roundedRect:NSRect(x:229,y:421,width:500,height:318),xRadius:57,yRadius:57)
mint.withAlphaComponent(0.12).setFill();back.fill();mint.withAlphaComponent(0.65).setStroke();back.lineWidth=13;back.stroke()
let front=NSBezierPath(roundedRect:NSRect(x:298,y:288,width:500,height:318),xRadius:57,yRadius:57)
NSGradient(starting:color(0.70,1,0.89),ending:mint)!.draw(in:front,angle:-60)
let stripe=NSBezierPath(roundedRect:NSRect(x:354,y:481,width:170,height:20),xRadius:10,yRadius:10);ink.setFill();stripe.fill()
let line=NSBezierPath(roundedRect:NSRect(x:354,y:350,width:212,height:16),xRadius:8,yRadius:8);ink.withAlphaComponent(0.65).setFill();line.fill()
let dot=NSBezierPath(ovalIn:NSRect(x:704,y:343,width:32,height:32));ink.setFill();dot.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
