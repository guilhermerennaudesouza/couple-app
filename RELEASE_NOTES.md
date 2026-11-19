# Couple App v1.1.1 — 100% Português (Brasil) por Padrão 🇧🇷💕

### ✨ O que foi corrigido

- **💘 Swipe de Encontros, Match & Lista 100% em PT-BR:**
  - Categorias nos cards do modo Swipe agora aparecem traduzidas (`Aconchegante`, `Ao Ar Livre`, `Gastronômico`, `Romântico`, `Aventura`, `Econômico`).
  - Ideias iniciais antigas salvas em inglês no Firestore (da v1.0.0) agora são traduzidas automaticamente no Swipe, no diálogo de **Deu Match!**, no **Sortear Encontro**, na notificação do parceiro, na exclusão e ao agendar no Calendário.
- **✅ Checklists & Diálogos de Edição em PT-BR:**
  - Templates padrão de Checklists agora são criados nativamente em português (mantendo tradução automática para listas antigas em inglês).
  - Dropdowns de categorias nos diálogos de edição (Tarefas, Checklists, Gastos e Metas de Economia) agora exibem nomes 100% em português, incluindo a categoria `Veículo` em Finanças.
- **💬 Pergunta do Dia, Calendário, Humor & Notificações:**
  - `getPromptForDate` padronizado em PT-BR por padrão e busca no histórico agora encontra perguntas antigas em inglês usando termos em português.
  - Eventos antigos de aniversário em inglês (`Our Anniversary`) traduzidos no Calendário, na Home ("Nosso Dia"), na edição/exclusão e nas notificações agendadas.
  - Humores do parceiro e mensagens de erro (Pareamento, Cofre e Desenhar Juntos) padronizados em PT-BR.
- **📱 Widgets Android Glance em PT-BR:**
  - Padrão PT-BR em toda sincronização de widgets (inclusive em segundo plano no WorkManager), placeholder `Carregando Krivo...`, tradução automática de perguntas e raspadinhas no idioma do receptor e nome do app unificado como **Krivo**.

---

# Couple App v1.1.0 — Paridade Krivo, Home Viva "Nosso Dia", Desenhar Juntos & Sync em Segundo Plano 💑✨

### ✨ O que há de novo

- **🏠 Nova Home Viva ("Nosso Dia") & Presença do Casal:**
  - Nova aba principal com cabeçalho do casal (foto/avatar editável, apelidos e data de namoro), contador de **streak diário**, status do parceiro em tempo real, banner de SOS/cutucada, status da Pergunta do Dia, recado/desenho fixado, raspadinha surpresa e resumo de tarefas e próximos eventos.
  - Emblemas (badges) na barra de navegação e banner ao vivo de atividades do parceiro.
- **🔔 Notificações Confiáveis em Segundo Plano (Samsung One UI — R$ 0 Spark Tier):**
  - Sincronização periódica em segundo plano a cada 15 minutos via Android `WorkManager`.
  - Canais separados no Android para alertas urgentes (SOS/Cutucar) e atividades rotineiras.
  - Guia dedicado no Hub (**"Garantir alertas no Samsung"**) com atalho para desativar otimização de bateria.
- **🎨 Desenhar Juntos + Widget de Desenho + Galeria:**
  - Tela colaborativa de desenho em tempo real com cores, espessuras, borracha, desfazer, limpar e fundo personalizável.
  - Fixe um desenho diretamente no Widget Android da tela inicial do parceiro (último fixado entre recado ou desenho vence) ou salve na Galeria do celular.
- **💘 Swipe de Encontros + Catálogo 40 PT-BR + Match → Calendário:**
  - Novo modo Swipe com 40 ideias curadas em português, revisão de descartados, sorteio rápido e celebração de **Deu Match!** com agendamento direto no Calendário.
- **💬 Pergunta do Dia Interativa:**
  - Reações com emoji, comentários do casal, botão de cutucar parceiro, contagem regressiva para a próxima pergunta, busca no histórico e agendamento de **Perguntas Surpresa** futuras.
- **✏️ Edição Completa nos 8 Módulos + Estabilização Geral:**
  - Edição rápida para Tarefas, Checklists, Gastos (com suporte nativo a valores em `R$`), Metas, Memórias, Desejos, Cofre Privado (re-criptografia AES-256-GCM) e Cupons de Amor.
  - Correções críticas de estabilidade: QR Code de pareamento, fuso horário local nas notificações, Cofre zero-knowledge com sentinel de PIN, limpeza ao sair do espaço e tradução PT-BR/EN nas telas v1.0.4.

---

# Couple App v1.0.3 — Localização Completa & Correção no Verificador de Atualizações 💑📱

### ✨ O que há de novo / What's New

- **🇧🇷 100% dos Textos Restantes em Português:**
  - **Pareamento & Conexão:** Tela de pareamento, botões "Entrar no Nosso Espaço", "Copiar Código", avisos de espera e mensagens de validação traduzidos.
  - **Finanças Compartilhadas:** Modais de quitação geral de contas, confirmação de exclusão de despesas/metas e validações de formulário traduzidos.
  - **Memórias & Baú:** Alertas de validação de URL, avisos de carregamento de fotos e títulos de desejos e cápsulas em português.
  - **Recadinhos & Notas de Amor:** Diálogo de confirmação de exclusão de recado e avisos de salvamento traduzidos.
- **🔄 Verificador de Atualizações Mais Preciso:**
  - Tratamento de erro detalhado na verificação de versão para evitar falso positivo de "aplicativo atualizado" quando houver falha de rede ou acesso.

---

# Couple App v1.0.2 — Localização 100% Português & Contraste Modo Escuro 💑📱

### ✨ O que há de novo / What's New

- **🇧🇷 Tradução 100% Completa para Português em Todo o Aplicativo:**
  - **Decidir Juntos & Ideias de Encontros:** Votações secretas, desempate no cara ou coroa, destaques da semana, categorias traduzidas (*Aconchegante, Ao Ar Livre, Gastronômico, Romântico, Aventura, Econômico*) e modais de criação.
  - **Finanças Compartilhadas & Cofrinho:** Cards de resumo, filtros, formulários de despesas e metas de economia traduzidos.
  - **Linha do Tempo, Cápsulas do Tempo & Desejos:** Telas vazias, botões, selamento de cartas e confirmações de exclusão em português.
  - **Calendário & Momentos:** Contagem regressiva de aniversário, chips e formulários de eventos em português com datas no formato brasileiro.
  - **Mural de Recados & Notas de Amor:** Instruções do widget, botões de ação e modais totalmente em português.
  - **Tarefas & Afazeres:** Filtros (*Compartilhada, Você, Para Mim*), prazos (*Hoje, Atrasada*) e checklists.

- **🌙 Contraste Otimizado para o Modo Escuro (AMOLED High Contrast):**
  - Corrigido o card verde de Finanças para verde escuro profundo no modo escuro, garantindo legibilidade perfeita de valores e textos.
  - Corrigidos os chips de filtro em Finanças e Ideias de Encontros (eliminado o fundo branco ofuscante).
  - Todas as folhas inferiores (bottom sheets) agora usam a cor de fundo adaptativa do tema (`context.cardColor`), eliminando o branco ofuscante no modo escuro.
  - Contornos, bordas e subtítulos adaptados dinamicamente com contraste WCAG AAA.

- **🚀 Publicação Automática no GitHub Releases (OTA):**
  - O aplicativo atualiza automaticamente via OTA sempre que uma nova tag `v*` é publicada no repositório GitHub.

---

# Couple App v1.0.1 — Atualização & Correções 💑📱

### ✨ O que há de novo / What's New

- **🛠️ Correção Visual no Card de Preferências:**
  - Corrigido o bug de quebra vertical de caracteres em "Tema" e "Versão do App".
  - Seletor de Tema reorganizado em layout limpo de largura total com alternância rápida entre Claro, Escuro e Sistema.
  - Botão de checagem de atualizações otimizado com padding compacto e dimensões seguras.

- **🇧🇷 Tradução Completa para Português:**
  - Tela de Conexão Diária totalmente localizada (perguntas, alertas de revelação dupla, botões de envio e histórico de memórias).
  - Data de hoje exibida em português natural (`Quinta-feira, 5 de novembro`).
  - Títulos, abas e filtros de Tarefas totalmente em português.

- **📱 Widgets Android Glance 100% Funcionais:**
  - Corrigido o ciclo de vida dos 4 receivers nativos Kotlin (`GlanceAppWidgetReceiver.onUpdate`) para que os widgets reflitam alterações imediatamente na tela inicial do celular.
  - Sincronização reativa contínua em segundo plano com Riverpod para dados do casal, tarefas urgentes, status da pergunta diária e mural de notas.
  - Textos dos widgets e do seletor nativo do Android totalmente traduzidos para Português (Brasil).

- **🔄 Atualizações Automáticas (OTA) via GitHub Releases:**
  - Sistema de publicação automatizada no GitHub Actions configurado para compilar e anexar o APK a cada nova versão.

---

# Couple App v1.0.0 — Initial Android Release 💑📱

Welcome to the initial release of **Couple App**! Designed specifically for couples with real-time pairing, bilingual support, high-contrast dark mode, and encrypted private features.

### ✨ What's New

- **🇧🇷 Português & 🇺🇸 English (Bilingual Support):**
  - Brazilian Portuguese enabled as default locale out-of-the-box.
  - Complete localization across all navigation tabs, settings, dialogs, and features.
  - 50 romantic daily question prompts localized in Brazilian Portuguese.
  - Quick language switch directly on the initial pairing screen and in the Couple Hub settings.

- **🌙 AMOLED Dark Mode & High-Contrast Typography:**
  - Optimized for Samsung Galaxy AMOLED displays (S22 Ultra, S24 Plus, etc.).
  - Secondary text contrast boosted to 8.5:1 (WCAG AAA compliant) with crisp off-white typography.
  - Theme toggle (Claro / Escuro / Sistema) available in Couple Hub and on the pairing screen.

- **💰 Brazilian Real (R$) Finance Segment:**
  - All shared expense management, split-bill tracking, and budget inputs formatted in `R$`.
  - Color-coded balance summaries with dark-mode adaptive surfaces.

- **🔐 End-to-End Encrypted Private Vault:**
  - AES-256-GCM client-side encryption with PBKDF2 key derivation from a 6-digit PIN.
  - Zero-knowledge storage for partner secrets, size cheatsheet, and private notes.

- **⚡ Cloud Architecture:**
  - Powered 100% by Google Firebase Free Spark Tier (Firestore, Anonymous Auth, Cloud Storage).
  - $0/month forever with zero paid cloud function dependencies.

---

### 📦 Sideload Installation Instructions (Galaxy S22 Ultra & Galaxy S24 Plus)
1. Download `CoupleApp-Release.apk` directly from this release onto your Samsung device.
2. Open **My Files** (*Meus Arquivos*) -> **Downloads**.
3. Tap `CoupleApp-Release.apk` to install.
4. If prompted to allow installation from unknown sources, enable permission for *My Files*.
5. Launch the app and enjoy!
