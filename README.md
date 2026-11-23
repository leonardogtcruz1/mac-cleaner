# MacCleaner

Aplicativo nativo para macOS (**Swift + SwiftUI**) focado em liberar espaço em disco limpando caches de agentes de IA, IDEs, gerenciadores de pacotes, Xcode/simuladores, caches do sistema e dependências antigas de projetos parados.

## Estrutura do Projeto

- `Sources/MacCleanerCore`: biblioteca principal com modelos, catálogo de regras (`RuleCatalog`), trava de segurança (`SafetyGuard`), motor de varredura paralelo (`ScannerEngine`), limpeza (`CleanerEngine`) e exclusões (`ExclusionsStore`).
- `Sources/MacCleaner`: interface nativa em SwiftUI (`NavigationSplitView`, gráfico com `Charts`, `MenuBarExtra`, preview de dry-run) + flag de terminal `--scan-summary`.
- `Tests/MacCleanerCoreTests`: testes unitários isolados em diretórios temporários (Swift Testing).
- `scripts/build-app.sh`: gera o bundle `build/MacCleaner.app`.
- `scripts/test.sh`: executa os testes unitários carregando o plugin de macros do Swift Testing no Command Line Tools.

## Como Executar

### 1. Gerar e abrir o `.app` standalone (`build/MacCleaner.app`)
```bash
./scripts/build-app.sh
open build/MacCleaner.app
```

### 2. Abrir diretamente via SwiftPM
```bash
swift run --scratch-path /tmp/mac-cleaner-build MacCleaner
```

### 3. Executar um diagnóstico rápido no terminal (somente leitura)
```bash
build/MacCleaner.app/Contents/MacOS/MacCleaner --scan-summary
```

### 4. Rodar os testes unitários
```bash
./scripts/test.sh
```

> **Nota sobre build no Desktop / iCloud Drive**: os scripts usam `--scratch-path "${TMPDIR:-/tmp}/mac-cleaner-build"` para evitar que atributos estendidos do Finder/iCloud Drive interfiram na assinatura `codesign` dentro de `.build`.

## Segurança e Permissões

- **Dry-run obrigatório**: nenhuma remoção acontece antes de confirmar o modal de preview com a lista exata de itens e tamanhos.
- **Lixeira por padrão**: os arquivos são movidos para a Lixeira do macOS (`FileManager.trashItem`), permitindo recuperação. O modo "Apagar Permanentemente" exige seleção explícita e exibe alerta destacado.
- **Proteções fixas (`SafetyGuard`)**: diretórios críticos do macOS (`/System`, `/usr`, `/bin`, `/sbin`, `~`, `~/Documents`, `~/Downloads`, `~/.ssh`, `~/Library/Keychains`) e arquivos sensíveis (`.env*`, `settings.json`, `auth.json`, `credentials*`, chaves SSH) nunca podem ser apagados.
- **Whitelist**: qualquer pasta ou arquivo pode ser marcado como protegido pela interface (ícone de escudo ou aba **Protegidos**).
- **Acesso Total ao Disco (Full Disk Access)**: algumas pastas protegidas em `~/Library` exigem permissão em *Ajustes do Sistema → Privacidade e Segurança → Acesso Total ao Disco*. Quando houver itens ignorados por permissão, o app avisa sem interromper o scan.
