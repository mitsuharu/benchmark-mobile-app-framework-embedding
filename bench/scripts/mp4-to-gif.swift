#!/usr/bin/env swift  //
// Converts a screen recording into a small looping GIF for the README, with
// nothing but the frameworks that ship with macOS (no ffmpeg needed).
//
//   swift scripts/mp4-to-gif.swift <in.mp4> <out.gif> [width] [fps]
//
// Frames that look the same as the one before are merged into one longer
// frame, so the still parts of a recording cost almost nothing. The last
// frame is held a little longer so the loop shows where it ends.

import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
  FileHandle.standardError.write(
    Data("usage: mp4-to-gif.swift <in.mp4> <out.gif> [width] [fps]\n".utf8))
  exit(1)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
let width = arguments.count > 3 ? Int(arguments[3]) ?? 280 : 280
let fps = arguments.count > 4 ? Double(arguments[4]) ?? 8 : 8
let finalHoldSeconds = 1.5

let asset = AVURLAsset(url: input)
let duration = try await asset.load(.duration).seconds

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: width, height: width * 4)

/// Draws a frame into a fixed RGBA buffer, to tell repeated frames apart.
func pixels(of image: CGImage) -> Data {
  let bytesPerRow = image.width * 4
  var data = Data(count: bytesPerRow * image.height)
  data.withUnsafeMutableBytes { buffer in
    let context = CGContext(
      data: buffer.baseAddress,
      width: image.width,
      height: image.height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  }
  return data
}

var frames: [(image: CGImage, delay: Double)] = []
var previousPixels: Data?
let step = 1 / fps
var time = 0.0
while time < duration {
  let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
  let current = pixels(of: image)
  if current == previousPixels, !frames.isEmpty {
    frames[frames.count - 1].delay += step
  } else {
    frames.append((image, step))
    previousPixels = current
  }
  time += step
}
guard !frames.isEmpty else {
  FileHandle.standardError.write(Data("no frames in \(input.path)\n".utf8))
  exit(1)
}
frames[frames.count - 1].delay += finalHoldSeconds

guard
  let destination = CGImageDestinationCreateWithURL(
    output as CFURL, UTType.gif.identifier as CFString, frames.count, nil)
else {
  FileHandle.standardError.write(Data("cannot write \(output.path)\n".utf8))
  exit(1)
}
CGImageDestinationSetProperties(
  destination,
  [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
)
for frame in frames {
  CGImageDestinationAddImage(
    destination,
    frame.image,
    [
      kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: frame.delay,
        kCGImagePropertyGIFUnclampedDelayTime: frame.delay,
      ]
    ] as CFDictionary
  )
}
guard CGImageDestinationFinalize(destination) else {
  FileHandle.standardError.write(Data("cannot write \(output.path)\n".utf8))
  exit(1)
}

let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
print(
  "\(output.lastPathComponent): \(frames.count) frames, \(String(format: "%.1f", duration)) s, \(size / 1024) KB"
)
