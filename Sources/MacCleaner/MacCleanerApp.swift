import AppKit
import Foundation
import MacCleanerCore
import SwiftUI

@main
enum MacCleanerLauncher {
    static func main() {
        if let langIdx = CommandLine.arguments.firstIndex(of: "--lang"),
           CommandLine.arguments.indices.contains(langIdx + 1),
           let lang = AppLanguage(rawValue: CommandLine.arguments[langIdx + 1].lowercased()) {
            L10n.language = lang
        } else if CommandLine.arguments.contains("--lang=en") {
            L10n.language = .en
        }

        if CommandLine.arguments.contains("--scan-summary") {
            let exitCode = runReadOnlyCLISummary()
            exit(exitCode)
        } else if let idx = CommandLine.arguments.firstIndex(of: "--record-demo") {
            let outputPath = CommandLine.arguments.indices.contains(idx + 1)
                ? CommandLine.arguments[idx + 1]
                : FileManager.default.currentDirectoryPath + "/demo/maccleaner-linkedin.mp4"
            MainActor.assumeIsolated {
                let exitCode = DemoRecorder.run(outputPath: outputPath)
                exit(exitCode)
            }
        } else {
            MacCleanerSwiftUIApp.main()
        }
    }

    private static func runReadOnlyCLISummary() -> Int32 {
        final class SummaryBox: @unchecked Sendable {
            var summary: ScanSummary?
        }

        let box = SummaryBox()
        let semaphore = DispatchSemaphore(value: 0)
        let exclusions = ExclusionsStore().load()

        Task.detached {
            let rules = RuleCatalog.defaultRules(staleDays: 30)
            let scanner = ScannerEngine()
            box.summary = await scanner.scan(rules: rules, exclusions: exclusions)
            semaphore.signal()
        }

        semaphore.wait()

        guard let summary = box.summary else {
            fputs("Falha ao executar scan.\n", stderr)
            return 1
        }

        print("=== MacCleaner — Resumo de Scan (Somente Leitura) ===")
        print(
            String(
                format: "Disco: %@ livres de %@ (usados: %@) | Duração: %.2fs",
                ByteFormatting.string(fromBytes: summary.diskSpace.availableBytes),
                ByteFormatting.string(fromBytes: summary.diskSpace.totalBytes),
                ByteFormatting.string(fromBytes: summary.diskSpace.usedBytes),
                summary.durationSeconds
            )
        )
        print("Total encontrado: \(ByteFormatting.string(fromBytes: summary.totalBytes))")
        print("Total seguro:     \(ByteFormatting.string(fromBytes: summary.safeBytes))")
        if summary.totalSkippedPermissions > 0 {
            print("Itens ignorados por permissão (Full Disk Access): \(summary.totalSkippedPermissions)")
        }
        print("")
        print("Por categoria:")
        for category in CleanerCategory.allCases {
            let bytes = summary.bytes(for: category)
            if bytes > 0 {
                print("  - \(category.displayName): \(ByteFormatting.string(fromBytes: bytes))")
            }
        }
        print("")
        print("Maiores itens:")
        for entry in summary.topEntries.prefix(10) {
            let flag = entry.isProtected ? " [protegido]" : ""
            print("  - \(ByteFormatting.string(fromBytes: entry.sizeBytes))\t\(entry.url.path)\(flag)")
        }
        return 0
    }
}

struct MacCleanerSwiftUIApp: App {
    private let viewModel = AppViewModel()
    @Environment(\.openWindow) private var openWindow

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("MacCleaner", id: "main") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 860, minHeight: 560)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    viewModel.startScanIfNeeded()
                }
        }
        .defaultSize(width: 1040, height: 700)

        MenuBarExtra("MacCleaner", systemImage: "sparkles.rectangle.stack") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Espaço livre: \(ByteFormatting.string(fromBytes: viewModel.diskSpace.availableBytes))")
                    .font(.headline)

                if let summary = viewModel.scanSummary {
                    Text("Recuperável: \(ByteFormatting.string(fromBytes: summary.totalBytes))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Seguro: \(ByteFormatting.string(fromBytes: summary.safeBytes))")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if viewModel.isScanning {
                    Text("Escaneando disco...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nenhum scan realizado ainda")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button("Abrir MacCleaner") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }

                Button("Escanear Agora") {
                    viewModel.startScan()
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                Divider()

                Button("Sair") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(6)
        }
    }
}
