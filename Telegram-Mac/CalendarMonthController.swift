//
//  CalendarMonthController.swift
//  TelegramMac
//
//  Created by keepcoder on 17/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import CalendarUtils

struct CalendarMonthInteractions {
    let lowYear: Int
    let canBeNoYear: Bool
    let selectAction:(Date)->Void
    let backAction:((Date)->Void)?
    let nextAction:((Date)->Void)?
    let changeYear: (Int32, Date)->Void
    init(lowYear: Int, canBeNoYear: Bool, selectAction:@escaping (Date)->Void, backAction:((Date)->Void)? = nil, nextAction:((Date)->Void)? = nil, changeYear: @escaping(Int32, Date)->Void) {
        self.selectAction = selectAction
        self.backAction = backAction
        self.nextAction = nextAction
        self.changeYear = changeYear
        self.lowYear = lowYear
        self.canBeNoYear = canBeNoYear
    }
}

final class CalendarMonthStruct {
    let month:Date
    let prevMonth:Date
    let nextMonth:Date
    
    let lastDayOfMonth:Int
    let lastDayOfPrevMonth:Int
    let lastDayOfNextMonth:Int
    
    let currentStartDay:Int
    var selectedDay:Int?
    
    let components:DateComponents
    let dayHandler:(Int)->Void
    let onlyFuture: Bool
    let limitedBy: Date?
    
    let dayPreview:(Int)->NSView?
    
    var linesCount: Int {
        switch mode {
        case .media:
            var count: Int = 0
            for i in 0 ..< 7 * 6 {
                if i + 1 < currentStartDay {
                    count += 1
                } else if (i + 2) - currentStartDay > lastDayOfMonth {
                } else {
                    count += 1
                }
            }
            let result = Int(ceil(Float(count) / 7))
            return result
        case .normal:
            return 6
        }
       
    }
    
    enum Mode {
        case media
        case normal
    }
    let mode: Mode
    
    init(month:Date, mode: Mode = .normal, selectDayAnyway: Bool, onlyFuture: Bool, limitedBy: Date?, dayHandler:@escaping (Int)->Void, dayPreview:@escaping(Int)->NSView? = { _ in return nil }) {
        self.month = month
        self.onlyFuture = onlyFuture
        self.limitedBy = limitedBy
        self.dayHandler = dayHandler
        self.prevMonth = CalendarUtils.stepMonth(-1, date: month)
        self.nextMonth = CalendarUtils.stepMonth(1, date: month)
        self.lastDayOfMonth = CalendarUtils.lastDay(ofTheMonth: month)
        self.lastDayOfPrevMonth = CalendarUtils.lastDay(ofTheMonth: prevMonth)
        self.lastDayOfNextMonth = CalendarUtils.lastDay(ofTheMonth: nextMonth)
        self.mode = mode
        self.dayPreview = dayPreview
        
        
        let calendar = NSCalendar.current
        
//        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: month)
        self.currentStartDay = CalendarUtils.weekDay(Date(timeIntervalSince1970: month.timeIntervalSince1970 - TimeInterval(components.day! * 24*60*60)))
        
        if selectDayAnyway {
            selectedDay = components.day!
        } else {
            selectedDay = nil
        }
        
        self.components = components
    }
}

class CalendarMonthView : View {
    private var month:CalendarMonthStruct?

    private var dayPreviews: [Int : NSView] = [:]
    private let dayPreviewsViews = View()
    private let dayViews = View()
    private let weekdayHeaderView = View()
    private var weekdayLabels: [TextView] = []

    private static let weekdayHeaderHeight: CGFloat = 22

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(weekdayHeaderView)
        addSubview(dayPreviewsViews)
        addSubview(dayViews)

        for _ in 0 ..< 7 {
            let label = TextView()
            label.userInteractionEnabled = false
            label.isSelectable = false
            weekdayHeaderView.addSubview(label)
            weekdayLabels.append(label)
        }

        backgroundColor = theme.colors.background
        weekdayHeaderView.backgroundColor = theme.colors.background
    }
    
    override func scrollWheel(with event: NSEvent) {
        if let month = month {
            switch month.mode {
            case .media:
                super.scrollWheel(with: event)
            default:
                break
            }
        }
    }
    
    func layout(for month:CalendarMonthStruct) {
        dayPreviewsViews.removeAllSubviews()
        dayViews.removeAllSubviews()
        if self.month?.month != month.month {
            self.dayPreviews.removeAll()
        }
        self.month = month

        // Day grid is hardcoded Monday-start (column 0 always = Monday), independent of
        // Calendar.current.firstWeekday. Header order is therefore fixed Mon..Sun, with
        // localized symbols. shortStandaloneWeekdaySymbols is Sun-indexed; rotate by 1.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appAppearance.language.languageCode)
        let raw = formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let symbols = Array(raw.dropFirst()) + Array(raw.prefix(1))
        for (i, symbol) in symbols.enumerated() {
            let attr = NSAttributedString.initialize(string: symbol, color: theme.colors.grayText, font: .normal(.short))
            let layout = TextViewLayout(attr, alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            weekdayLabels[i].update(layout)
        }

        for i in 0 ..< 7 * 6 {
            let day = TextButton()
            day.set(font: .normal(.text), for: .Normal)
            day.set(background: theme.colors.background, for: .Normal)
            day.scaleOnClick = true
            let hideExcess: Bool
            switch month.mode {
            case .media:
                hideExcess = true
            case .normal:
                hideExcess = false
            }
            let current:Int
            
            if i + 1 < month.currentStartDay {
                current = (month.lastDayOfPrevMonth - month.currentStartDay) + i + 2
                day.set(color: theme.colors.grayText, for: .Normal)
                day.isHidden = hideExcess
            } else if (i + 2) - month.currentStartDay > month.lastDayOfMonth {
                current = (i + 2) - (month.currentStartDay + month.lastDayOfMonth)
                day.set(color: theme.colors.grayText, for: .Normal)
                day.isHidden = hideExcess
            } else {
                current = (i + 1) - month.currentStartDay + 1
                
                var skipDay: Bool = false
                
                let calendar = NSCalendar.current
//                calendar.timeZone = TimeZone(abbreviation: "UTC")!
                let components = calendar.dateComponents([.day, .year, .month], from: Date())
                
                if month.onlyFuture, CalendarUtils.isSameDate(month.month, date: Date(), checkDay: false) {
                    if current < components.day! {
                        skipDay = true
                    }
                } else if month.onlyFuture, components.year! + 1 == month.components.year! && components.month! == month.components.month!  {
                    if current > components.day! {
                        skipDay = true
                    }
                } else if CalendarUtils.isSameDate(month.month, date: Date(), checkDay: false), current > components.day! {
                    skipDay = true
                }
                let dayTimeinterval = CalendarUtils.monthDay(current, date: month.month).timeIntervalSince1970
                
                let dayPreview = self.dayPreviews[current] ?? month.dayPreview(Int(dayTimeinterval))
                if let dayPreview = dayPreview {
                    self.dayPreviews[current] = dayPreview
                    self.dayPreviewsViews.addSubview(dayPreview)
                }
                day.contextObject = current
                
                if let limitedBy = month.limitedBy {
                    let limited = calendar.dateComponents([.year, .month, .day], from: limitedBy)
                    if limited.year! < month.components.year! || limited.month! < month.components.month! || limited.day! < current {
                        skipDay = true
                    }
                }
                if !skipDay {
                    day.set(color: theme.colors.underSelectedColor, for: .Highlight)
                    if (i + 1) % 7 == 0 || (i + 2) % 7 == 0 {
                        day.set(color: theme.colors.redUI, for: .Normal)
                    } else {
                        day.set(color: theme.colors.text, for: .Normal)
                    }
                    if dayPreview != nil {
                        day.set(background: .clear, for: .Normal)
                        day.set(background: .clear, for: .Highlight)
                        day.set(color: .white, for: .Normal)
                        day.set(font: .medium(.text), for: .Normal)
                    } else {
                        switch month.mode {
                        case .media:
                            day.set(background: theme.colors.background, for: .Normal)
                            day.set(background: theme.colors.background, for: .Highlight)
                            day.set(color: theme.colors.text, for: .Highlight)
                        case .normal:
                            if let selectedDay = month.selectedDay, current == selectedDay {
                               // day.isSelected = true
                                day.set(color: theme.colors.underSelectedColor, for: .Normal)
                                
                                day.set(background: theme.colors.accent, for: .Normal)
                                day.set(background: theme.colors.accent, for: .Highlight)
                            } else {
                                day.set(background: theme.colors.background, for: .Normal)
                                day.set(background: theme.colors.accent, for: .Highlight)
                            }
                        }
                        
                    }
                   
                    day.set(handler: { [weak self] (control) in
                        if month.mode != .media {
                            month.selectedDay = current
                        }
                        month.dayHandler(current)
                        self?.layout(for: month)
                        
                    }, for: .Click)
                } else {
                    day.set(color: theme.colors.grayText, for: .Normal)
                }
            }
            day.set(text: "\(current)", for: .Normal)
            
            dayViews.addSubview(day)
        }
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()

        let headerHeight = CalendarMonthView.weekdayHeaderHeight
        weekdayHeaderView.frame = NSMakeRect(0, 0, frame.width, headerHeight)

        let bodyOriginY = headerHeight
        let bodyHeight = max(0, frame.height - headerHeight)
        let bodyFrame = NSMakeRect(0, bodyOriginY, frame.width, bodyHeight)
        dayViews.frame = bodyFrame
        dayPreviewsViews.frame = bodyFrame

        let columnWidth = floorToScreenPixels(backingScaleFactor, (frame.width - 20) / 7)
        for (i, label) in weekdayLabels.enumerated() {
            let cellX = 10 + columnWidth * CGFloat(i)
            label.setFrameOrigin(NSMakePoint(cellX + (columnWidth - label.frame.width) / 2,
                                             (headerHeight - label.frame.height) / 2))
        }

        guard let month = self.month else {
            return
        }

        let oneSize:NSSize
        var inset:NSPoint
        switch month.mode {
        case .normal:
            oneSize = NSMakeSize(columnWidth, floorToScreenPixels(backingScaleFactor, (bodyHeight - 20) / CGFloat(month.linesCount)))
            inset = NSMakePoint(10, 10)
        case .media:
            oneSize = NSMakeSize(columnWidth, floorToScreenPixels(backingScaleFactor, bodyHeight / CGFloat(month.linesCount)))
            inset = NSMakePoint(10, 0)
        }

        for i in 0 ..< dayViews.subviews.count {
            if let view = dayViews.subviews[i] as? TextButton {
                view.frame = NSMakeRect(inset.x, inset.y, oneSize.width, oneSize.height)
                view.layer?.cornerRadius = view.frame.height / 2
                if let currentDay = view.contextObject as? Int {
                    if let preview = self.dayPreviews[currentDay] {
                        preview.setFrameOrigin(inset.x + (view.frame.width - preview.frame.width) / 2, inset.y + (view.frame.height - preview.frame.height) / 2)
                    }
                }
                inset.x += oneSize.width
                if (i + 1) % 7 == 0 {
                    inset.x = 10
                    inset.y += oneSize.height
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}



class CalendarMonthController: GenericViewController<CalendarMonthView> {
    let interactions:CalendarMonthInteractions
    let month:CalendarMonthStruct
    let onlyFuture: Bool
    let limitedBy: Date?
    let lowYear: Int
    init(_ month:Date, onlyFuture: Bool, limitedBy: Date?, selectDayAnyway: Bool, interactions:CalendarMonthInteractions, lowYear: Int = 2013) {
        self.onlyFuture = onlyFuture
        self.limitedBy = limitedBy
        self.lowYear = lowYear
        self.month = CalendarMonthStruct(month: month, selectDayAnyway: selectDayAnyway, onlyFuture: self.onlyFuture, limitedBy: self.limitedBy, dayHandler: { day in
            interactions.selectAction(CalendarUtils.monthDay(day, date: month))
        })
        self.interactions = interactions
        
        super.init()
        self.bar = NavigationBarStyle(height: 40)
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        let formatter:DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: appAppearance.language.languageCode)
        formatter.dateFormat = "LLLL"
        let monthString:String = formatter.string(from: month.month)
        formatter.dateFormat = "yyyy"
        let yearString:String
        if month.components.year == 1 {
            yearString = "—"
        } else {
            yearString = formatter.string(from: month.month)
        }
        
        let barView = TitledBarView(controller: self, .initialize(string: monthString, color: theme.colors.text, font:.medium(.text)), .initialize(string:yearString, color: theme.colors.grayText, font:.normal(.small)))
        barView.removeAllHandlers()
        
        let lowYear = self.interactions.lowYear
        let canBeNoYear = self.interactions.canBeNoYear

        barView.contextMenu = { [weak self] in
            guard let `self` = self else {
                return nil
            }
            
            let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            
            var now: time_t = time_t(nowTimestamp)
            var timeinfoNow: tm = tm()
            localtime_r(&now, &timeinfoNow)
            
             var items:[ContextMenuItem] = []
            
            if canBeNoYear {
                items.append(.init("—", handler: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.interactions.changeYear(1, self.month.month)
                }))
            }
            
            for i in stride(from: 1900 + timeinfoNow.tm_year, to: Int32(lowYear) - 1, by: -1) {
                items.append(.init("\(i)", handler: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.interactions.changeYear(i, self.month.month)
                }))
            }
            if !items.isEmpty && !self.onlyFuture {
                let menu = ContextMenu(betterInside: true)
                for item in items {
                    menu.addItem(item)
                }
                return menu
            }
            return nil
        }
        
        
        return barView
    }
    
    var isNextEnabled:Bool {
        if self.onlyFuture {
            
            var calendar = NSCalendar.current
            
//            calendar.timeZone = TimeZone(abbreviation: "UTC")!
            let components = calendar.dateComponents([.year, .month, .day], from: Date())

            
            if month.components.year! == components.year! {
                return true
            } else if components.year! + 1 == month.components.year! {
                return month.components.month! < components.month!
            }
            return true
        }
        if month.components.year! == 1, month.components.month! == 12 {
            return false
        }
        return !CalendarUtils.isSameDate(month.month, date: Date(), checkDay: false)
    }
    
    var isPrevEnabled:Bool {
        if self.onlyFuture {
            return !CalendarUtils.isSameDate(month.month, date: Date(), checkDay: false)
        }
        return month.components.year! > lowYear || ((month.components.year == lowYear || month.components.year! == 1) && month.components.month! > 1)
    }
    
    override func getLeftBarViewOnce() -> BarView {
        let bar = ImageBarView(controller: self, theme.icons.calendarBack)
        bar.button.isEnabled = isPrevEnabled
        
        if isPrevEnabled {
            bar.button.set(handler: { [weak self] (control) in
                if let backAction = self?.interactions.backAction, let month = self?.month.month {
                    backAction(month)
                }
            }, for: .Click)
        }
        
        bar.set(image: bar.button.isEnabled ? theme.icons.calendarBack : theme.icons.calendarBackDisabled)
        bar.setFrameSize(40,bar.frame.height)
        bar.set(background: theme.colors.background, for: .Normal)
        return bar
    }
    
    override func getRightBarViewOnce() -> BarView {
        let bar = ImageBarView(controller: self, theme.icons.calendarNext)
        bar.button.isEnabled = isNextEnabled

        if isNextEnabled {
            bar.button.set(handler: { [weak self] (control) in
                if let nextAction = self?.interactions.nextAction, let month = self?.month.month {
                    nextAction(month)
                }
            }, for: .Click)
        }
       
        bar.set(image: bar.button.isEnabled ? theme.icons.calendarNext : theme.icons.calendarNextDisabled)
        bar.setFrameSize(40,bar.frame.height)
        bar.set(background: theme.colors.background, for: .Normal)
        return bar
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.layout(for: month)
        
        readyOnce()
    }

    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
}

