import Foundation

public enum RuleCatalog {
    public static func defaultRules(staleDays: Int = 30) -> [CleanerRule] {
        [
            // MARK: - AI Agents & IDEs
            CleanerRule(
                id: "ai-antigravity-caches",
                name: L10n.t("Antigravity — Caches & Updater", "Antigravity — Caches & Updater"),
                category: .aiAgents,
                risk: .safe,
                summary: L10n.t(
                    "Caches de interface, GPU, código compilado e instaladores de atualização do Antigravity.",
                    "UI, GPU, compiled code caches, and updater installers for Antigravity."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente ao abrir o app. Não afeta sessões ou configurações.",
                    "Automatically rebuilt when launching the app. Sessions and settings remain intact."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/com.google.antigravity"),
                    .directory(path: "~/Library/Caches/antigravity-updater"),
                    .directory(path: "~/Library/Application Support/Antigravity/Cache"),
                    .directory(path: "~/Library/Application Support/Antigravity/CachedData"),
                    .directory(path: "~/Library/Application Support/Antigravity/Code Cache"),
                    .directory(path: "~/Library/Application Support/Antigravity/GPUCache")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "ai-gemini-tmp",
                name: L10n.t("Gemini — Temporários & Cache", "Gemini — Temp Files & Cache"),
                category: .aiAgents,
                risk: .safe,
                summary: L10n.t(
                    "Arquivos temporários e cache local em ~/.gemini/tmp e ~/.gemini/cache.",
                    "Temporary files and local cache in ~/.gemini/tmp and ~/.gemini/cache."
                ),
                impactNote: L10n.t(
                    "Seguro para remover; não toca em credenciais nem histórico de conversas.",
                    "Safe to remove; never touches credentials or conversation history."
                ),
                targets: [
                    .directory(path: "~/.gemini/tmp"),
                    .directory(path: "~/.gemini/cache")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "ai-gemini-recordings",
                name: L10n.t("Gemini / Antigravity — Gravações de Browser", "Gemini / Antigravity — Browser Recordings"),
                category: .aiAgents,
                risk: .moderate,
                summary: L10n.t(
                    "Capturas de tela e gravações de automação de navegador salvas por sessões.",
                    "Screenshots and browser automation recordings saved from agent sessions."
                ),
                impactNote: L10n.t(
                    "Remove apenas mídias antigas de reprodução visual; código dos projetos permanece intacto.",
                    "Removes old visual playback media only; project code remains untouched."
                ),
                targets: [
                    .directoryChildren(path: "~/.gemini/antigravity/browser_recordings")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "ai-gemini-sessions",
                name: L10n.t("Gemini / Antigravity — Sessões & Artefatos", "Gemini / Antigravity — Sessions & Artifacts"),
                category: .aiAgents,
                risk: .caution,
                summary: L10n.t(
                    "Diretórios de conversas, logs de tarefas e artefatos salvos em ~/.gemini/antigravity/brain.",
                    "Conversation directories, task logs, and artifacts stored in ~/.gemini/antigravity/brain."
                ),
                impactNote: L10n.t(
                    "Contém histórico e artefatos de sessões anteriores. Escolha manualmente sessões antigas.",
                    "Contains past session history and artifacts. Manually pick old sessions to remove."
                ),
                targets: [
                    .directoryChildren(path: "~/.gemini/antigravity/brain")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "ai-claude-caches",
                name: L10n.t("Claude Code — Caches, Backups & Debug", "Claude Code — Caches, Backups & Debug"),
                category: .aiAgents,
                risk: .safe,
                summary: L10n.t(
                    "Caches internos, backups rotativos, file-history e logs de debug em ~/.claude.",
                    "Internal caches, rotating backups, file-history, and debug logs inside ~/.claude."
                ),
                impactNote: L10n.t(
                    "Não apaga skills, plugins nem sessões de projeto.",
                    "Preserves skills, plugins, and project sessions."
                ),
                targets: [
                    .directory(path: "~/.claude/cache"),
                    .directory(path: "~/.claude/backups"),
                    .directory(path: "~/.claude/file-history"),
                    .directory(path: "~/.claude/debug")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "ai-claude-sessions",
                name: L10n.t("Claude Code — Sessões por Projeto", "Claude Code — Project Sessions"),
                category: .aiAgents,
                risk: .caution,
                summary: L10n.t(
                    "Transcrições e estado de conversas salvas em ~/.claude/projects.",
                    "Conversation transcripts and state stored in ~/.claude/projects."
                ),
                impactNote: L10n.t(
                    "Apagar remove o histórico de retomada daquelas conversas no Claude Code.",
                    "Deleting removes resume history for those Claude Code conversations."
                ),
                targets: [
                    .directoryChildren(path: "~/.claude/projects")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "ai-codex-caches",
                name: L10n.t("OpenAI Codex — Cache & Temporários", "OpenAI Codex — Cache & Temp Files"),
                category: .aiAgents,
                risk: .safe,
                summary: L10n.t(
                    "Diretórios de cache e arquivos temporários (.tmp) do Codex em ~/.codex.",
                    "Codex cache directories and temporary files (.tmp) in ~/.codex."
                ),
                impactNote: L10n.t(
                    "Preserva plugins, configurações e bancos SQLite.",
                    "Preserves plugins, settings, and SQLite databases."
                ),
                targets: [
                    .directory(path: "~/.codex/cache"),
                    .directory(path: "~/.codex/.tmp")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "ai-cursor-caches",
                name: L10n.t("Cursor — Caches de Editor & Electron", "Cursor — Editor & Electron Caches"),
                category: .aiAgents,
                risk: .safe,
                summary: L10n.t(
                    "Cache, CachedData, Code Cache e GPUCache do Cursor IDE.",
                    "Cache, CachedData, Code Cache, and GPUCache for Cursor IDE."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente; extensões e configurações permanecem intactas.",
                    "Rebuilt automatically; extensions and settings remain intact."
                ),
                targets: [
                    .directory(path: "~/Library/Application Support/Cursor/Cache"),
                    .directory(path: "~/Library/Application Support/Cursor/CachedData"),
                    .directory(path: "~/Library/Application Support/Cursor/Code Cache"),
                    .directory(path: "~/Library/Application Support/Cursor/GPUCache")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "ai-vscode-caches",
                name: L10n.t("VS Code — Caches de Editor & Electron", "VS Code — Editor & Electron Caches"),
                category: .aiAgents,
                risk: .safe,
                summary: L10n.t(
                    "Cache, CachedData, Code Cache e GPUCache do Visual Studio Code.",
                    "Cache, CachedData, Code Cache, and GPUCache for Visual Studio Code."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente ao reabrir o VS Code.",
                    "Automatically rebuilt when reopening VS Code."
                ),
                targets: [
                    .directory(path: "~/Library/Application Support/Code/Cache"),
                    .directory(path: "~/Library/Application Support/Code/CachedData"),
                    .directory(path: "~/Library/Application Support/Code/Code Cache"),
                    .directory(path: "~/Library/Application Support/Code/GPUCache")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "ai-windsurf-caches",
                name: L10n.t("Windsurf — Caches de Editor & Electron", "Windsurf — Editor & Electron Caches"),
                category: .aiAgents,
                risk: .safe,
                summary: L10n.t(
                    "Cache, CachedData, Code Cache e GPUCache do Windsurf.",
                    "Cache, CachedData, Code Cache, and GPUCache for Windsurf."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente; configurações e extensões não são alteradas.",
                    "Automatically rebuilt; settings and extensions are untouched."
                ),
                targets: [
                    .directory(path: "~/Library/Application Support/Windsurf/Cache"),
                    .directory(path: "~/Library/Application Support/Windsurf/CachedData"),
                    .directory(path: "~/Library/Application Support/Windsurf/Code Cache"),
                    .directory(path: "~/Library/Application Support/Windsurf/GPUCache")
                ],
                defaultSelected: true
            ),

            // MARK: - Local AI Models
            CleanerRule(
                id: "models-huggingface",
                name: L10n.t("HuggingFace Hub — Modelos em Cache", "HuggingFace Hub — Cached Models"),
                category: .aiModels,
                risk: .caution,
                summary: L10n.t(
                    "Pesos e tokenizers baixados em ~/.cache/huggingface/hub.",
                    "Downloaded model weights and tokenizers in ~/.cache/huggingface/hub."
                ),
                impactNote: L10n.t(
                    "Modelos removidos precisarão ser baixados novamente se um script precisar deles.",
                    "Removed models will need to be re-downloaded if needed by a script."
                ),
                targets: [
                    .directoryChildren(path: "~/.cache/huggingface/hub")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "models-ollama",
                name: L10n.t("Ollama — Modelos Locais", "Ollama — Local Models"),
                category: .aiModels,
                risk: .caution,
                summary: L10n.t(
                    "Blobs e manifestos de modelos armazenados pelo Ollama em ~/.ollama/models.",
                    "Model blobs and manifests stored by Ollama in ~/.ollama/models."
                ),
                impactNote: L10n.t(
                    "Remove pesos locais baixados via ollama pull.",
                    "Removes local weights downloaded via ollama pull."
                ),
                targets: [
                    .directoryChildren(path: "~/.ollama/models")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "models-lmstudio",
                name: L10n.t("LM Studio — Modelos Locais", "LM Studio — Local Models"),
                category: .aiModels,
                risk: .caution,
                summary: L10n.t(
                    "Arquivos GGUF e MLX baixados no LM Studio em ~/.lmstudio/models.",
                    "GGUF and MLX model files downloaded in ~/.lmstudio/models."
                ),
                impactNote: L10n.t(
                    "Exige novo download caso deseje rodar o modelo novamente.",
                    "Requires re-downloading if you want to run the model again."
                ),
                targets: [
                    .directoryChildren(path: "~/.lmstudio/models")
                ],
                defaultSelected: false
            ),

            // MARK: - Dev & Packages
            CleanerRule(
                id: "dev-npm-cache",
                name: L10n.t("npm — Cache & Pacotes npx", "npm — Cache & npx Packages"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Cache de tarballs (~/.npm/_cacache) e executáveis temporários (~/.npm/_npx).",
                    "Tarball cache (~/.npm/_cacache) and temporary npx binaries (~/.npm/_npx)."
                ),
                impactNote: L10n.t(
                    "100% recriável sob demanda na próxima execução de npm ou npx.",
                    "100% recreatable on demand the next time npm or npx runs."
                ),
                targets: [
                    .directory(path: "~/.npm/_cacache"),
                    .directory(path: "~/.npm/_npx")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-pnpm-cache",
                name: L10n.t("pnpm — Cache", "pnpm — Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Cache de pacotes e metadados do pnpm em ~/Library/Caches/pnpm.",
                    "pnpm package and metadata cache in ~/Library/Caches/pnpm."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente em instalações futuras.",
                    "Automatically rebuilt on future installs."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/pnpm")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-bun-cache",
                name: L10n.t("Bun — Cache de Instalação", "Bun — Install Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Cache global de pacotes do Bun em ~/.bun/install/cache.",
                    "Global Bun package cache in ~/.bun/install/cache."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente ao rodar bun install.",
                    "Automatically rebuilt when running bun install."
                ),
                targets: [
                    .directory(path: "~/.bun/install/cache")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-yarn-cache",
                name: L10n.t("Yarn — Cache Global", "Yarn — Global Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Cache do Yarn em ~/Library/Caches/Yarn.",
                    "Yarn cache in ~/Library/Caches/Yarn."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente ao instalar dependências.",
                    "Automatically rebuilt when installing dependencies."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/Yarn")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-pip-cache",
                name: L10n.t("pip — Cache de Pacotes Python", "pip — Python Package Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Wheels e downloads em cache do pip em ~/Library/Caches/pip e ~/.cache/pip.",
                    "Cached Python wheels and downloads in ~/Library/Caches/pip and ~/.cache/pip."
                ),
                impactNote: L10n.t(
                    "Não afeta virtualenvs nem pacotes já instalados.",
                    "Does not affect virtualenvs or already-installed packages."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/pip"),
                    .directory(path: "~/.cache/pip")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-uv-cache",
                name: L10n.t("uv — Cache de Pacotes Python", "uv — Python Package Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Cache de pacotes do uv em ~/.cache/uv.",
                    "uv package cache in ~/.cache/uv."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente ao rodar uv.",
                    "Automatically rebuilt when running uv."
                ),
                targets: [
                    .directory(path: "~/.cache/uv")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-homebrew-cache",
                name: L10n.t("Homebrew — Downloads & Casks em Cache", "Homebrew — Cached Downloads & Casks"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Arquivos baixados pelo brew em ~/Library/Caches/Homebrew.",
                    "Archives downloaded by brew in ~/Library/Caches/Homebrew."
                ),
                impactNote: L10n.t(
                    "Equivalente a limpar downloads antigos do brew; fórmulas instaladas não mudam.",
                    "Equivalent to brew cleanup; installed formulae and casks remain intact."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/Homebrew")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-swiftpm-cache",
                name: L10n.t("Swift Package Manager — Cache", "Swift Package Manager — Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Cache de repositórios e manifestos do SwiftPM em ~/Library/Caches/org.swift.swiftpm.",
                    "SwiftPM repository and manifest cache in ~/Library/Caches/org.swift.swiftpm."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente no próximo swift build.",
                    "Automatically rebuilt on the next swift build."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/org.swift.swiftpm")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-playwright",
                name: L10n.t("Playwright — Browsers Baixados", "Playwright — Downloaded Browsers"),
                category: .devCaches,
                risk: .moderate,
                summary: L10n.t(
                    "Binários de Chromium/Firefox/WebKit baixados pelo Playwright.",
                    "Chromium/Firefox/WebKit binaries downloaded by Playwright."
                ),
                impactNote: L10n.t(
                    "Se você rodar testes Playwright novamente, será necessário rodar playwright install.",
                    "Requires running playwright install again if you run Playwright tests."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/ms-playwright"),
                    .directory(path: "~/.cache/ms-playwright")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "dev-puppeteer",
                name: L10n.t("Puppeteer — Browsers Baixados", "Puppeteer — Downloaded Browsers"),
                category: .devCaches,
                risk: .moderate,
                summary: L10n.t(
                    "Binários do Chrome/Chromium baixados em ~/.cache/puppeteer.",
                    "Chrome/Chromium binaries cached in ~/.cache/puppeteer."
                ),
                impactNote: L10n.t(
                    "Scripts que usam Puppeteer podem baixar o browser novamente se necessário.",
                    "Scripts using Puppeteer may re-download the browser if needed."
                ),
                targets: [
                    .directory(path: "~/.cache/puppeteer")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "dev-cargo-cache",
                name: L10n.t("Rust Cargo — Registry Cache", "Rust Cargo — Registry Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Tarballs compactados (.crate) em ~/.cargo/registry/cache.",
                    "Compressed crate tarballs (.crate) in ~/.cargo/registry/cache."
                ),
                impactNote: L10n.t(
                    "Crates já compilados e binários instalados não são removidos.",
                    "Compiled crates and installed binaries are not removed."
                ),
                targets: [
                    .directory(path: "~/.cargo/registry/cache")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "dev-gradle-cache",
                name: L10n.t("Gradle — Caches de Build", "Gradle — Build Caches"),
                category: .devCaches,
                risk: .moderate,
                summary: L10n.t(
                    "Dependências e caches de build em ~/.gradle/caches.",
                    "Dependencies and build caches in ~/.gradle/caches."
                ),
                impactNote: L10n.t(
                    "Próximo build Android/Java fará novo download das dependências.",
                    "The next Android/Java build will re-download dependencies."
                ),
                targets: [
                    .directory(path: "~/.gradle/caches")
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "dev-cocoapods",
                name: L10n.t("CocoaPods — Cache", "CocoaPods — Cache"),
                category: .devCaches,
                risk: .safe,
                summary: L10n.t(
                    "Cache de podspecs e downloads em ~/Library/Caches/CocoaPods.",
                    "Podspec and download cache in ~/Library/Caches/CocoaPods."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente ao rodar pod install.",
                    "Automatically rebuilt when running pod install."
                ),
                targets: [
                    .directory(path: "~/Library/Caches/CocoaPods")
                ],
                defaultSelected: true
            ),

            // MARK: - Xcode & Simulators
            CleanerRule(
                id: "xcode-derived-data",
                name: "Xcode — DerivedData",
                category: .xcodeAndMobile,
                risk: .safe,
                summary: L10n.t(
                    "Artefatos intermediários e índices de build por projeto em DerivedData.",
                    "Intermediate build artifacts and indexes per project in DerivedData."
                ),
                impactNote: L10n.t(
                    "Recriado no próximo build do Xcode (o primeiro build pode levar um pouco mais).",
                    "Rebuilt on the next Xcode build (the first build may take slightly longer)."
                ),
                targets: [
                    .directoryChildren(path: "~/Library/Developer/Xcode/DerivedData")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "xcode-caches",
                name: L10n.t("Xcode — Cache Interno", "Xcode — Internal Cache"),
                category: .xcodeAndMobile,
                risk: .safe,
                summary: L10n.t(
                    "Caches gerais do Xcode em ~/Library/Caches/com.apple.dt.Xcode.",
                    "General Xcode caches in ~/Library/Caches/com.apple.dt.Xcode."
                ),
                impactNote: L10n.t("Seguro para remover.", "Safe to remove."),
                targets: [
                    .directory(path: "~/Library/Caches/com.apple.dt.Xcode")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "xcode-sim-caches",
                name: "CoreSimulator — Caches",
                category: .xcodeAndMobile,
                risk: .safe,
                summary: L10n.t(
                    "Caches compartilhados dos simuladores iOS/watchOS.",
                    "Shared caches for iOS/watchOS simulators."
                ),
                impactNote: L10n.t(
                    "Recriado automaticamente ao iniciar um simulador.",
                    "Automatically rebuilt when booting a simulator."
                ),
                targets: [
                    .directory(path: "~/Library/Developer/CoreSimulator/Caches")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "xcode-sim-devices",
                name: L10n.t("CoreSimulator — Dispositivos", "CoreSimulator — Devices"),
                category: .xcodeAndMobile,
                risk: .caution,
                summary: L10n.t(
                    "Imagens individuais de simuladores em CoreSimulator/Devices.",
                    "Individual simulator device images in CoreSimulator/Devices."
                ),
                impactNote: L10n.t(
                    "Apaga o estado e apps instalados dentro do simulador escolhido.",
                    "Erases state and installed apps inside the selected simulator."
                ),
                targets: [
                    .directoryChildren(path: "~/Library/Developer/CoreSimulator/Devices")
                ],
                defaultSelected: false
            ),

            // MARK: - System & Apps
            CleanerRule(
                id: "sys-user-caches",
                name: L10n.t("macOS — Caches de Aplicativos", "macOS — Application Caches"),
                category: .systemAndApps,
                risk: .moderate,
                summary: L10n.t(
                    "Pastas em ~/Library/Caches (excluindo itens já listados em Dev/IA/Xcode).",
                    "Folders in ~/Library/Caches (excluding items already grouped under Dev/AI/Xcode)."
                ),
                impactNote: L10n.t(
                    "Apps como Spotify e navegadores podem refazer cache de mídia após limpeza.",
                    "Apps like Spotify and browsers may rebuild media caches after cleanup."
                ),
                targets: [
                    .directoryChildren(
                        path: "~/Library/Caches",
                        excludeNames: [
                            "pip",
                            "Homebrew",
                            "pnpm",
                            "Yarn",
                            "org.swift.swiftpm",
                            "ms-playwright",
                            "com.apple.dt.Xcode",
                            "CocoaPods",
                            "com.google.antigravity",
                            "antigravity-updater"
                        ]
                    )
                ],
                defaultSelected: false
            ),
            CleanerRule(
                id: "sys-user-logs",
                name: L10n.t("macOS — Logs de Usuário", "macOS — User Logs"),
                category: .systemAndApps,
                risk: .safe,
                summary: L10n.t(
                    "Arquivos e pastas de diagnóstico em ~/Library/Logs.",
                    "Diagnostic logs and reports in ~/Library/Logs."
                ),
                impactNote: L10n.t(
                    "Remove apenas registros de log antigos.",
                    "Removes old diagnostic log records only."
                ),
                targets: [
                    .directoryChildren(path: "~/Library/Logs")
                ],
                defaultSelected: true
            ),
            CleanerRule(
                id: "sys-downloads-installers",
                name: L10n.t("Downloads — Instaladores Antigos (.dmg / .pkg)", "Downloads — Old Installers (.dmg / .pkg)"),
                category: .systemAndApps,
                risk: .moderate,
                summary: L10n.t(
                    "Instaladores .dmg e .pkg em ~/Downloads sem modificação há mais de 14 dias.",
                    ".dmg and .pkg installers in ~/Downloads unmodified for over 14 days."
                ),
                impactNote: L10n.t(
                    "Após instalar um app em /Applications, o .dmg/.pkg geralmente não é mais necessário.",
                    "Once an app is installed in /Applications, the installer is usually no longer needed."
                ),
                targets: [
                    .matchingFiles(path: "~/Downloads", extensions: ["dmg", "pkg"], olderThanDays: 14)
                ],
                defaultSelected: false
            ),

            // MARK: - Stale Projects
            CleanerRule(
                id: "stale-dev-artifacts",
                name: L10n.t("Dependências & Builds em Projetos Parados", "Stale Project Dependencies & Builds"),
                category: .staleProjects,
                risk: .moderate,
                summary: L10n.t(
                    "Pastas node_modules, .venv, venv, target e .next em projetos sem edição há mais de \(staleDays) dias.",
                    "node_modules, .venv, venv, target, and .next folders in projects untouched for over \(staleDays) days."
                ),
                impactNote: L10n.t(
                    "Código-fonte permanece intacto; exige reinstalar dependências (npm install / pip install / cargo build) se reabrir o projeto.",
                    "Source code remains intact; requires reinstalling dependencies if you reopen the project."
                ),
                targets: [
                    .staleProjectArtifacts(
                        roots: ["~/Desktop", "~/Documents", "~/Projects", "~/Developer", "~/Code"],
                        artifactNames: ["node_modules", ".venv", "venv", "target", ".next"],
                        olderThanDays: staleDays,
                        maxDepth: 4
                    )
                ],
                defaultSelected: false
            )
        ]
    }
}
