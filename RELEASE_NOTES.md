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
