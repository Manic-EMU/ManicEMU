//
//  DuoLayoutKit.swift
//  ManicEmu
//
//  SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

/// The system side strip on iPhone Duo, in a view's current coordinates.
///
/// Inner portrait keeps bars on the top and bottom, so there is no side strip.
/// Outer display, inner landscape, and Split View are not special-cased: the
/// strip is whichever left or right edge currently holds the vertical chrome.
/// Rotation is already reflected by that view's bounds, safe area, and occlusion frames.
struct DuoSideStrip: Equatable {
    enum Edge: Equatable {
        case left
        case right
    }

    var edge: Edge
    /// Full strip, including the space behind the camera.
    var frame: CGRect
    /// Active occlusion frames that intersect the strip.
    var occlusions: [CGRect]
    /// Strip pieces that do not overlap an occlusion, from top to bottom.
    var freeRects: [CGRect]

    /// Centers `size` in the strip. Shifts it down only when that centered frame intersects an occlusion.
    func frame(fitting size: CGSize) -> CGRect {
        let originX = frame.minX + max(0, (frame.width - size.width) / 2)
        var originY = frame.midY - size.height / 2
        let blocked = DuoLayoutKit.mergedVerticalSpans(occlusions.map { ($0.minY, $0.maxY) })
        for span in blocked where span.upper > span.lower {
            let candidate = CGRect(x: originX, y: originY, width: size.width, height: size.height)
            let spanRect = CGRect(x: frame.minX, y: span.lower, width: frame.width, height: span.upper - span.lower)
            if candidate.intersects(spanRect) {
                originY = span.upper
            }
        }
        let minY = frame.minY
        let maxY = max(minY, frame.maxY - size.height)
        originY = min(max(minY, originY), maxY)
        return CGRect(x: originX, y: originY, width: size.width, height: size.height)
    }
    
    func cameraArea() -> CGRect? {
        if let rect = occlusions.first {
            if UIDevice.currentOrientation == .landscapeLeft || UIDevice.currentOrientation == .portraitUpsideDown {
                return CGRect(origin: frame.origin, size: CGSize(frame.width))
            } else {
                let height = rect.minY + rect.maxY
                if height > 0 {
                    return CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: height))
                }
            }
        }
        return nil
    }
}

enum DuoLayoutKit {
    /// Minimum horizontal inset that counts as the system side strip.
    private static let minimumStripWidth: CGFloat = 44

    /// Side strip of `view`, or of the application window when `view` is nil.
    static func sideStrip(in view: UIView? = nil) -> DuoSideStrip? {
        guard let view = view ?? ApplicationSceneDelegate.applicationWindow else { return nil }
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        let occlusions = occlusionFrames(in: view)
        guard let edge = stripEdge(insets: view.safeAreaInsets, occlusions: occlusions, bounds: bounds) else {
            return nil
        }
        let width = stripWidth(edge: edge, insets: view.safeAreaInsets, occlusions: occlusions, bounds: bounds)
        let minX = edge == .right ? bounds.width - width : 0
        let strip = CGRect(x: minX, y: 0, width: width, height: bounds.height)
        let hittingStrip = occlusions.filter { $0.intersects(strip) }
        return DuoSideStrip(
            edge: edge,
            frame: strip,
            occlusions: hittingStrip,
            freeRects: freeRects(in: strip, occlusions: hittingStrip)
        )
    }

    private static func occlusionFrames(in view: UIView) -> [CGRect] {
        guard #available(iOS 27.1, *) else { return [] }
        return view.reservedRegions(kind: .occlusion).filter(\.isActive).map(\.frame)
    }

    private static func stripEdge(insets: UIEdgeInsets, occlusions: [CGRect], bounds: CGRect) -> DuoSideStrip.Edge? {
        let right = max(insets.right, edgeWidth(.right, occlusions: occlusions, bounds: bounds))
        let left = max(insets.left, edgeWidth(.left, occlusions: occlusions, bounds: bounds))
        if right >= minimumStripWidth, right > left { return .right }
        if left >= minimumStripWidth, left > right { return .left }
        return nil
    }

    private static func stripWidth(edge: DuoSideStrip.Edge, insets: UIEdgeInsets, occlusions: [CGRect], bounds: CGRect) -> CGFloat {
        let inset = edge == .right ? insets.right : insets.left
        return max(inset, edgeWidth(edge, occlusions: occlusions, bounds: bounds))
    }

    private static func edgeWidth(_ edge: DuoSideStrip.Edge, occlusions: [CGRect], bounds: CGRect) -> CGFloat {
        occlusions.filter { rect in
            edge == .right ? abs(rect.maxX - bounds.width) <= 1 : abs(rect.minX) <= 1
        }.map(\.width).max() ?? 0
    }

    private static func freeRects(in strip: CGRect, occlusions: [CGRect]) -> [CGRect] {
        let spans = mergedVerticalSpans(occlusions.map { (max(strip.minY, $0.minY), min(strip.maxY, $0.maxY)) })
        var rects: [CGRect] = []
        var cursor = strip.minY
        for span in spans where span.upper > span.lower {
            if span.lower > cursor {
                rects.append(CGRect(x: strip.minX, y: cursor, width: strip.width, height: span.lower - cursor))
            }
            cursor = max(cursor, span.upper)
        }
        if strip.maxY > cursor {
            rects.append(CGRect(x: strip.minX, y: cursor, width: strip.width, height: strip.maxY - cursor))
        }
        return rects
    }

    fileprivate static func mergedVerticalSpans(_ input: [(CGFloat, CGFloat)]) -> [(lower: CGFloat, upper: CGFloat)] {
        let sorted = input.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        var result: [(lower: CGFloat, upper: CGFloat)] = []
        for item in sorted {
            if let last = result.last, item.0 <= last.upper {
                result[result.count - 1].upper = max(last.upper, item.1)
            } else {
                result.append((item.0, item.1))
            }
        }
        return result
    }
}
