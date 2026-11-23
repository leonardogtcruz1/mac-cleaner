import AppKit
import MacCleanerCore
import SwiftUI

struct ExclusionsView: View {
    @Bindable var viewModel: AppViewModel

    private var sortedExclusions: [String] {
        viewModel.exclusions.sorted()
    }

    private let permanentRules: [String] = [
        "/, /System, /usr, /bin, /sbin, /Library, /Applications, /Users",
        "Pasta pessoal (~), ~/Desktop, ~/Documents, ~/Downloads, ~/Library, ~/Library/Application Support",
        "Chaves e segredos: ~/Library/Keychains, ~/.ssh, ~/.gnupg, ~/.aws",
        "Arquivos sensíveis: .env*, credentials*, settings.json, auth.json, id_rsa, id_ed25519, known_hosts"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Caminhos Protegidos (Whitelist)")
                            .font(.title2.bold())
                        Text("Itens protegidos nunca são selecionados automaticamente nem podem ser apagados.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        pickFolderOrFileToProtect()
                    } label: {
                        Label("Adicionar Pasta Protegida", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suas Exclusões Personalizadas")
                        .font(.headline)

                    if sortedExclusions.isEmpty {
                        Text("Nenhuma exclusão adicionada ainda. Você pode proteger qualquer pasta pelo ícone de escudo nas categorias ou clicando em \"Adicionar Pasta Protegida\".")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(sortedExclusions, id: \.self) { path in
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundStyle(.blue)
                                    Text(path)
                                        .font(.subheadline.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        viewModel.revealInFinder(url: URL(fileURLWithPath: path))
                                    } label: {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Mostrar no Finder")

                                    Button(role: .destructive) {
                                        viewModel.removeExclusion(path: path)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Remover da lista de protegidos")
                                }
                                .padding(10)
                                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Proteções Permanentes do Sistema")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(permanentRules, id: \.self) { ruleText in
                            Label(ruleText, systemImage: "checkmark.shield.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(24)
        }
        .navigationTitle("Protegidos")
    }

    private func pickFolderOrFileToProtect() {
        let panel = NSOpenPanel()
        panel.title = "Escolher pasta ou arquivo para proteger"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.addExclusion(path: url.path)
        }
    }
}
