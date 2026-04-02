import SwiftUI

struct CleanView: View {
    @EnvironmentObject private var mole: MoleService
    @State private var categories: [CleanCategory] = []
    @State private var scanResult: CleanScanResult?
    @State private var phase: Phase = .idle
    @State private var cleanOutput: String = ""
    @State private var error: String?

    enum Phase {
        case idle, scanning, scanned, cleaning, done
    }

    var selectedCategories: [CleanCategory] {
        categories.filter { $0.selected && $0.sizeKb > 0 }
    }

    var selectedSize: Int {
        selectedCategories.reduce(0) { $0 + $1.sizeKb }
    }

    var maxCategorySize: Int {
        categories.map(\.sizeKb).max() ?? 1
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            switch phase {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .scanned:
                categoryList
            case .cleaning:
                cleaningView
            case .done:
                doneView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    // MARK: - Header

    private var header: some View {
        ViewHeader(icon: "trash", title: "Clean") {
            if let scan = scanResult {
                Text("\(scan.architecture) | Free: \(scan.freeSpace)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
            }
            if phase == .scanned {
                Button {
                    startClean()
                } label: {
                    Label("Clean \(formatBytes(kb: selectedSize))", systemImage: "sparkles")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoleColors.danger)
                .disabled(selectedCategories.isEmpty)
            }
            if phase == .idle || phase == .done {
                Button {
                    startScan()
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoleColors.accent)
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(MoleColors.accent)
            }
            .pulseEffect()
            Text("Scan your Mac")
                .font(.title3.bold())
            Text("Find and remove caches, logs, and temporary files to free up space.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            if let error {
                Text(error)
                    .foregroundStyle(MoleColors.danger)
                    .font(.caption)
                    .padding(8)
                    .cardStyle(padding: 8)
            }
            Spacer()
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(MoleColors.accent)
            }
            Text("Scanning...")
                .font(.title3.bold())
            Text("Checking all cleanup categories")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Category List

    private var categoryList: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                Button(allSelected ? "Deselect All" : "Select All") {
                    let newValue = !allSelected
                    for i in categories.indices {
                        if categories[i].sizeKb > 0 {
                            categories[i].selected = newValue
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(MoleColors.accent)
                .font(.subheadline.weight(.medium))

                Spacer()

                HStack(spacing: 6) {
                    Text("\(selectedCategories.count)")
                        .fontWeight(.bold)
                        .foregroundStyle(MoleColors.accent)
                    Text("selected")
                        .foregroundStyle(.secondary)
                    Text("|")
                        .foregroundStyle(.quaternary)
                    Text(formatBytes(kb: selectedSize))
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedSize > 1_048_576 ? MoleColors.danger :
                            selectedSize > 102_400 ? MoleColors.warning : .primary)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(categories.indices, id: \.self) { i in
                        CategoryCard(
                            category: $categories[i],
                            maxSize: maxCategorySize
                        )
                        .hoverEffect()
                        .appearAnimation(delay: Double(i) * 0.04)
                    }
                }
                .padding(16)
            }
        }
    }

    private var allSelected: Bool {
        categories.filter { $0.sizeKb > 0 }.allSatisfy { $0.selected }
    }

    // MARK: - Cleaning

    private var cleaningView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.danger.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(MoleColors.danger)
            }
            Text("Cleaning...")
                .font(.title3.bold())
            Text("\(selectedCategories.count) categories selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(MoleColors.success)
            }
            Text("Cleanup Complete")
                .font(.title3.bold())

            if !cleanOutput.isEmpty {
                ScrollView {
                    Text(cleanOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .cardStyle()
                .padding(.horizontal, 20)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func startScan() {
        phase = .scanning
        error = nil
        Task {
            do {
                let result = try await mole.scanClean()
                scanResult = result
                categories = result.categories
                phase = .scanned
            } catch {
                self.error = error.localizedDescription
                phase = .idle
            }
        }
    }

    private func startClean() {
        let names = selectedCategories.map(\.name)
        phase = .cleaning
        Task {
            do {
                let output = try await mole.runClean(categories: names)
                cleanOutput = stripAnsi(output)
                phase = .done
            } catch {
                self.error = error.localizedDescription
                phase = .scanned
            }
        }
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    @Binding var category: CleanCategory
    let maxSize: Int

    private var fraction: Double {
        guard maxSize > 0 else { return 0 }
        return Double(category.sizeKb) / Double(maxSize)
    }

    private var color: Color {
        categoryColor(category.name)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: categoryIcon(category.name))
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.name)
                        .fontWeight(.medium)
                    Spacer()
                    Text(category.sizeFormatted)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(category.sizeKb > 1_048_576 ? MoleColors.danger :
                            category.sizeKb > 102_400 ? MoleColors.warning : .primary)
                }

                HStack(spacing: 8) {
                    SizeBar(fraction: fraction, color: color)
                    Text("\(category.items) items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 55, alignment: .trailing)
                }
            }

            // Toggle
            Toggle(isOn: $category.selected) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .tint(color)
            .disabled(category.sizeKb == 0)
            .scaleEffect(0.75)
            .frame(width: 40)
        }
        .padding(12)
        .background(category.selected && category.sizeKb > 0 ? color.opacity(0.04) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(category.selected && category.sizeKb > 0 ? color.opacity(0.2) : MoleColors.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(category.sizeKb == 0 ? 0.4 : 1.0)
    }
}

/// Strip ANSI escape codes from CLI output.
func stripAnsi(_ text: String) -> String {
    text.replacingOccurrences(
        of: "\\x1B\\[[0-9;]*[a-zA-Z]",
        with: "",
        options: .regularExpression
    )
    .replacingOccurrences(
        of: "\u{1B}\\[[0-9;]*[a-zA-Z]",
        with: "",
        options: .regularExpression
    )
}
