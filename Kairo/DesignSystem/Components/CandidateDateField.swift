import SwiftUI

nonisolated enum CandidateDateInput {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    static func display(_ date: Date?, precision: CareerDatePrecisionOption) -> String {
        guard let date else { return "Not set" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate(precision == .day ? "dMMMyyyy" : precision == .month ? "MMMyyyy" : "yyyy")
        return formatter.string(from: date)
    }
    static func date(year: String, month: Int = 1, day: Int = 1) -> Date? {
        guard let y = Int(year), (1...9999).contains(y), (1...12).contains(month) else { return nil }
        guard (1...31).contains(day),
              let result = calendar.date(from: DateComponents(year: y, month: month, day: day)),
              calendar.component(.year, from: result) == y,
              calendar.component(.month, from: result) == month,
              calendar.component(.day, from: result) == day else { return nil }
        return result
    }
    static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL"
        return date(year: "2000", month: month).map(formatter.string(from:)) ?? ""
    }
}

/// A modal draft is committed only by Use date. Opening and Cancel never change the bound value.
struct CandidateDateField: View {
    let title: String
    @Binding var selection: Date?
    var precision: CareerDatePrecisionOption = .day
    var required = false
    var disabled = false
    var hasIncompleteValue = false
    var errorMessage: String? = nil
    let identifier: String
    @State private var presented = false
    @State private var draft = Date()
    @State private var year = ""
    @State private var month = 1

    private var displayedValue: String {
        selection == nil && hasIncompleteValue ? "Incomplete saved date" : CandidateDateInput.display(selection, precision: precision)
    }

    private var proposed: Date? {
        precision == .day ? draft : CandidateDateInput.date(year: year, month: precision == .month ? month : 1)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title + (required ? " *" : " — Optional"))
                .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                .accessibilityHidden(true)
            Button {
                draft = selection ?? Date()
                year = String(CandidateDateInput.calendar.component(.year, from: draft))
                month = CandidateDateInput.calendar.component(.month, from: draft)
                presented = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(displayedValue)
                        Spacer(); Image(systemName: "calendar").accessibilityHidden(true)
                    }.font(KairoTypography.body)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(KairoActionStyle(role: .secondary)).disabled(disabled)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel("\(title), \(required ? "required" : "optional")")
            .accessibilityValue(displayedValue)
            if (selection != nil || hasIncompleteValue), !required {
                Button("Remove \(title.lowercased())", role: .destructive) { selection = nil }
                    .frame(minHeight: 44).accessibilityIdentifier(identifier + ".remove")
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(KairoColors.danger).fixedSize(horizontal: false, vertical: true) }
        }
        .sheet(isPresented: $presented) {
            NavigationStack {
                Form {
                    if precision == .day {
                        DatePicker(title, selection: $draft, displayedComponents: .date)
                            .datePickerStyle(.graphical).environment(\.timeZone, CandidateDateInput.calendar.timeZone)
                            .environment(\.calendar, CandidateDateInput.calendar)
                    } else {
                        if precision == .month {
                            Picker("Month", selection: $month) {
                                ForEach(1...12, id: \.self) { value in
                                    Text(CandidateDateInput.monthName(value)).tag(value)
                                }
                            }
                        }
                        TextField("Year", text: $year).keyboardType(.numberPad)
                            .accessibilityIdentifier(identifier + ".year")
                        Text("\(precision.title): \(CandidateDateInput.display(proposed, precision: precision))")
                        if proposed == nil { Text("Enter a year from 1 to 9999.").foregroundStyle(KairoColors.danger) }
                    }
                }
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { presented = false }.accessibilityIdentifier(identifier + ".cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use date") { if let proposed { selection = proposed; presented = false } }
                            .disabled(proposed == nil).accessibilityIdentifier(identifier + ".confirm")
                    }
                }
            }
        }
    }
}
