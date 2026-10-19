import AppKit
import os

private let log = Logger(subsystem: "com.openbartender.app", category: "fitter")

/// Finds the divider width that hides icons cleanly on macOS 26+.
///
/// macOS 26 moved menu-bar layout into Control Center. A widening divider still
/// pushes the icons on its left into the system « overflow, but how far it can
/// grow is limited:
///
/// - While it's **pushing**, its left edge moves by exactly as much as it grows
///   and the system shows a « button for the overflowed icons.
/// - When its left edge reaches the **wall** at the end of the status area, the
///   « button goes away too. This is the state we want.
/// - A few pixels wider and it **overshoots**: its right edge starts creeping
///   into its neighbours, then the layout breaks down and every icon reappears.
///   That's why a fixed 10,000 px stopped working.
///
/// The wall depends on the screen, the notch and the other icons, so we
/// measure it: grow in steps until the left edge stops moving, then narrow down
/// to the exact width where it first touches. Only our own status item's window
/// is read, so this needs no permissions. The width is remembered, so after the
/// first fit collapsing is instant.
final class DividerFitter {

    /// Where the divider's window sat at a given length.
    private struct Sample {
        let length: CGFloat
        let minX: CGFloat
        let maxX: CGFloat
    }

    private struct State {
        /// Width found by the last fit.
        var length: CGFloat?
        /// Frame at normal width; fitting must never push the right edge past it.
        var baseline: Sample?
        /// Bumped to abandon an in-flight fit.
        var generation = 0
        /// A fit is measuring right now.
        var fitting = false
        /// A fit was cut short because the bar wasn't being laid out.
        var interrupted = false
    }

    private var states: [ObjectIdentifier: State] = [:]
    private let expandedWidth: CGFloat
    private let step: CGFloat = 40
    /// Bisections after the coarse search; 40 px → under 1 px. The clean
    /// window at the wall is only ~6 px wide.
    private let refineSteps = 6
    /// Slack for sub-pixel jitter in reported frames.
    private let tolerance: CGFloat = 1.5
    /// Coming back to a remembered width, start this far below it and creep up.
    private let approachMargin: CGFloat = 12
    private let creepStep: CGFloat = 3

    init(expandedWidth: CGFloat) {
        self.expandedWidth = expandedWidth
    }

    // MARK: - API

    /// Widens `item` until everything to its left is hidden.
    func collapse(_ item: NSStatusItem) {
        let id = ObjectIdentifier(item)
        let generation = begin(id)

        guard item.length == expandedWidth else {
            start(item, generation: generation)
            return
        }
        // Take the baseline only once the bar is still: another divider may be
        // mid-move (e.g. the primary one expanding as this one collapses).
        waitForLayout(item) { [weak self] _ in
            guard let self, self.isCurrent(id, generation) else { return }
            self.states[id]!.baseline = self.sample(item)
            self.start(item, generation: generation)
        }
    }

    /// Returns `item` to normal width and abandons any fit in progress.
    func expand(_ item: NSStatusItem) {
        let id = ObjectIdentifier(item)
        let generation = begin(id)
        states[id]!.fitting = false
        item.length = expandedWidth
        // Refresh the baseline once the bar has settled, in case the user has
        // ⌘-dragged the divider since we last looked.
        waitForLayout(item) { [weak self] _ in
            guard let self, self.isCurrent(id, generation) else { return }
            if let sample = self.sample(item) { self.states[id]!.baseline = sample }
        }
    }

    /// Whether a collapse of `item` was cut short and should be tried again.
    func needsRetry(_ item: NSStatusItem) -> Bool {
        states[ObjectIdentifier(item)]?.interrupted ?? false
    }

    /// Re-checks a collapsed `item` after something else on the bar changed.
    ///
    /// Reading the frame is free and catches overshoot. With `probe`, it also
    /// nudges the width by a couple of pixels to see whether the divider is
    /// still at the wall — if the left edge moves, there's more room than
    /// before and the « would be back, so it carries on growing.
    func verify(_ item: NSStatusItem, probe: Bool = false) {
        let id = ObjectIdentifier(item)
        guard item.length > expandedWidth, let state = states[id], !state.fitting,
              let current = sample(item) else { return }

        if isOvershoot(current, id) {
            log.debug("verify: overshoot at \(item.length), refitting")
            refit(item)
            return
        }
        guard probe else { return }

        let generation = begin(id)
        states[id]!.fitting = true
        checkStillAtWall(item, current, generation: generation)
    }

    /// Re-measures from normal width, e.g. after the display layout changes.
    func refit(_ item: NSStatusItem) {
        let id = ObjectIdentifier(item)
        states[id]?.length = nil
        expand(item)
        let generation = states[id]!.generation
        waitForLayout(item) { [weak self] _ in
            guard let self, self.isCurrent(id, generation) else { return }
            self.collapse(item)
        }
    }

    // MARK: - Search

    private func start(_ item: NSStatusItem, generation: Int) {
        let id = ObjectIdentifier(item)
        guard let baseline = states[id]?.baseline else {
            // Not on screen yet — nothing to measure against.
            interrupt(item, id)
            return
        }
        states[id]!.fitting = true

        guard let cached = states[id]!.length else {
            grow(item, last: baseline, generation: generation)
            return
        }
        // The wall shifts by a few pixels between collapses, and jumping even
        // slightly past it can leave the bar stuck overlapping. So land a
        // little below the remembered width and creep up to the wall.
        let approach = max(cached - approachMargin, expandedWidth + step)
        measure(item, to: approach, generation: generation) { [weak self] sample in
            guard let self else { return }
            if self.isStuck(sample, id) || self.isOvershoot(sample, id) {
                self.restart(item, generation: generation)
            } else {
                self.creep(item, last: sample, until: cached + self.step, generation: generation)
            }
        }
    }

    /// Steps up a few pixels at a time until the left edge stops: the wall.
    private func creep(_ item: NSStatusItem, last: Sample, until limit: CGFloat, generation: Int) {
        let id = ObjectIdentifier(item)
        guard last.length < limit else {
            // Much more room than last time; switch to the coarse search.
            grow(item, last: last, generation: generation)
            return
        }
        measure(item, to: last.length + creepStep, generation: generation) { [weak self] sample in
            guard let self else { return }
            if self.isPushing(sample, after: last, id) {
                self.creep(item, last: sample, until: limit, generation: generation)
            } else {
                self.refine(item, pushing: last, past: sample, steps: 2, generation: generation)
            }
        }
    }

    /// Forgets the remembered width and searches again from normal width.
    private func restart(_ item: NSStatusItem, generation: Int) {
        let id = ObjectIdentifier(item)
        log.debug("restart from normal width")
        states[id]!.length = nil
        let before = item.button?.window?.frame
        item.length = expandedWidth
        waitForLayout(item, from: before) { [weak self] _ in
            guard let self, self.isCurrent(id, generation), let baseline = self.sample(item) else { return }
            self.states[id]!.baseline = baseline
            self.grow(item, last: baseline, generation: generation)
        }
    }

    /// Nudges `current` by a couple of pixels: if the left edge follows, the
    /// wall moved out (the « would be back), so carry on growing.
    private func checkStillAtWall(_ item: NSStatusItem, _ current: Sample, generation: Int) {
        let id = ObjectIdentifier(item)
        measure(item, to: current.length + 2, generation: generation) { [weak self] nudged in
            guard let self else { return }
            if self.isPushing(nudged, after: current, id) {
                log.debug("room to grow at \(current.length)")
                self.grow(item, last: nudged, generation: generation)
            } else {
                self.finish(item, at: current.length, generation: generation)
            }
        }
    }

    /// Grows in fixed steps while the divider is still pushing icons.
    private func grow(_ item: NSStatusItem, last: Sample, generation: Int) {
        let id = ObjectIdentifier(item)
        let next = last.length + step
        let limit = (NSScreen.main?.frame.width ?? 2000) * 2
        guard next < limit else { finish(item, at: last.length, generation: generation); return }

        measure(item, to: next, generation: generation) { [weak self] sample in
            guard let self else { return }
            if self.isPushing(sample, after: last, id) {
                self.grow(item, last: sample, generation: generation)
            } else {
                self.refine(item, pushing: last, past: sample, steps: self.refineSteps, generation: generation)
            }
        }
    }

    /// Bisects between a width that's still pushing and one that isn't, to find
    /// the first width at the wall.
    private func refine(_ item: NSStatusItem, pushing: Sample, past: Sample,
                        steps: Int, generation: Int) {
        let id = ObjectIdentifier(item)
        guard steps > 0, past.length - pushing.length > 1 else {
            // At the wall the « is gone. If even the first width past pushing
            // already overshoots, settle for pushing: icons hidden, « shown.
            let atWall = !isOvershoot(past, id) && !isStuck(past, id)
            log.debug("refine: pushing \(pushing.length), past \(past.length), at wall \(atWall)")
            finish(item, at: atWall ? past.length : pushing.length, generation: generation)
            return
        }
        let mid = ((pushing.length + past.length) / 2).rounded()
        measure(item, to: mid, generation: generation) { [weak self] sample in
            guard let self else { return }
            if self.isPushing(sample, after: pushing, id) {
                self.refine(item, pushing: sample, past: past, steps: steps - 1, generation: generation)
            } else {
                self.refine(item, pushing: pushing, past: sample, steps: steps - 1, generation: generation)
            }
        }
    }

    private func finish(_ item: NSStatusItem, at length: CGFloat, generation: Int) {
        let id = ObjectIdentifier(item)
        guard isCurrent(id, generation) else { return }
        item.length = length
        // Only remember widths that actually pushed something.
        states[id]!.length = length >= expandedWidth + step ? length : nil
        states[id]!.fitting = false
        log.debug("finish at \(length)")
    }

    // MARK: - Classification

    /// Still pushing icons: the left edge moved by (at least) as much as the
    /// divider grew, and the right edge hasn't moved into its neighbour. (It
    /// can move further once, when the « button appears to its right.)
    private func isPushing(_ sample: Sample, after previous: Sample, _ id: ObjectIdentifier) -> Bool {
        let expectedMinX = previous.minX - (sample.length - previous.length)
        return sample.minX <= expectedMinX + tolerance && !isOvershoot(sample, id)
    }

    /// Stretched in place from where it sat at normal width instead of
    /// pushing anything: the bar has given up on laying it out properly.
    private func isStuck(_ sample: Sample, _ id: ObjectIdentifier) -> Bool {
        guard let baseline = states[id]?.baseline else { return true }
        return sample.length > expandedWidth + tolerance
            && abs(sample.minX - baseline.minX) <= tolerance
    }

    /// The right edge has crept past where it sat at normal width.
    private func isOvershoot(_ sample: Sample, _ id: ObjectIdentifier) -> Bool {
        guard let baseline = states[id]?.baseline else { return true }
        return sample.maxX > baseline.maxX + tolerance
    }

    // MARK: - Layout

    /// Sets `length`, waits for the bar to re-lay out, and reports where the
    /// divider ended up.
    ///
    /// If the bar doesn't re-lay out at all (screen locked, display asleep) we
    /// can't tell where it went, and growing blindly would overshoot — so the
    /// fit is abandoned at normal width for the caller to retry later.
    private func measure(_ item: NSStatusItem, to length: CGFloat, generation: Int,
                         then completion: @escaping (Sample) -> Void) {
        let id = ObjectIdentifier(item)
        // Read the frame before changing the length: the bar sometimes
        // re-lays out synchronously, so reading it afterwards can miss the move.
        let before = item.button?.window?.frame
        item.length = length
        waitForLayout(item, from: before) { [weak self] changed in
            guard let self, self.isCurrent(id, generation) else { return }
            guard changed, let sample = self.sample(item) else {
                log.debug("measure \(length): no layout — will retry")
                self.interrupt(item, id)
                return
            }
            log.debug("measure \(length): x \(sample.minX)–\(sample.maxX)")
            completion(sample)
        }
    }

    /// Calls back once the item's window frame has stopped changing, saying
    /// whether it changed at all. Control Center re-lays out the bar
    /// asynchronously, typically within ~70 ms.
    private func waitForLayout(_ item: NSStatusItem, from initial: NSRect? = nil,
                               then completion: @escaping (Bool) -> Void) {
        let start = Date()
        let initial = initial ?? item.button?.window?.frame
        var last = item.button?.window?.frame
        var lastChange = start

        func poll() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
                let now = Date()
                let frame = item.button?.window?.frame
                if frame != last { last = frame; lastChange = now }
                let changed = frame != initial
                let quietFor = now.timeIntervalSince(lastChange)
                let elapsed = now.timeIntervalSince(start)
                if (changed && quietFor > 0.04) || (!changed && elapsed > 0.15) || elapsed > 0.4 {
                    completion(changed)
                } else {
                    poll()
                }
            }
        }
        poll()
    }

    private func sample(_ item: NSStatusItem) -> Sample? {
        guard let frame = item.button?.window?.frame, frame.width > 0 else { return nil }
        return Sample(length: item.length, minX: frame.minX, maxX: frame.maxX)
    }

    // MARK: - Bookkeeping

    /// Starts a new operation on `id`, abandoning whatever was in flight.
    private func begin(_ id: ObjectIdentifier) -> Int {
        states[id, default: State()].generation += 1
        states[id]!.interrupted = false
        return states[id]!.generation
    }

    private func isCurrent(_ id: ObjectIdentifier, _ generation: Int) -> Bool {
        states[id]?.generation == generation
    }

    private func interrupt(_ item: NSStatusItem, _ id: ObjectIdentifier) {
        states[id]!.generation += 1
        states[id]!.fitting = false
        states[id]!.interrupted = true
        item.length = expandedWidth
    }
}
