import SwiftUI
import UIKit

/// The first-run flow: a welcome, five short questions, the arithmetic on the
/// answer to one of them, and a hold-to-commit that hands over to the Screen
/// Time permission prompt.
///
/// One view with a step rather than a navigation stack, so the header — back,
/// progress, skip — stays put while only the page under it changes, and the
/// progress bar can fill in its next segment instead of being redrawn.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    let onFinish: () -> Void

    @State private var step: Step = .welcome
    @State private var forward = true
    @State private var band: ScreenTimeBand?
    @State private var committed = false
    @FocusState private var nameFocused: Bool

    enum Step: Int, CaseIterable {
        case welcome, name, why, about, screenTime, reveal, hour, setup

        /// Where Skip goes. The reveal and setup have none: one is the point of
        /// answering, the other is the last step.
        var skipTarget: Step? {
            switch self {
            case .name: return .why
            case .why: return .about
            case .about: return .screenTime
            case .screenTime: return .hour
            case .hour: return .setup
            default: return nil
            }
        }
    }

    private var firstName: String { model.profile.firstName ?? "" }

    private var nameBinding: Binding<String> {
        Binding(get: { model.profile.name }, set: { value in model.updateProfile { $0.name = value } })
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                header
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }
            ZStack {
                page
                    .id(step)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundColor(Theme.foreground)
        .onAppear {
            if band == nil, model.hasChosenBaseline { band = model.baselineBand }
        }
    }

    // MARK: - Navigation

    private func go(to next: Step) {
        nameFocused = false
        forward = next.rawValue > step.rawValue
        // Direction is set a beat before the step changes, so the page leaving
        // and the page arriving both pick up the new transition.
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)) { step = next }
        }
    }

    private var pageTransition: AnyTransition {
        let direction: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: .modifier(
                active: Shift(x: 24 * direction, opacity: 0),
                identity: Shift(x: 0, opacity: 1)
            ),
            removal: .modifier(
                active: Shift(x: -40 * direction, opacity: 0),
                identity: Shift(x: 0, opacity: 1)
            )
        )
    }

    private struct Shift: ViewModifier {
        let x: CGFloat
        let opacity: Double
        func body(content: Content) -> some View {
            content.offset(x: x).opacity(opacity)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) { go(to: previous) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, -14)
            .accessibilityLabel("Back")

            progressBar

            Group {
                if let target = step.skipTarget {
                    Button("Skip") { go(to: target) }
                        .font(.system(size: 15))
                        .foregroundColor(Theme.muted)
                        .buttonStyle(.plain)
                } else {
                    Color.clear
                }
            }
            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
        }
        .frame(height: 44)
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(1..<Step.allCases.count, id: \.self) { index in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule()
                        .fill(Theme.foreground)
                        .scaleEffect(x: index <= step.rawValue ? 1 : 0.0001, anchor: .leading)
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.6).delay(0.05), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue) of \(Step.allCases.count - 1)")
    }

    // MARK: - Pages

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome: welcome
        case .name: namePage
        case .why: whyPage
        case .about: aboutPage
        case .screenTime: screenTimePage
        case .reveal: RevealPage(band: band ?? .unanswered) { go(to: .hour) }
        case .hour: hourPage
        case .setup: setupPage
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Welcome to")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.muted)
                .rise(0.1)
            Text("ScreenSense")
                .font(Theme.display(46))
                .padding(.top, 10)
                .rise(0.18)
            Text("Put your time into the things you actually want to do.")
                .font(.system(size: 19))
                .lineSpacing(3)
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
                .rise(0.32)

            Spacer(minLength: 24)

            VStack(spacing: 0) {
                Rule()
                welcomeRow(1, "Block as many apps as you like").rise(0.6)
                welcomeRow(2, "Get a few breaks a day").rise(0.7)
                welcomeRow(3, "Note what you did instead").rise(0.8)
            }

            Button("Get started") { go(to: .name) }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 40)
                .rise(0.98)
            Text("Six questions, about a minute.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .rise(1.1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 54)
        .padding(.bottom, 16)
    }

    private func welcomeRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("\(number)")
                .font(Theme.display(22, .light))
                .foregroundColor(Theme.muted)
                .frame(width: 18, alignment: .leading)
            Text(text).font(.system(size: 17))
        }
        .ruledRow()
    }

    private var namePage: some View {
        QuestionPage(eyebrow: "First things", title: "What should we call you?") {
            VStack(alignment: .leading, spacing: 6) {
                Text("First name")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.muted)
                TextField("", text: nameBinding, prompt: Text("Your first name").foregroundColor(Theme.faint))
                    .font(Theme.display(30))
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($nameFocused)
                    .onSubmit { go(to: .why) }
                    .frame(height: 56)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.foreground).frame(height: 1)
                    }
            }
            .padding(.top, 40)
            .rise(0.3)
        } footer: {
            Button("Continue") { go(to: .why) }
                .buttonStyle(PillButtonStyle())
        }
    }

    private var whyPage: some View {
        QuestionPage(eyebrow: "Your reasons", title: "Why did you get ScreenSense?") {
            ReasonList(staggered: true)
                .padding(.top, 28)
        } footer: {
            Button("Continue") { go(to: .about) }
                .buttonStyle(PillButtonStyle())
        }
    }

    private static let roles: [(UserProfile.Role, String, String)] = [
        (.school, "In high school", "Study sessions up front, tagged by class"),
        (.college, "In college or university", "Study sessions up front, tagged by class"),
        (.work, "Working", "Focus blocks for the workday"),
        (.other, "Something else", "The plain version, nothing assumed"),
    ]

    private var aboutPage: some View {
        QuestionPage(
            eyebrow: "About you",
            title: "Which sounds most like you?",
            subtitle: "It decides what we ask when you jot down what you did instead."
        ) {
            VStack(spacing: 0) {
                Rule()
                ForEach(Array(Self.roles.enumerated()), id: \.element.0) { index, item in
                    OptionRow(
                        title: item.1,
                        subtitle: item.2,
                        selected: model.profile.role == item.0,
                        shape: .circle,
                        height: 72
                    ) { model.updateProfile { $0.role = item.0 } }
                    .rise(0.29 + Double(index) * 0.06)
                }
            }
            .padding(.top, 28)
        } footer: {
            Button("Continue") { go(to: .screenTime) }
                .buttonStyle(PillButtonStyle())
        }
    }

    private var screenTimePage: some View {
        QuestionPage(eyebrow: "Where you started", title: "How long do you spend on your phone a day?") {
            VStack(alignment: .leading, spacing: 0) {
                Rule()
                ForEach(Array(ScreenTimeBand.allCases.enumerated()), id: \.element.rawValue) { index, option in
                    OptionRow(
                        title: option.title,
                        selected: band == option,
                        shape: .circle,
                        height: 60
                    ) { band = option }
                    .rise(0.24 + Double(index) * 0.06)
                }
                Text("Not sure? Settings › Screen Time on your phone shows last week's daily average.")
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)
                    .rise(0.56)
            }
            .padding(.top, 28)
        } footer: {
            Button("Continue") {
                if let band { model.chooseBaseline(band) }
                go(to: .reveal)
            }
            .buttonStyle(PillButtonStyle())
            .disabled(band == nil)
        }
    }

    private static let activities: [(String, String)] = [
        ("study", "Study"), ("read", "Read"), ("sleep", "Sleep"), ("exercise", "Exercise"),
        ("friends", "See friends"), ("make", "Make something"), ("outside", "Get outside"),
        ("other", "Something else"),
    ]

    private var hourPage: some View {
        QuestionPage(
            eyebrow: "Instead",
            title: firstName.isEmpty
                ? "What would you do with an extra hour?"
                : "What would you do with an extra hour, \(firstName)?"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(Self.activities.enumerated()), id: \.element.0) { index, item in
                        ChoiceChip(
                            title: item.1,
                            selected: model.profile.activities.contains(item.0),
                            opensMore: item.0 == "other",
                            height: 44
                        ) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                model.updateProfile { $0.activities.toggle(item.0) }
                            }
                        }
                        .pop(0.2 + Double(index) * 0.055)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("How it shows up later")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.muted)
                    Text("After a study session or at the end of the day: “What did you do instead?” Tap one, add a line if you like. Your notes stay on this phone.")
                        .font(.system(size: 15))
                        .lineSpacing(3)
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rule() }
                .padding(.top, 36)
                .rise(0.7)
            }
            .padding(.top, 32)
        } footer: {
            Button("Continue") { go(to: .setup) }
                .buttonStyle(PillButtonStyle())
        }
    }

    private var setupPage: some View {
        let settings = model.settings
        return QuestionPage(
            eyebrow: "Your setup",
            title: firstName.isEmpty ? "Here's where you start." : "Here's where you start, \(firstName).",
            subtitle: "You can change any of this later."
        ) {
            VStack(spacing: 0) {
                Rule()
                setupRow("Breaks per day", "\(settings.breaksPerDay)").rise(0.32)
                setupRow("Each break lasts", "\(settings.breakMinutes) min").rise(0.4)
                setupRow("Wait between breaks", "\(settings.cooldownMinutes) min").rise(0.48)
                setupRow("Starting point", (band ?? model.baselineBand).title).rise(0.56)
            }
            .padding(.top, 24)
        } footer: {
            VStack(spacing: 14) {
                if committed {
                    Button("Allow Screen Time access") {
                        Task {
                            await model.requestAuthorization()
                            onFinish()
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                    .rise(0)
                    Text("You're in. Day one starts now.")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.streak)
                        .rise(0.12)
                } else {
                    HoldToCommitButton {
                        withAnimation(.easeOut(duration: 0.25)) { committed = true }
                    }
                    .rise(0.72)
                    Text("Next, iOS asks for Screen Time access. ScreenSense never sees which apps you pick.")
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .rise(0.8)
                }
            }
        }
    }

    private func setupRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(Theme.muted)
            Spacer(minLength: 12)
            Text(value).monospacedDigit()
        }
        .font(.system(size: 16))
        .ruledRow(padding: 14)
    }
}

/// The app's own defaults keys for onboarding. Only `completed` is still
/// written; the answers themselves live in `UserProfile`, in the App Group, and
/// the rest are read once to move an earlier build's answers across.
enum OnboardingKeys {
    static let completed = "onboarding.completed"
    static let legacyName = "onboarding.name"
    static let legacyReasons = "onboarding.reasons"
    static let legacyRole = "onboarding.role"
    static let legacyActivities = "onboarding.activities"
}

extension Array where Element: Equatable {
    /// Adds the element if it is missing, removes it if it is there.
    mutating func toggle(_ element: Element) {
        if let index = firstIndex(of: element) { remove(at: index) } else { append(element) }
    }
}

// MARK: - Reasons

/// The "why did you get ScreenSense" list, shared by onboarding and Settings.
/// Ticking Other opens a line under it for their own words.
struct ReasonList: View {
    @EnvironmentObject private var model: AppModel
    /// Onboarding brings the rows in one after another; Settings does not.
    var staggered = false
    @FocusState private var typing: Bool

    private var otherBinding: Binding<String> {
        Binding(
            get: { model.profile.otherReason },
            set: { value in model.updateProfile { $0.otherReason = value } }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Rule()
            ForEach(Array(UserProfile.Reason.allCases.enumerated()), id: \.element) { index, reason in
                OptionRow(
                    title: reason.title,
                    selected: model.profile.reasons.contains(reason),
                    shape: .square,
                    height: 56
                ) {
                    model.updateProfile { $0.reasons.toggle(reason) }
                    if reason == .other { typing = model.profile.reasons.contains(.other) }
                }
                .modifier(Rise(delay: staggered ? 0.24 + Double(index) * 0.055 : 0, enabled: staggered))

                if reason == .other, model.profile.reasons.contains(.other) {
                    otherField
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var otherField: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextField("", text: otherBinding, prompt: Text("What's your reason?").foregroundColor(Theme.faint))
                .font(.system(size: 17))
                .focused($typing)
                .submitLabel(.done)
                .onSubmit { typing = false }
                .frame(height: 44)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(typing ? Theme.foreground : Theme.hairline).frame(height: 1)
                }
            Text("\(model.profile.otherReason.count)/\(UserProfile.otherReasonLimit)")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundColor(Theme.faint)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rule() }
    }
}

// MARK: - Question page

/// The shared layout of a question: eyebrow, serif question, optional line
/// under it, the answers, and a footer pinned to the bottom.
private struct QuestionPage<Content: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.muted)
                .rise(0.06)
            Text(title)
                .font(Theme.display(30))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
                .rise(0.11)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .rise(0.2)
            }
            content
            Spacer(minLength: 24)
            footer.rise(0.5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
    }
}

// MARK: - Option row

/// One answer in a ruled list, with a tick box (multi-select) or a radio
/// (single). Colours ease between states rather than snapping.
struct OptionRow: View {
    enum Shape { case square, circle }

    let title: String
    var subtitle: String?
    let selected: Bool
    let shape: Shape
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(selected ? Theme.foreground : Theme.muted)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                    }
                }
                Spacer(minLength: 0)
                mark
            }
            .padding(.vertical, subtitle == nil ? 0 : 12)
            .frame(minHeight: height)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rule() }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var mark: some View {
        let radius: CGFloat = shape == .circle ? 11 : 6
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(selected ? Theme.foreground : Color.clear)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(selected ? Theme.foreground : Theme.hairline, lineWidth: 1)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.background)
                .scaleEffect(selected ? 1 : 0.4)
                .opacity(selected ? 1 : 0)
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - The arithmetic

/// The answer to "how long on your phone", turned into a year. The big number
/// counts up from zero and warms to ember when it lands; the rows under it
/// follow one at a time, each counting up as it arrives.
private struct RevealPage: View {
    let band: ScreenTimeBand
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var days: Double = 0
    @State private var hoursYear: Double = 0
    @State private var perWakingHour: Double = 0
    @State private var tenYears: Double = 0
    @State private var fiftyYears: Double = 0
    @State private var landed = false

    /// A single representative figure per band, and how it reads in a sentence.
    private var hoursPerDay: (Double, String) {
        switch band {
        case .underTwo: return (1.5, "an hour and a half")
        case .twoToThree: return (2.5, "2 and a half hours")
        case .threeToSix: return (4, "4 hours")
        case .overSix: return (7, "7 hours")
        }
    }

    private var target: (days: Double, hours: Double, waking: Double, ten: Double, fifty: Double) {
        let hours = hoursPerDay.0
        return (
            days: (hours * 365 / 24).rounded(),
            hours: hours * 365,
            // About sixteen hours awake a day.
            waking: (hours / 16 * 60).rounded(),
            ten: hours * 10 / 24,
            fifty: hours * 50 / 24
        )
    }

    var body: some View {
        let goal = target
        VStack(alignment: .leading, spacing: 0) {
            Text("The arithmetic")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.muted)
                .rise(0.06)
            Text("At about \(hoursPerDay.1) a day, here is your year.")
                .font(Theme.display(30))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .rise(0.11)

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                CountingText(value: days) { "\(Int($0.rounded()))" }
                    .font(Theme.numeral(120))
                    .foregroundColor(landed ? Theme.streak : Theme.foreground)
                    .frame(minWidth: 132, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("days a year").font(.system(size: 17))
                    Text("on your phone, around the clock")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.muted)
                }
            }
            .padding(.top, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(goal.days)) days a year on your phone, around the clock")
            .rise(0.26)

            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surface)
                        Capsule()
                            .fill(Theme.streak)
                            .frame(width: geo.size.width * CGFloat(days / 365))
                    }
                }
                .frame(height: 4)
                HStack {
                    Text("Jan")
                    Spacer()
                    CountingText(value: days) { "\(Int($0.rounded())) of 365 days" }
                }
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundColor(Theme.muted)
            }
            .padding(.top, 20)
            .accessibilityHidden(true)
            .rise(0.3)

            VStack(spacing: 0) {
                Rule()
                revealRow("Hours a year", hoursYear) { Int($0.rounded()).formatted() }
                    .rise(1.7)
                revealRow("Of every hour you're awake", perWakingHour) { "\(Int($0.rounded())) min" }
                    .rise(1.85)
                revealRow("Over the next 10 years", tenYears) { String(format: "%.1f years", $0) }
                    .rise(2.0)
                revealRow("Over the next 50 years", fiftyYears) { String(format: "%.1f years", $0) }
                    .rise(2.15)
            }
            .padding(.top, 24)

            Text("Win back half of it and that is \(Int((goal.days / 2).rounded())) days a year.")
                .font(.system(size: 17))
                .lineSpacing(2)
                .foregroundColor(Theme.streak)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
                .rise(2.9)

            Spacer(minLength: 24)

            Button("Let's get some back", action: onContinue)
                .buttonStyle(PillButtonStyle())
                .rise(3.15)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
        .onAppear(perform: play)
    }

    private func revealRow(_ title: String, _ value: Double, _ format: @escaping (Double) -> String) -> some View {
        HStack {
            Text(title).foregroundColor(Theme.muted)
            Spacer(minLength: 12)
            CountingText(value: value, format: format).monospacedDigit()
        }
        .font(.system(size: 16))
        .frame(height: 50)
        .overlay(alignment: .bottom) { Rule() }
    }

    private func play() {
        let goal = target
        guard !reduceMotion else {
            days = goal.days
            hoursYear = goal.hours
            perWakingHour = goal.waking
            tenYears = goal.ten
            fiftyYears = goal.fifty
            landed = true
            return
        }
        // Rushes up, then slows into the final figure.
        let climb = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 1.5).delay(0.38)
        withAnimation(climb) { days = goal.days }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.8).delay(1.78)) { hoursYear = goal.hours }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.6).delay(1.93)) { perWakingHour = goal.waking }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.7).delay(2.08)) { tenYears = goal.ten }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.8).delay(2.23)) { fiftyYears = goal.fifty }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeInOut(duration: 0.9)) { landed = true }
        }
    }
}

/// Text that redraws on every frame of an animation of `value`, so a figure
/// counts through the numbers in between rather than cross-fading to the end.
private struct CountingText: View, Animatable {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { Text(format(value)) }
}

// MARK: - Hold to commit

/// A pill that fills while it is held and commits when full. Let go early and
/// the fill drains back. VoiceOver and Switch Control get a plain action, since
/// there is no hold to perform there.
private struct HoldToCommitButton: View {
    let onCommit: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var done = false
    @State private var pending: DispatchWorkItem?

    private let duration = 1.1

    var body: some View {
        ZStack {
            Theme.raised
            GeometryReader { geo in
                Theme.foreground.frame(width: geo.size.width * progress)
            }
            Text("Hold to commit")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.foreground)
                .blendMode(.difference)
        }
        .compositingGroup()
        .frame(height: 50)
        .clipShape(Capsule())
        .scaleEffect(holding ? 0.98 : 1)
        .animation(.easeOut(duration: 0.15), value: holding)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding && !done { begin() } }
                .onEnded { _ in release() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to commit")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
    }

    private func begin() {
        holding = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.linear(duration: duration)) { progress = 1 }
        let work = DispatchWorkItem { if holding { commit() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func release() {
        holding = false
        pending?.cancel()
        guard !done else { return }
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.35)) { progress = 0 }
    }

    private func commit() {
        guard !done else { return }
        done = true
        holding = false
        progress = 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCommit()
    }
}

// MARK: - Entrances

/// Fades a piece of a page in and lifts it into place, after `delay` seconds,
/// so a page arrives top to bottom rather than all at once.
struct Rise: ViewModifier {
    let delay: Double
    var scale = false
    /// Off shows the content straight away, for lists reused outside onboarding.
    var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        if enabled { animated(content) } else { content }
    }

    private func animated(_ content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion || scale ? 0 : 16)
            .scaleEffect(shown || reduceMotion || !scale ? 1 : 0.92)
            .onAppear {
                guard !shown else { return }
                let animation: Animation = scale
                    ? .spring(response: 0.45, dampingFraction: 0.7)
                    : .timingCurve(0.16, 1, 0.3, 1, duration: 0.62)
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : animation.delay(delay)) {
                    shown = true
                }
            }
    }
}

private extension View {
    func rise(_ delay: Double) -> some View { modifier(Rise(delay: delay)) }
    func pop(_ delay: Double) -> some View { modifier(Rise(delay: delay, scale: true)) }
}
