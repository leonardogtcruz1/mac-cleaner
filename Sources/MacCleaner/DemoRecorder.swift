import AppKit
import CoreText
import Foundation
import MacCleanerCore
import SwiftUI

private enum DemoOverlayMode {
    case none
    case dryRunConfirmation
    case cleanResult(CleanReport)
}

private struct DemoStageView: View {
    @Bindable var viewModel: AppViewModel
    let overlayMode: DemoOverlayMode

    var body: some View {
        ZStack {
            ContentView(viewModel: viewModel)

            switch overlayMode {
            case .none:
                EmptyView()
            case .dryRunConfirmation:
                Color.black.opacity(0.50)
                    .ignoresSafeArea()
                DryRunConfirmationSheet(viewModel: viewModel)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 28, y: 12)
            case .cleanResult(let report):
                Color.black.opacity(0.50)
                    .ignoresSafeArea()
                CleanResultSheet(report: report, onDismiss: {})
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 28, y: 12)
            }
        }
    }
}

private final class DemoStageHolder: @unchecked Sendable {
    var overlayMode: DemoOverlayMode = .none
}

@MainActor
enum DemoRecorder {
    private static let outputWidth = 1920
    private static let outputHeight = 1080
    private static let fps = 30
    private static let windowSize = NSSize(width: 1180, height: 700)

    static func run(outputPath: String) -> Int32 {
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            fputs("Erro ao criar diretório de saída: \(error.localizedDescription)\n", stderr)
            return 1
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .darkAqua)

        let suiteName = "MacCleanerDemo-\(UUID().uuidString)"
        let demoDefaults = UserDefaults(suiteName: suiteName)!
        defer { demoDefaults.removePersistentDomain(forName: suiteName) }

        let viewModel = AppViewModel(exclusionsStore: ExclusionsStore(userDefaults: demoDefaults, key: "demoExclusions"))
        let stageHolder = DemoStageHolder()

        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: 40, y: 80), size: windowSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "MacCleaner"
        window.isReleasedWhenClosed = false

        func refreshHostingView() {
            let rootView = DemoStageView(viewModel: viewModel, overlayMode: stageHolder.overlayMode)
                .preferredColorScheme(.dark)
                .frame(width: windowSize.width, height: windowSize.height)

            let hosting = NSHostingView(rootView: rootView)
            hosting.appearance = NSAppearance(named: .darkAqua)
            hosting.frame = NSRect(origin: .zero, size: windowSize)
            window.contentView = hosting
        }

        let demoData = buildDemoDataset()
        viewModel.diskSpace = demoData.initialDisk
        viewModel.scanSummary = nil
        viewModel.isScanning = true
        viewModel.scanProgress = 0.08
        viewModel.scanStatusText = L10n.t("Iniciando varredura...", "Starting scan...")
        viewModel.sidebarSelection = .overview
        stageHolder.overlayMode = .none

        refreshHostingView()
        window.orderFrontRegardless()
        pumpRunLoop(seconds: 0.35)

        let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
        guard FileManager.default.isExecutableFile(atPath: ffmpegPath) else {
            fputs("ffmpeg não encontrado em \(ffmpegPath)\n", stderr)
            return 1
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-y",
            "-f", "rawvideo",
            "-pix_fmt", "rgba",
            "-s", "\(outputWidth)x\(outputHeight)",
            "-r", "\(fps)",
            "-i", "-",
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "18",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            outputURL.path
        ]

        let pipe = Pipe()
        process.standardInput = pipe
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            fputs("Falha ao iniciar ffmpeg: \(error.localizedDescription)\n", stderr)
            return 1
        }

        let stdinHandle = pipe.fileHandleForWriting

        // Helper to capture the current window content as a high-DPI CGImage
        func captureCurrentWindowImage() -> CGImage? {
            refreshHostingView()
            pumpRunLoop(seconds: 0.16)
            window.displayIfNeeded()
            guard let contentView = window.contentView else { return nil }
            contentView.layoutSubtreeIfNeeded()
            pumpRunLoop(seconds: 0.08)

            let bounds = contentView.bounds
            let pixelWidth = Int(bounds.width * 2)
            let pixelHeight = Int(bounds.height * 2)
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else {
                return nil
            }
            rep.size = bounds.size
            contentView.cacheDisplay(in: bounds, to: rep)
            return rep.cgImage
        }

        var composedFrames: [(image: CGImage, caption: String, durationSeconds: Double)] = []

        // Scene 1: Scanning animation
        let scanSteps: [(Double, String)] = [
            (0.08, L10n.t("Escaneando: Antigravity — Caches & Updater", "Scanning: Antigravity — Caches & Updater")),
            (0.14, L10n.t("Escaneando: Gemini — Temporários & Cache", "Scanning: Gemini — Temp Files & Cache")),
            (0.22, L10n.t("Escaneando: Claude Code — Caches, Backups & Debug", "Scanning: Claude Code — Caches, Backups & Debug")),
            (0.30, L10n.t("Escaneando: OpenAI Codex — Cache & Temporários", "Scanning: OpenAI Codex — Cache & Temp Files")),
            (0.38, L10n.t("Escaneando: Cursor — Caches de Editor & Electron", "Scanning: Cursor — Editor & Electron Caches")),
            (0.46, L10n.t("Escaneando: HuggingFace Hub — Modelos em Cache", "Scanning: HuggingFace Hub — Cached Models")),
            (0.54, L10n.t("Escaneando: npm — Cache & Pacotes npx", "Scanning: npm — Cache & npx Packages")),
            (0.62, L10n.t("Escaneando: Puppeteer — Browsers Baixados", "Scanning: Puppeteer — Downloaded Browsers")),
            (0.70, L10n.t("Escaneando: Swift Package Manager — Cache", "Scanning: Swift Package Manager — Cache")),
            (0.78, L10n.t("Escaneando: Homebrew & pip", "Scanning: Homebrew & pip")),
            (0.86, L10n.t("Escaneando: CoreSimulator — Dispositivos", "Scanning: CoreSimulator — Devices")),
            (0.94, L10n.t("Escaneando: Projetos Parados (node_modules / .venv)", "Scanning: Stale Projects (node_modules / .venv)")),
            (1.00, L10n.t("Finalizando cálculo de espaço...", "Finalizing space calculation..."))
        ]

        let scene1Caption = L10n.t(
            "1. Scan paralelo de caches de agentes de IA, Dev e macOS",
            "1. Parallel scan of AI agent, dev & macOS caches"
        )
        for (index, step) in scanSteps.enumerated() {
            viewModel.isScanning = true
            viewModel.scanProgress = step.0
            viewModel.scanStatusText = step.1
            if let img = captureCurrentWindowImage() {
                let dur = index == scanSteps.count - 1 ? 0.40 : 0.30
                composedFrames.append((img, scene1Caption, dur))
            }
        }

        // Scene 2: Overview completed (5.5s)
        viewModel.isScanning = false
        viewModel.scanProgress = 1.0
        viewModel.scanStatusText = L10n.t("Concluído em 1,4s", "Completed in 1.4s")
        viewModel.scanSummary = demoData.summary
        viewModel.selectedEntryIDs = demoData.defaultSelectedIDs
        viewModel.sidebarSelection = .overview
        stageHolder.overlayMode = .none
        if let img = captureCurrentWindowImage() {
            composedFrames.append((
                img,
                L10n.t(
                    "2. 39 GB encontrados — organizados por categoria e risco",
                    "2. 39 GB found — grouped by category and risk level"
                ),
                5.5
            ))
        }

        // Scene 3: AI Agents & IDEs category (5.0s)
        viewModel.sidebarSelection = .category(.aiAgents)
        viewModel.expandedRuleIDs = [
            "ai-antigravity-caches",
            "ai-gemini-recordings",
            "ai-claude-sessions",
            "ai-codex-caches"
        ]
        if let img = captureCurrentWindowImage() {
            composedFrames.append((
                img,
                L10n.t(
                    "3. Caches de agentes de IA sem tocar em sessões ou .env",
                    "3. Clean AI agent caches without touching sessions or .env"
                ),
                5.0
            ))
        }

        // Scene 4: Dev & Packages category (4.5s)
        viewModel.sidebarSelection = .category(.devCaches)
        viewModel.expandedRuleIDs = [
            "dev-npm-cache",
            "dev-puppeteer",
            "dev-swiftpm-cache",
            "dev-pip-cache"
        ]
        if let img = captureCurrentWindowImage() {
            composedFrames.append((
                img,
                L10n.t(
                    "4. Quase 15 GB só em caches recriáveis de pacotes dev",
                    "4. Nearly 15 GB in safely recreatable dev package caches"
                ),
                4.5
            ))
        }

        // Scene 5: Mandatory Dry-Run Confirmation Sheet (4.0s)
        viewModel.sidebarSelection = .overview
        stageHolder.overlayMode = .dryRunConfirmation
        if let img = captureCurrentWindowImage() {
            composedFrames.append((
                img,
                L10n.t(
                    "5. Preview obrigatório + Lixeira por padrão — zero sustos",
                    "5. Mandatory dry-run preview + Trash by default — zero risk"
                ),
                4.0
            ))
        }

        // Scene 6: Clean Result Sheet + updated disk space (3.8s)
        viewModel.diskSpace = demoData.afterCleanDisk
        viewModel.scanSummary = demoData.afterCleanSummary
        viewModel.selectedEntryIDs = []
        stageHolder.overlayMode = .cleanResult(demoData.cleanReport)
        if let img = captureCurrentWindowImage() {
            composedFrames.append((
                img,
                L10n.t(
                    "6. 14 GB liberados com segurança — nativo em Swift + SwiftUI",
                    "6. ~14 GB reclaimed safely — native Swift + SwiftUI app"
                ),
                3.8
            ))
        }

        // Pre-render each scene canvas and cross-dissolve smoothly into ffmpeg
        var previousCanvas: [UInt8]?
        let transitionFrames = 9 // ~0.30s dissolve between major scenes (skip for rapid progress steps)

        for (idx, item) in composedFrames.enumerated() {
            guard let canvas = renderStudioCanvas(windowImage: item.image, caption: item.caption) else {
                continue
            }

            let isProgressStep = idx > 0 && idx < scanSteps.count
            let totalFramesForItem = max(1, Int((item.durationSeconds * Double(fps)).rounded()))

            if let prev = previousCanvas, !isProgressStep {
                let blendCount = min(transitionFrames, totalFramesForItem)
                for step in 1...blendCount {
                    let alpha = Float(step) / Float(blendCount + 1)
                    let blended = blendRGBA(from: prev, to: canvas, t: alpha)
                    writeFrame(blended, to: stdinHandle)
                }
                let holdCount = max(1, totalFramesForItem - blendCount)
                for _ in 0..<holdCount {
                    writeFrame(canvas, to: stdinHandle)
                }
            } else {
                for _ in 0..<totalFramesForItem {
                    writeFrame(canvas, to: stdinHandle)
                }
            }

            previousCanvas = canvas
        }

        try? stdinHandle.close()
        process.waitUntilExit()
        window.close()

        if process.terminationStatus != 0 {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            fputs("ffmpeg falhou (\(process.terminationStatus)):\n\(errStr)\n", stderr)
            return 1
        }

        print("Vídeo demo gravado com sucesso em: \(outputURL.path)")
        return 0
    }

    private static func pumpRunLoop(seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private static func writeFrame(_ bytes: [UInt8], to handle: FileHandle) {
        bytes.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: base), count: ptr.count, deallocator: .none)
                try? handle.write(contentsOf: data)
            }
        }
    }

    private static func blendRGBA(from: [UInt8], to: [UInt8], t: Float) -> [UInt8] {
        let count = min(from.count, to.count)
        var out = [UInt8](repeating: 255, count: count)
        let inv = 1.0 - t
        for i in stride(from: 0, to: count, by: 4) {
            out[i]     = UInt8(clamping: Int(Float(from[i])     * inv + Float(to[i])     * t))
            out[i + 1] = UInt8(clamping: Int(Float(from[i + 1]) * inv + Float(to[i + 1]) * t))
            out[i + 2] = UInt8(clamping: Int(Float(from[i + 2]) * inv + Float(to[i + 2]) * t))
            out[i + 3] = 255
        }
        return out
    }

    private static func renderStudioCanvas(windowImage: CGImage, caption: String) -> [UInt8]? {
        let width = outputWidth
        let height = outputHeight
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        ctx.interpolationQuality = .high

        // 1. Studio dark gradient background
        let bgColors = [
            CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0),
            CGColor(red: 0.08, green: 0.11, blue: 0.21, alpha: 1.0),
            CGColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1.0)
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.52, 1.0]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: height),
                end: CGPoint(x: width, y: 0),
                options: []
            )
        }

        // Subtle radial glow behind window
        let glowColors = [
            CGColor(red: 0.22, green: 0.45, blue: 0.95, alpha: 0.22),
            CGColor(red: 0.22, green: 0.45, blue: 0.95, alpha: 0.0)
        ] as CFArray
        if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(
                glow,
                startCenter: CGPoint(x: Double(width) * 0.5, y: Double(height) * 0.55),
                startRadius: 40,
                endCenter: CGPoint(x: Double(width) * 0.5, y: Double(height) * 0.55),
                endRadius: 680,
                options: []
            )
        }

        // 2. Centered macOS window frame (content + 34px titlebar)
        let scale: CGFloat = 1.26
        let contentW = windowSize.width * scale
        let contentH = windowSize.height * scale
        let titleBarH: CGFloat = 36
        let frameW = contentW
        let frameH = contentH + titleBarH
        let frameX = (CGFloat(width) - frameW) / 2.0
        let frameY: CGFloat = 112.0 // leaves space at bottom for caption pill (CG origin is bottom-left)
        let frameRect = CGRect(x: frameX, y: frameY, width: frameW, height: frameH)
        let cornerRadius: CGFloat = 16

        // Shadow behind window
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 44, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
        let shadowPath = CGPath(roundedRect: frameRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(shadowPath)
        ctx.setFillColor(CGColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1.0))
        ctx.fillPath()
        ctx.restoreGState()

        // Clip inside rounded window
        ctx.saveGState()
        let clipPath = CGPath(roundedRect: frameRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()

        // Titlebar background
        let titleBarRect = CGRect(x: frameX, y: frameY + contentH, width: frameW, height: titleBarH)
        ctx.setFillColor(CGColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 1.0))
        ctx.fill(titleBarRect)

        // Titlebar bottom separator
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
        ctx.fill(CGRect(x: frameX, y: frameY + contentH, width: frameW, height: 1))

        // Traffic lights (red, yellow, green)
        let dotY = frameY + contentH + (titleBarH - 12) / 2.0
        let trafficColors: [CGColor] = [
            CGColor(red: 1.00, green: 0.37, blue: 0.34, alpha: 1.0),
            CGColor(red: 0.99, green: 0.74, blue: 0.18, alpha: 1.0),
            CGColor(red: 0.15, green: 0.79, blue: 0.25, alpha: 1.0)
        ]
        for (i, dotColor) in trafficColors.enumerated() {
            let dotRect = CGRect(x: frameX + 16 + CGFloat(i) * 20, y: dotY, width: 12, height: 12)
            ctx.setFillColor(dotColor)
            ctx.fillEllipse(in: dotRect)
        }

        // Window title centered in titlebar
        drawCenteredText(
            "MacCleaner",
            in: titleBarRect,
            font: NSFont.systemFont(ofSize: 13.5, weight: .semibold),
            color: NSColor.white.withAlphaComponent(0.86),
            context: ctx
        )

        // Draw SwiftUI window content image
        let contentRect = CGRect(x: frameX, y: frameY, width: contentW, height: contentH)
        ctx.draw(windowImage, in: contentRect)

        ctx.restoreGState()

        // Crisp 1px window border
        ctx.saveGState()
        let borderPath = CGPath(roundedRect: frameRect.insetBy(dx: 0.5, dy: 0.5), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(borderPath)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
        ctx.setLineWidth(1.5)
        ctx.strokePath()
        ctx.restoreGState()

        // 3. Bottom LinkedIn subtitle pill
        let captionFont = NSFont.systemFont(ofSize: 28, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: NSColor.white
        ]
        let attrStr = NSAttributedString(string: caption, attributes: attrs)
        let textBounds = attrStr.size()
        let pillW = textBounds.width + 64
        let pillH: CGFloat = 58
        let pillX = (CGFloat(width) - pillW) / 2.0
        let pillY: CGFloat = 28
        let pillRect = CGRect(x: pillX, y: pillY, width: pillW, height: pillH)

        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil)
        ctx.addPath(pillPath)
        ctx.setFillColor(CGColor(red: 0.08, green: 0.11, blue: 0.19, alpha: 0.92))
        ctx.fillPath()

        ctx.addPath(pillPath)
        ctx.setStrokeColor(CGColor(red: 0.35, green: 0.62, blue: 1.0, alpha: 0.45))
        ctx.setLineWidth(1.5)
        ctx.strokePath()

        drawCenteredText(
            caption,
            in: pillRect,
            font: captionFont,
            color: .white,
            context: ctx
        )

        return buffer
    }

    private static func drawCenteredText(
        _ text: String,
        in rect: CGRect,
        font: NSFont,
        color: NSColor,
        context: CGContext
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attr = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )

        let line = CTLineCreateWithAttributedString(attr)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        let x = rect.midX - CGFloat(lineWidth) / 2.0
        let y = rect.midY - (ascent - descent) / 2.0

        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: - Sanitized Demo Dataset

    private struct DemoDataset {
        let initialDisk: DiskSpaceInfo
        let afterCleanDisk: DiskSpaceInfo
        let summary: ScanSummary
        let afterCleanSummary: ScanSummary
        let defaultSelectedIDs: Set<String>
        let cleanReport: CleanReport
    }

    private static func buildDemoDataset() -> DemoDataset {
        let now = Date()
        let gb: Int64 = 1_000_000_000
        let mb: Int64 = 1_000_000

        let rulesByID = Dictionary(
            uniqueKeysWithValues: RuleCatalog.defaultRules(staleDays: 30).map { ($0.id, $0) }
        )

        func makeEntry(
            ruleID: String,
            name: String,
            path: String,
            sizeBytes: Int64,
            files: Int,
            daysAgo: Double
        ) -> ScannedEntry {
            ScannedEntry(
                ruleID: ruleID,
                name: name,
                url: URL(fileURLWithPath: path),
                sizeBytes: sizeBytes,
                fileCount: files,
                lastModified: now.addingTimeInterval(-daysAgo * 86_400),
                isProtected: false
            )
        }

        func makeRuleResult(_ ruleID: String, entries: [ScannedEntry]) -> ScanRuleResult {
            let rule = rulesByID[ruleID]!
            return ScanRuleResult(
                rule: rule,
                entries: entries.sorted { $0.sizeBytes > $1.sizeBytes },
                totalBytes: entries.reduce(0) { $0 + $1.sizeBytes },
                totalFiles: entries.reduce(0) { $0 + $1.fileCount },
                skippedPermissionCount: 0
            )
        }

        let results: [ScanRuleResult] = [
            // Dev & Pacotes (~14.97 GB)
            makeRuleResult("dev-npm-cache", entries: [
                makeEntry(ruleID: "dev-npm-cache", name: "~/.npm/_cacache", path: "/Users/dev/.npm/_cacache", sizeBytes: Int64(5.24 * Double(gb)), files: 41_820, daysAgo: 2),
                makeEntry(ruleID: "dev-npm-cache", name: "~/.npm/_npx", path: "/Users/dev/.npm/_npx", sizeBytes: Int64(4.52 * Double(gb)), files: 68_410, daysAgo: 5)
            ]),
            makeRuleResult("dev-puppeteer", entries: [
                makeEntry(ruleID: "dev-puppeteer", name: "~/.cache/puppeteer", path: "/Users/dev/.cache/puppeteer", sizeBytes: Int64(2.22 * Double(gb)), files: 1_940, daysAgo: 18)
            ]),
            makeRuleResult("dev-swiftpm-cache", entries: [
                makeEntry(ruleID: "dev-swiftpm-cache", name: "~/Library/Caches/org.swift.swiftpm", path: "/Users/dev/Library/Caches/org.swift.swiftpm", sizeBytes: Int64(1.38 * Double(gb)), files: 3_420, daysAgo: 4)
            ]),
            makeRuleResult("dev-pip-cache", entries: [
                makeEntry(ruleID: "dev-pip-cache", name: "~/Library/Caches/pip", path: "/Users/dev/Library/Caches/pip", sizeBytes: 720 * mb, files: 1_120, daysAgo: 9)
            ]),
            makeRuleResult("dev-playwright", entries: [
                makeEntry(ruleID: "dev-playwright", name: "~/Library/Caches/ms-playwright", path: "/Users/dev/Library/Caches/ms-playwright", sizeBytes: 580 * mb, files: 910, daysAgo: 22)
            ]),
            makeRuleResult("dev-homebrew-cache", entries: [
                makeEntry(ruleID: "dev-homebrew-cache", name: "~/Library/Caches/Homebrew", path: "/Users/dev/Library/Caches/Homebrew", sizeBytes: 310 * mb, files: 185, daysAgo: 6)
            ]),

            // Sistema & Apps (~7.88 GB)
            makeRuleResult("sys-user-caches", entries: [
                makeEntry(ruleID: "sys-user-caches", name: "com.spotify.client", path: "/Users/dev/Library/Caches/com.spotify.client", sizeBytes: Int64(4.22 * Double(gb)), files: 2_890, daysAgo: 1),
                makeEntry(ruleID: "sys-user-caches", name: "Google", path: "/Users/dev/Library/Caches/Google", sizeBytes: Int64(1.99 * Double(gb)), files: 5_410, daysAgo: 1)
            ]),
            makeRuleResult("sys-downloads-installers", entries: [
                makeEntry(ruleID: "sys-downloads-installers", name: "Docker_Desktop_4.34.dmg", path: "/Users/dev/Downloads/Docker_Desktop_4.34.dmg", sizeBytes: Int64(1.49 * Double(gb)), files: 1, daysAgo: 42)
            ]),
            makeRuleResult("sys-user-logs", entries: [
                makeEntry(ruleID: "sys-user-logs", name: "DiagnosticReports", path: "/Users/dev/Library/Logs/DiagnosticReports", sizeBytes: 180 * mb, files: 245, daysAgo: 7)
            ]),

            // AI Agents & IDEs (~6.12 GB)
            makeRuleResult("ai-gemini-sessions", entries: [
                makeEntry(
                    ruleID: "ai-gemini-sessions",
                    name: L10n.t("sessao-refactor-auth", "session-auth-refactor"),
                    path: L10n.t("/Users/dev/.gemini/antigravity/brain/sessao-refactor-auth", "/Users/dev/.gemini/antigravity/brain/session-auth-refactor"),
                    sizeBytes: Int64(1.95 * Double(gb)),
                    files: 840,
                    daysAgo: 14
                )
            ]),
            makeRuleResult("ai-gemini-recordings", entries: [
                makeEntry(ruleID: "ai-gemini-recordings", name: "browser-e2e-checkout", path: "/Users/dev/.gemini/antigravity/browser_recordings/browser-e2e-checkout", sizeBytes: Int64(1.85 * Double(gb)), files: 112, daysAgo: 11)
            ]),
            makeRuleResult("ai-claude-sessions", entries: [
                makeEntry(ruleID: "ai-claude-sessions", name: "workspace-legacy-api", path: "/Users/dev/.claude/projects/workspace-legacy-api", sizeBytes: Int64(1.10 * Double(gb)), files: 318, daysAgo: 21)
            ]),
            makeRuleResult("ai-antigravity-caches", entries: [
                makeEntry(ruleID: "ai-antigravity-caches", name: "~/Library/Caches/com.google.antigravity", path: "/Users/dev/Library/Caches/com.google.antigravity", sizeBytes: 420 * mb, files: 680, daysAgo: 1),
                makeEntry(ruleID: "ai-antigravity-caches", name: "~/Library/Caches/antigravity-updater", path: "/Users/dev/Library/Caches/antigravity-updater", sizeBytes: 325 * mb, files: 45, daysAgo: 3),
                makeEntry(ruleID: "ai-antigravity-caches", name: "~/Library/Application Support/Antigravity/CachedData", path: "/Users/dev/Library/Application Support/Antigravity/CachedData", sizeBytes: 145 * mb, files: 310, daysAgo: 2)
            ]),
            makeRuleResult("ai-codex-caches", entries: [
                makeEntry(ruleID: "ai-codex-caches", name: "~/.codex/.tmp", path: "/Users/dev/.codex/.tmp", sizeBytes: 132 * mb, files: 410, daysAgo: 4),
                makeEntry(ruleID: "ai-codex-caches", name: "~/.codex/cache", path: "/Users/dev/.codex/cache", sizeBytes: 87 * mb, files: 195, daysAgo: 3)
            ]),
            makeRuleResult("ai-cursor-caches", entries: [
                makeEntry(ruleID: "ai-cursor-caches", name: "~/Library/Application Support/Cursor/CachedData", path: "/Users/dev/Library/Application Support/Cursor/CachedData", sizeBytes: 136 * mb, files: 280, daysAgo: 5)
            ]),
            makeRuleResult("ai-claude-caches", entries: [
                makeEntry(ruleID: "ai-claude-caches", name: "~/.claude/file-history", path: "/Users/dev/.claude/file-history", sizeBytes: 85 * mb, files: 520, daysAgo: 6)
            ]),

            // Xcode & Simuladores (~5.97 GB)
            makeRuleResult("xcode-sim-devices", entries: [
                makeEntry(ruleID: "xcode-sim-devices", name: "iPhone 16 Pro (iOS 18.2)", path: "/Users/dev/Library/Developer/CoreSimulator/Devices/036BA614-SIM-1", sizeBytes: Int64(3.31 * Double(gb)), files: 4_120, daysAgo: 19),
                makeEntry(ruleID: "xcode-sim-devices", name: "iPhone 15 (iOS 17.5)", path: "/Users/dev/Library/Developer/CoreSimulator/Devices/FD8D4C66-SIM-2", sizeBytes: Int64(2.49 * Double(gb)), files: 3_680, daysAgo: 48)
            ]),
            makeRuleResult("xcode-derived-data", entries: [
                makeEntry(ruleID: "xcode-derived-data", name: "MobileApp-DerivedData", path: "/Users/dev/Library/Developer/Xcode/DerivedData/MobileApp-abc", sizeBytes: 170 * mb, files: 890, daysAgo: 12)
            ]),

            // Modelos de IA Locais (~3.14 GB)
            makeRuleResult("models-huggingface", entries: [
                makeEntry(ruleID: "models-huggingface", name: "models--mlx-community--whisper-large-v3-turbo", path: "/Users/dev/.cache/huggingface/hub/models--mlx-community--whisper-large-v3-turbo", sizeBytes: Int64(1.61 * Double(gb)), files: 14, daysAgo: 25),
                makeEntry(ruleID: "models-huggingface", name: "blobs", path: "/Users/dev/.cache/huggingface/hub/blobs", sizeBytes: Int64(1.53 * Double(gb)), files: 22, daysAgo: 25)
            ]),

            // Projetos Parados (~967 MB)
            makeRuleResult("stale-dev-artifacts", entries: [
                makeEntry(ruleID: "stale-dev-artifacts", name: "old-dashboard/node_modules", path: "/Users/dev/Projects/old-dashboard/node_modules", sizeBytes: 620 * mb, files: 28_400, daysAgo: 64),
                makeEntry(ruleID: "stale-dev-artifacts", name: "ml-experiments/.venv", path: "/Users/dev/Projects/ml-experiments/.venv", sizeBytes: 347 * mb, files: 11_200, daysAgo: 51)
            ])
        ]
        .sorted { $0.totalBytes > $1.totalBytes }

        let totalDisk: Int64 = Int64(245.11 * Double(gb))
        let initialFree: Int64 = Int64(31.48 * Double(gb))
        let initialDisk = DiskSpaceInfo(totalBytes: totalDisk, availableBytes: initialFree)

        let summary = ScanSummary(
            results: results,
            diskSpace: initialDisk,
            scannedAt: now,
            durationSeconds: 1.4,
            totalSkippedPermissions: 0
        )

        var defaultSelectedIDs = Set<String>()
        var safeBytesTotal: Int64 = 0
        var safeCount = 0
        for result in results where result.rule.defaultSelected {
            for entry in result.entries {
                defaultSelectedIDs.insert(entry.id)
                safeBytesTotal += entry.sizeBytes
                safeCount += 1
            }
        }

        let afterCleanFree = initialFree + safeBytesTotal
        let afterCleanDisk = DiskSpaceInfo(totalBytes: totalDisk, availableBytes: afterCleanFree)

        let remainingResults = results.filter { !$0.rule.defaultSelected }
        let afterCleanSummary = ScanSummary(
            results: remainingResults,
            diskSpace: afterCleanDisk,
            scannedAt: now,
            durationSeconds: 0.9,
            totalSkippedPermissions: 0
        )

        let report = CleanReport(
            reclaimedBytes: safeBytesTotal,
            removedCount: safeCount,
            failures: [],
            mode: .moveToTrash,
            completedAt: now
        )

        return DemoDataset(
            initialDisk: initialDisk,
            afterCleanDisk: afterCleanDisk,
            summary: summary,
            afterCleanSummary: afterCleanSummary,
            defaultSelectedIDs: defaultSelectedIDs,
            cleanReport: report
        )
    }
}
