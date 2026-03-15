//
//  ExportService.swift
//  LedgerFinance
//
//  CSV and PDF export functionality
//

import Foundation
import UIKit

// MARK: - Export Format
enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case pdf = "pdf"

    var displayName: String {
        switch self {
        case .csv: return "CSV Spreadsheet"
        case .pdf: return "PDF Report"
        }
    }

    var systemImage: String {
        switch self {
        case .csv: return "tablecells"
        case .pdf: return "doc.richtext"
        }
    }

    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .pdf: return "application/pdf"
        }
    }

    var fileExtension: String { rawValue }
}

// MARK: - Export Options
struct ExportOptions {
    var format: ExportFormat = .csv
    var dateRange: ClosedRange<Date>?
    var includeIncome: Bool = true
    var includeExpenses: Bool = true
    var includeTransfers: Bool = false
    var groupByCategory: Bool = false
    var includeBudgets: Bool = false
    var includeNetWorth: Bool = false
    var filename: String = "ledger-export"
}

// MARK: - Export Service
@MainActor
final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - CSV Export
    func exportCSV(
        transactions: [Transaction],
        categories: [Category],
        accounts: [Account],
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        var rows: [String] = []

        // Header
        let header = "Date,Type,Title,Amount,Category,Account,Notes,Tags"
        rows.append(header)

        // Filter transactions
        var filtered = transactions

        if !options.includeIncome {
            filtered = filtered.filter { $0.type != .income }
        }
        if !options.includeExpenses {
            filtered = filtered.filter { $0.type != .expense }
        }
        if !options.includeTransfers {
            filtered = filtered.filter { $0.type != .transfer }
        }

        if let range = options.dateRange {
            filtered = filtered.filter { range.contains($0.date) }
        }

        filtered = filtered.sorted { $0.date > $1.date }

        // Build category and account lookups
        let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let accMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })

        // Date formatter
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        // Rows
        for t in filtered {
            let date = df.string(from: t.date)
            let type = t.type.displayName
            let title = "\"\(t.title.replacingOccurrences(of: "\"", with: "\"\""))\""
            let amount = String(format: "%.2f", t.amount)
            let category = t.categoryID.flatMap { catMap[$0] } ?? ""
            let account = t.accountID.flatMap { accMap[$0] } ?? ""
            let notes = "\"\(t.notes.replacingOccurrences(of: "\"", with: "\"\""))\""
            let tags = t.tags.joined(separator: ";")

            rows.append("\(date),\(type),\(title),\(amount),\(category),\(account),\(notes),\(tags)")
        }

        let csvString = rows.joined(separator: "\n")
        return csvString.data(using: .utf8)
    }

    // MARK: - PDF Export
    func exportPDF(
        transactions: [Transaction],
        categories: [Category],
        accounts: [Account],
        budgetSummaries: [BudgetSummary] = [],
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext
            _ = cgContext // suppress unused warning

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.systemBlue
            ]
            let title = NSAttributedString(string: "Ledger — Financial Report", attributes: titleAttrs)
            title.draw(at: CGPoint(x: 40, y: 40))

            // Date
            let df = DateFormatter()
            df.dateStyle = .long
            let dateStr = "Generated: \(df.string(from: Date()))"
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.systemGray
            ]
            let dateText = NSAttributedString(string: dateStr, attributes: dateAttrs)
            dateText.draw(at: CGPoint(x: 40, y: 72))

            // Summary section
            var filtered = transactions
            if let range = options.dateRange {
                filtered = filtered.filter { range.contains($0.date) }
            }

            let income = filtered.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let expenses = filtered.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let net = income - expenses

            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]

            let curr = NumberFormatter()
            curr.numberStyle = .currency
            curr.currencyCode = "USD"

            let summary = """
            Summary
            Total Income:   \(curr.string(from: NSNumber(value: income)) ?? "$0")
            Total Expenses: \(curr.string(from: NSNumber(value: expenses)) ?? "$0")
            Net Balance:    \(curr.string(from: NSNumber(value: net)) ?? "$0")
            """

            let summaryText = NSAttributedString(string: summary, attributes: summaryAttrs)
            summaryText.draw(in: CGRect(x: 40, y: 100, width: 532, height: 120))

            // Transactions table header
            var y: CGFloat = 250
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.white
            ]
            UIColor.systemBlue.setFill()
            UIBezierPath(rect: CGRect(x: 40, y: y, width: 532, height: 20)).fill()

            NSAttributedString(string: "Date", attributes: headerAttrs).draw(at: CGPoint(x: 45, y: y + 4))
            NSAttributedString(string: "Description", attributes: headerAttrs).draw(at: CGPoint(x: 115, y: y + 4))
            NSAttributedString(string: "Category", attributes: headerAttrs).draw(at: CGPoint(x: 310, y: y + 4))
            NSAttributedString(string: "Amount", attributes: headerAttrs).draw(at: CGPoint(x: 480, y: y + 4))

            y += 24

            // Transaction rows
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.label
            ]
            let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            let shortDf = DateFormatter()
            shortDf.dateFormat = "MM/dd/yy"

            var rowIndex = 0
            for t in filtered.prefix(40).sorted(by: { $0.date > $1.date }) {
                if rowIndex % 2 == 1 {
                    UIColor.systemGray6.setFill()
                    UIBezierPath(rect: CGRect(x: 40, y: y - 2, width: 532, height: 16)).fill()
                }
                let sign = t.type == .income ? "+" : "-"
                let amountStr = "\(sign)\(curr.string(from: NSNumber(value: t.amount)) ?? "$0")"
                let catName = t.categoryID.flatMap { catMap[$0] } ?? "—"

                NSAttributedString(string: shortDf.string(from: t.date), attributes: rowAttrs).draw(at: CGPoint(x: 45, y: y))
                NSAttributedString(string: String(t.title.prefix(28)), attributes: rowAttrs).draw(at: CGPoint(x: 115, y: y))
                NSAttributedString(string: String(catName.prefix(20)), attributes: rowAttrs).draw(at: CGPoint(x: 310, y: y))
                NSAttributedString(string: amountStr, attributes: rowAttrs).draw(at: CGPoint(x: 480, y: y))

                y += 16
                rowIndex += 1

                if y > 730 { break }
            }
        }

        return data
    }

    // MARK: - Share
    func shareURL(for data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to write export file: \(error)")
            return nil
        }
    }
}
