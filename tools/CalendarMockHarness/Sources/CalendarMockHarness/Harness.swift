import AppKit
import SwiftUI

// Reproduces the layout math of Telegram-Mac/CalendarMonthController.swift's
// CalendarMonthView using only SwiftUI primitives. No Telegram dependencies.
//
// Visual fidelity: approximate (system fonts, system colors).
// Layout fidelity: exact — same currentStartDay computation, same loop, same
// "column 0 = Monday" hardcoding, same .normal vs .media inset rules.

enum Mode { case normal, media }

struct MonthData {
    let date: Date
    let lastDayOfMonth: Int
    let lastDayOfPrevMonth: Int
    let currentStartDay: Int
    let day: Int
    let mode: Mode

    init(year: Int, month: Int, mode: Mode) {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let cal = Calendar.current
        let firstOfMonth = cal.date(from: comps)!
        self.date = firstOfMonth
        self.day = 1
        self.lastDayOfMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        let prevMonth = cal.date(byAdding: .month, value: -1, to: firstOfMonth)!
        self.lastDayOfPrevMonth = cal.range(of: .day, in: .month, for: prevMonth)!.count

        // Mirror CalendarMonthController:93 exactly: weekday of (monthDate - day*86400).
        let dayBefore = firstOfMonth.addingTimeInterval(-Double(self.day) * 86400)
        self.currentStartDay = cal.component(.weekday, from: dayBefore)
        self.mode = mode
    }

    var linesCount: Int {
        switch mode {
        case .media:
            var count = 0
            for i in 0 ..< 7 * 6 {
                if i + 1 < currentStartDay { count += 1 }
                else if (i + 2) - currentStartDay > lastDayOfMonth {}
                else { count += 1 }
            }
            return Int(ceil(Double(count) / 7))
        case .normal: return 6
        }
    }
}

struct DayCell {
    let text: String
    let inThisMonth: Bool
    let hidden: Bool
    let selected: Bool
}

func cells(for month: MonthData, selectedDay: Int? = nil) -> [DayCell] {
    var out: [DayCell] = []
    for i in 0 ..< 7 * 6 {
        if i + 1 < month.currentStartDay {
            let n = (month.lastDayOfPrevMonth - month.currentStartDay) + i + 2
            out.append(DayCell(text: "\(n)", inThisMonth: false, hidden: month.mode == .media, selected: false))
        } else if (i + 2) - month.currentStartDay > month.lastDayOfMonth {
            let n = (i + 2) - (month.currentStartDay + month.lastDayOfMonth)
            out.append(DayCell(text: "\(n)", inThisMonth: false, hidden: month.mode == .media, selected: false))
        } else {
            let current = (i + 1) - month.currentStartDay + 1
            out.append(DayCell(text: "\(current)", inThisMonth: true, hidden: false, selected: selectedDay == current))
        }
    }
    return out
}

func weekdaySymbols(localeId: String) -> [String] {
    let f = DateFormatter()
    f.locale = Locale(identifier: localeId)
    let raw = f.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return Array(raw.dropFirst()) + Array(raw.prefix(1))
}

func monthTitle(month: MonthData, localeId: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: localeId)
    f.dateFormat = "LLLL yyyy"
    return f.string(from: month.date)
}

struct CalendarMockView: View {
    let month: MonthData
    let localeId: String
    let showHeader: Bool
    let selectedDay: Int?

    var body: some View {
        let frameW: CGFloat = 320
        let frameH: CGFloat = month.mode == .normal ? 380 : 280
        let titleHeight: CGFloat = 36
        let headerHeight: CGFloat = showHeader ? 22 : 0
        let bodyHeight = max(0, frameH - titleHeight - headerHeight)
        let columnWidth = (frameW - 20) / 7
        let cellHeight: CGFloat = month.mode == .normal
            ? (bodyHeight - 20) / CGFloat(month.linesCount)
            : bodyHeight / CGFloat(month.linesCount)
        let yInset: CGFloat = month.mode == .normal ? 10 : 0
        let dayCells = cells(for: month, selectedDay: selectedDay)
        let symbols = weekdaySymbols(localeId: localeId)

        ZStack(alignment: .topLeading) {
            Color(NSColor.windowBackgroundColor)

            VStack(spacing: 0) {
                Text(monthTitle(month: month, localeId: localeId))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: frameW, height: titleHeight)

                if showHeader {
                    HStack(spacing: 0) {
                        Spacer().frame(width: 10)
                        ForEach(0..<7, id: \.self) { i in
                            Text(symbols[i])
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: columnWidth, height: headerHeight)
                        }
                        Spacer().frame(width: 10)
                    }
                    .frame(width: frameW, height: headerHeight)
                }

                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: frameW, height: bodyHeight)

                    ForEach(0..<dayCells.count, id: \.self) { i in
                        let row = i / 7
                        let col = i % 7
                        let cell = dayCells[i]
                        let x = 10 + columnWidth * CGFloat(col)
                        let y = yInset + cellHeight * CGFloat(row)

                        if !cell.hidden {
                            ZStack {
                                if cell.selected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: min(columnWidth, cellHeight) * 0.9,
                                               height: min(columnWidth, cellHeight) * 0.9)
                                }
                                Text(cell.text)
                                    .font(.system(size: 13, weight: cell.selected ? .medium : .regular))
                                    .foregroundColor(
                                        cell.selected ? .white :
                                        cell.inThisMonth ? colorForColumn(col) : .secondary.opacity(0.55)
                                    )
                            }
                            .frame(width: columnWidth, height: cellHeight)
                            .offset(x: x, y: y)
                        }
                    }
                }
                .frame(width: frameW, height: bodyHeight)
            }
            .frame(width: frameW, height: frameH)
        }
        .frame(width: frameW, height: frameH)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func colorForColumn(_ col: Int) -> Color {
        // Original code reddens columns 6 and 7 (Saturday, Sunday in Mon-start).
        col >= 5 ? Color.red.opacity(0.85) : Color.primary
    }
}

// Render to PNG using SwiftUI ImageRenderer (macOS 13+).
@MainActor
func renderPNG(_ view: some View, to path: String) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("Failed to render \(path)\n".utf8))
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("Wrote \(path)")
    } catch {
        FileHandle.standardError.write(Data("Write error \(path): \(error)\n".utf8))
    }
}

@main
struct Harness {
    static func main() {
        let outDir = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : FileManager.default.currentDirectoryPath + "/docs/screenshots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let normal = MonthData(year: 2026, month: 4, mode: .normal)
        let media = MonthData(year: 2026, month: 4, mode: .media)

        renderPNG(CalendarMockView(month: normal, localeId: "en_US", showHeader: false, selectedDay: 26),
                  to: "\(outDir)/before-en-normal.png")
        renderPNG(CalendarMockView(month: normal, localeId: "en_US", showHeader: true, selectedDay: 26),
                  to: "\(outDir)/after-en-normal.png")
        renderPNG(CalendarMockView(month: normal, localeId: "ru_RU", showHeader: true, selectedDay: 26),
                  to: "\(outDir)/after-ru-normal.png")
        renderPNG(CalendarMockView(month: normal, localeId: "he_IL", showHeader: true, selectedDay: 26),
                  to: "\(outDir)/after-he-normal.png")
        renderPNG(CalendarMockView(month: media, localeId: "en_US", showHeader: false, selectedDay: nil),
                  to: "\(outDir)/before-en-media.png")
        renderPNG(CalendarMockView(month: media, localeId: "en_US", showHeader: true, selectedDay: nil),
                  to: "\(outDir)/after-en-media.png")

        print("currentStartDay (Apr 2026) = \(normal.currentStartDay)")
        print("linesCount (.media) = \(media.linesCount)")
    }
}
