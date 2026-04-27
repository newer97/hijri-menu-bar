import SwiftUI
import AppKit

struct CalendarView: View {
    @State private var now = Date()
    @State private var displayedMonth = Date()
    @State private var scrollMonitor: Any? = nil
    @State private var swipeAccum: CGFloat = 0
    @State private var swipeFired = false
    @State private var showingGoTo = false
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private let weekdays: [(ar: String, en: String)] = [
        ("الأحد", "Sun"),
        ("الإثنين", "Mon"),
        ("الثلاثاء", "Tue"),
        ("الأربعاء", "Wed"),
        ("الخميس", "Thu"),
        ("الجمعة", "Fri"),
        ("السبت", "Sat")
    ]

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()
                weekdayRow
                grid
            }
            .padding(16)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let dx = value.translation.width
                        if dx > 50 { shiftMonth(-1) }
                        else if dx < -50 { shiftMonth(1) }
                    }
            )

            if showingGoTo {
                GoToDateSheet(
                    isPresented: $showingGoTo,
                    onPick: { date in
                        withAnimation(.easeOut(duration: 0.15)) {
                            displayedMonth = date
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { now = $0 }
        .onAppear(perform: installScrollMonitor)
        .onDisappear(perform: removeScrollMonitor)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HijriDateUtils.hijriMonthArabic(for: displayedMonth))
                    .font(.system(size: 22, weight: .bold))
                Text(gregorianSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            navControls
        }
    }

    private var gregorianSubtitle: String {
        let month = HijriDateUtils.gregorianMonthName(displayedMonth)
        let year = HijriDateUtils.gregorianYear(displayedMonth)
        let hYear = HijriDateUtils.hijriYears(for: displayedMonth).map(String.init).joined(separator: "/")
        return "\(month) \(year)  ·  \(hYear) هـ"
    }

    private var navControls: some View {
        HStack(spacing: 4) {
            Button { showingGoTo = true } label: {
                Image(systemName: "calendar.badge.clock")
            }
            .buttonStyle(.borderless)
            .help("اذهب إلى تاريخ")

            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("الشهر السابق")

            Button("اليوم") { displayedMonth = now }
                .buttonStyle(.borderless)
                .disabled(HijriDateUtils.isInMonth(now, month: displayedMonth))

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .help("الشهر التالي")
        }
        .font(.system(size: 13, weight: .medium))
    }

    private func shiftMonth(_ delta: Int) {
        if let next = HijriDateUtils.gregorian.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(.easeOut(duration: 0.15)) {
                displayedMonth = next
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.en) { label in
                VStack(spacing: 1) {
                    Text(label.ar)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(label.en)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }

    private var grid: some View {
        let dates = HijriDateUtils.calendarGrid(for: displayedMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(dates, id: \.self) { date in
                DayCell(
                    date: date,
                    inMonth: HijriDateUtils.isInMonth(date, month: displayedMonth),
                    isToday: HijriDateUtils.isToday(date)
                )
            }
        }
    }

    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            handleScroll(event)
            return event
        }
    }

    private func removeScrollMonitor() {
        if let m = scrollMonitor {
            NSEvent.removeMonitor(m)
            scrollMonitor = nil
        }
    }

    private func handleScroll(_ event: NSEvent) {
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        guard abs(dx) > abs(dy) else { return }

        if event.phase == .began {
            swipeAccum = 0
            swipeFired = false
        }
        swipeAccum += dx
        if !swipeFired && abs(swipeAccum) > 30 {
            swipeFired = true
            shiftMonth(swipeAccum > 0 ? -1 : 1)
        }
        if event.phase == .ended || event.phase == .cancelled {
            swipeAccum = 0
            swipeFired = false
        }
    }
}

private struct DayCell: View {
    let date: Date
    let inMonth: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                }
                Text("\(HijriDateUtils.gregorianDay(date))")
                    .font(.system(size: 16, weight: isToday ? .semibold : .regular))
                    .foregroundColor(gregorianColor)
            }
            .frame(height: 30)

            Text("\(HijriDateUtils.hijriDay(date))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(hijriColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var gregorianColor: Color {
        if isToday { return .white }
        return inMonth ? .primary : .secondary.opacity(0.45)
    }

    private var hijriColor: Color {
        if isToday { return .red }
        return inMonth ? .secondary : .secondary.opacity(0.4)
    }
}

private struct GoToDateSheet: View {
    @Binding var isPresented: Bool
    let onPick: (Date) -> Void

    enum Kind: String, CaseIterable, Identifiable {
        case hijri, gregorian
        var id: String { rawValue }
        var label: String { self == .hijri ? "هجري" : "ميلادي" }
    }

    @State private var kind: Kind = .hijri
    @State private var day: Int = Calendar(identifier: .islamicUmmAlQura).component(.day, from: Date())
    @State private var month: Int = Calendar(identifier: .islamicUmmAlQura).component(.month, from: Date())
    @State private var year: Int = Calendar(identifier: .islamicUmmAlQura).component(.year, from: Date())
    @State private var error: String? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .onTapGesture { isPresented = false }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("اذهب إلى تاريخ")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                Picker("", selection: kindBinding) {
                    ForEach(Kind.allCases) { k in
                        Text(k.label).tag(k)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(alignment: .bottom, spacing: 10) {
                    numberField(label: "اليوم", value: $day, range: 1...30, width: 56)
                    numberField(label: "الشهر", value: $month, range: 1...12, width: 56)
                    numberField(label: "السنة", value: $year, range: 1...9999, width: 80)
                }

                if let preview = previewLine {
                    Text(preview)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if let error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }

                HStack {
                    Button("إلغاء") { isPresented = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("اذهب") { go() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(width: 380)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            )
        }
    }

    private func numberField(label: String, value: Binding<Int>, range: ClosedRange<Int>, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 2) {
                TextField("", value: value, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: width)
                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    private var kindBinding: Binding<Kind> {
        Binding(
            get: { kind },
            set: { newKind in
                if newKind != kind { convert(from: kind, to: newKind) }
                kind = newKind
            }
        )
    }

    private var calendar: Calendar {
        kind == .hijri ? HijriDateUtils.hijriArabic : HijriDateUtils.gregorian
    }

    private var previewLine: String? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return nil
        }
        let other: Calendar = kind == .hijri ? HijriDateUtils.gregorian : HijriDateUtils.hijriArabic
        let f = DateFormatter()
        f.calendar = other
        f.locale = kind == .hijri ? Locale(identifier: "en_US") : Locale(identifier: "ar")
        f.dateFormat = kind == .hijri ? "d MMMM yyyy" : "d MMMM yyyy"
        let suffix = kind == .hijri ? "" : " هـ"
        return "≈ \(f.string(from: date))\(suffix)"
    }

    private func convert(from old: Kind, to new: Kind) {
        let oldCal = old == .hijri ? HijriDateUtils.hijriArabic : HijriDateUtils.gregorian
        let newCal = new == .hijri ? HijriDateUtils.hijriArabic : HijriDateUtils.gregorian
        guard let date = oldCal.date(from: DateComponents(year: year, month: month, day: day)) else { return }
        year = newCal.component(.year, from: date)
        month = newCal.component(.month, from: date)
        day = newCal.component(.day, from: date)
    }

    private func go() {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            error = "تاريخ غير صحيح"
            return
        }
        onPick(date)
        isPresented = false
    }
}
