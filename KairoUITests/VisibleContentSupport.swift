import XCTest

@MainActor
extension XCUIApplication {
    /// Use the scroll container and actual occluding chrome, not a device-sized
    /// guessed footer. Short drags near the target avoid flinging past it.
    func revealContent(_ element: XCUIElement, fullyVisible: Bool = false, missingTargetIsAbove: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let scroll: XCUIElement
        if element.exists {
            let containing = scrollViews.containing(.any, identifier: element.identifier).firstMatch
            scroll = containing.exists ? containing : scrollViews.firstMatch
        } else {
            scroll = scrollViews.firstMatch
        }
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "Missing content scroll view", file: file, line: line)
        guard scroll.exists else { return }
        var previousFrame: CGRect?
        var stalled = 0
        var remainingDrags = 25
        if element.exists {
            // XXXL comparison cards can span many viewports. Bound the traversal
            // by measured distance instead of assuming every form fits 25 drags.
            remainingDrags += Int(ceil(abs(element.frame.midY - scroll.frame.midY) / max(1, scroll.frame.height * 0.5)))
        }
        while remainingDrags > 0 {
            remainingDrags -= 1
            var viewport = scroll.frame.intersection(frame)
            let navigation = navigationBars.firstMatch
            if navigation.exists, navigation.isHittable {
                let top = max(viewport.minY, navigation.frame.maxY)
                viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
            }
            for chrome in [tabBars.firstMatch, keyboards.firstMatch] where chrome.exists && chrome.isHittable {
                if chrome.frame.intersects(viewport) {
                    viewport.size.height = max(0, min(viewport.maxY, chrome.frame.minY) - viewport.minY)
                }
            }
            guard viewport.height > 0 else { break }
            let target = element.exists ? element.frame : .null
            let visible = target.intersection(viewport)
            if !target.isNull, !visible.isNull,
               visible.height >= (fullyVisible ? target.height : min(44, target.height)),
               (element.elementType != .button || viewport.contains(CGPoint(x: target.midX, y: target.midY))),
               element.isHittable || !element.isEnabled { return }
            if !target.isNull, let previousFrame, previousFrame == target { stalled += 1 } else { stalled = 0 }
            if stalled >= 2 { break }
            previousFrame = target
            // Lazy stacks may remove an earlier section from the AX tree.
            // A caller returning to a known earlier section must search up,
            // rather than repeatedly searching below the end of the list.
            let delta = target.isNull
                ? (missingTargetIsAbove ? -viewport.height : viewport.height)
                : target.midY - viewport.midY
            let distance = min(max(abs(delta), 20), viewport.height * 0.6)
            let startY = delta < 0 ? viewport.minY + viewport.height * 0.2 : viewport.maxY - viewport.height * 0.2
            let start = coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: viewport.midX, dy: startY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta < 0 ? distance : -distance)))
        }
        XCTFail("Content is not visibly reachable: \(element.identifier), frame \(element.exists ? element.frame : .null)", file: file, line: line)
    }
}
