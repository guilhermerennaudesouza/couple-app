import 'package:flutter/material.dart';

/// Strongly-typed bilingual string dictionary for the Couple App.
/// Supports Brazilian Portuguese (`pt-BR`) and English (`en-US`).
class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  bool get isPortuguese => locale.languageCode == 'pt';

  /// Obtains the [AppStrings] instance matching the current [BuildContext] locale.
  static AppStrings of(BuildContext context) {
    final loc = Localizations.maybeLocaleOf(context) ?? const Locale('pt', 'BR');
    return ofLocale(loc);
  }

  /// Obtains the [AppStrings] instance matching the specified [Locale].
  static AppStrings ofLocale(Locale locale) {
    return AppStrings(locale);
  }

  // --- Navigation & Core Shell ---
  String get appTitle => 'Couple App';
  String get navToday => isPortuguese ? 'Hoje' : 'Today';
  String get navTasks => isPortuguese ? 'Tarefas' : 'Tasks';
  String get navCalendar => isPortuguese ? 'Calendário' : 'Calendar';
  String get navDecide => isPortuguese ? 'Decidir' : 'Decide';
  String get navHub => isPortuguese ? 'Espaço' : 'Hub';
  String get hubTitle => isPortuguese ? 'Nosso Espaço' : 'Couple Hub';

  // --- Settings & Preferences ---
  String get settings => isPortuguese ? 'Preferências' : 'Preferences';
  String get theme => isPortuguese ? 'Tema' : 'Theme';
  String get themeLight => isPortuguese ? 'Claro' : 'Light';
  String get themeDark => isPortuguese ? 'Escuro' : 'Dark';
  String get themeSystem => isPortuguese ? 'Sistema' : 'System';
  String get language => isPortuguese ? 'Idioma' : 'Language';
  String get langPt => 'Português (Brasil)';
  String get langEn => 'English (US)';
  String get retry => isPortuguese ? 'Tentar Novamente' : 'Retry';
  String get cancel => isPortuguese ? 'Cancelar' : 'Cancel';
  String get save => isPortuguese ? 'Salvar' : 'Save';
  String get delete => isPortuguese ? 'Excluir' : 'Delete';
  String get edit => isPortuguese ? 'Editar' : 'Edit';
  String get copied => isPortuguese ? 'Copiado para a área de transferência!' : 'Copied to clipboard!';

  // --- In-App Updates ---
  String get updateAvailableTitle => isPortuguese ? 'Nova Atualização Disponível! 🚀' : 'New Update Available! 🚀';
  String updateAvailableBody(String version) => isPortuguese
      ? 'Uma nova versão ($version) está disponível. Deseja atualizar agora?'
      : 'A new version ($version) is available. Would you like to update now?';
  String get updateNow => isPortuguese ? 'Atualizar Agora' : 'Update Now';
  String get updateLater => isPortuguese ? 'Lembrar Depois' : 'Later';
  String get updateChecking => isPortuguese ? 'Verificando atualizações...' : 'Checking for updates...';
  String get updateUpToDate => isPortuguese ? 'Você já está na versão mais recente! ✨' : 'You are on the latest version! ✨';
  String updateDownloading(String progress) => isPortuguese ? 'Baixando atualização: $progress%' : 'Downloading update: $progress%';
  String get updateError => isPortuguese ? 'Não foi possível baixar a atualização. Tente novamente mais tarde.' : 'Could not download update. Please try again later.';
  String get checkForUpdates => isPortuguese ? 'Verificar Atualizações' : 'Check for Updates';
  String get appVersionLabel => isPortuguese ? 'Versão do App' : 'App Version';

  // --- Couple Hub Screen ---
  String get spaceHeroTag => isPortuguese ? 'NOSSO ESPAÇO KRIVO' : 'KRIVO COUPLE HUB';
  String get privateSpace => isPortuguese ? 'Nosso Espaço Privado' : 'Our Private Space';
  String get anniversary => isPortuguese ? 'Aniversário de Namoro' : 'Anniversary';
  String daysTogetherCount(int count) =>
      isPortuguese ? '$count dias de muito amor 💕' : '$count days of shared love 💕';
  String get featureSpaces => isPortuguese ? 'ESPAÇOS DE RECURSOS' : 'FEATURE SPACES';
  String get spaceDetails => isPortuguese ? 'DETALHES DO ESPAÇO' : 'SPACE DETAILS & SETTINGS';
  String get spaceId => isPortuguese ? 'ID do Espaço' : 'Space ID';
  String get inviteCode => isPortuguese ? 'Código de Convite' : 'Invite Code';
  String get connectionStatus => isPortuguese ? 'Status da Conexão' : 'Connection Status';
  String get pairedStatus => isPortuguese ? 'Conectados (2/2 parceiros) 🎉' : 'Paired (2/2 partners) 🎉';
  String get waitingPartnerStatus => isPortuguese ? 'Aguardando parceiro(a) (1/2)' : 'Waiting for partner (1/2)';
  String get unpairBtn => isPortuguese ? 'Desconectar do Espaço' : 'Unpair / Disconnect Space';
  String get unpairConfirmTitle => isPortuguese ? 'Desconectar do Espaço?' : 'Unpair from Couple Space?';
  String get unpairConfirmDesc => isPortuguese
      ? 'Tem certeza de que deseja desconectar? Você retornará para a tela inicial e precisará do código para reconectar.'
      : 'Are you sure you want to disconnect from this space? You will return to the pairing screen and will need the invite code to reconnect.';

  // Feature Cards in Hub
  String get memoriesTitle => isPortuguese ? 'Memórias, Desejos e Cápsulas' : 'Memories, Wishlist & Capsules';
  String get memoriesSub => isPortuguese
      ? 'Linha do tempo, cápsulas de fotos e lista de desejos'
      : 'Timeline milestones, photo capsules & gift wishes';
  String get financeTitle => isPortuguese ? 'Finanças & Metas Compartilhadas' : 'Shared Finance & Savings';
  String get financeSub => isPortuguese
      ? 'Divisão 50/50, gastos conjuntos e metas no cofrinho'
      : '50/50 splits, custom shares & piggy bank targets';
  String get vaultTitle => isPortuguese ? 'Cofre Secreto Criptografado' : 'Private Encrypted Vault';
  String get vaultSub => isPortuguese
      ? 'Segredos confidenciais com criptografia AES-256 e biometria'
      : 'Zero-knowledge AES-256 encrypted sensitive secrets';
  String get notesTitle => isPortuguese ? 'Notas de Amor & Mural de Recados' : 'Love Notes & Sticky Wall';
  String get notesSub => isPortuguese
      ? 'Post-its coloridos, recadinhos e fixação de widgets'
      : 'Color sticky notes, sweet messages & widget pins';

  // --- Pairing Screen ---
  String get pairingTitle => isPortuguese ? 'Conectar ao Parceiro(a)' : 'Connect with Partner';
  String get pairingSubtitle => isPortuguese
      ? 'Um espaço privado, seguro e feito sob medida para vocês dois.'
      : 'A private, zero-cost, encrypted shared space for the two of you.';
  String get tabCreate => isPortuguese ? 'Criar Espaço' : 'Create Space';
  String get tabJoin => isPortuguese ? 'Entrar com Código' : 'Join Partner';
  String get yourNameLabel => isPortuguese ? 'Seu Nome ou Apelido' : 'Your Name';
  String get yourNameHint => isPortuguese ? 'ex: Guilherme' : 'e.g. Alex';
  String get partnerNameLabel => isPortuguese ? 'Nome do seu Amor' : 'Partner\'s Name';
  String get partnerNameHint => isPortuguese ? 'ex: Naoma' : 'e.g. Sam';
  String get anniversaryLabel => isPortuguese ? 'Data do Início do Relacionamento' : 'Relationship Start Date';
  String get createSpaceBtn => isPortuguese ? 'Criar Nosso Espaço Privado' : 'Create Our Couple Space';
  String get enterInviteCodeLabel => isPortuguese ? 'Código de Convite de 6 Dígitos' : '6-Character Invite Code';
  String get joinSpaceBtn => isPortuguese ? 'Conectar ao Espaço do Parceiro(a)' : 'Join Couple Space';
  String get waitingPartnerBanner => isPortuguese
      ? 'Espaço criado! Compartilhe o código de convite abaixo com seu parceiro(a):'
      : 'Space created! Share this invite code with your partner:';
  String get copyCode => isPortuguese ? 'Copiar Código' : 'Copy Code';

  // --- Daily Question ---
  String get dailyQuestionTitle => isPortuguese ? 'Pergunta do Dia' : 'Daily Question';
  String get dailyQuestionSubtitle => isPortuguese
      ? 'Respondam todos os dias para se conhecerem ainda mais fundo 💕'
      : 'Answer daily to deepen your connection and spark sweet moments 💕';
  String get yourAnswer => isPortuguese ? 'Sua Resposta' : 'Your Answer';
  String get partnerAnswer => isPortuguese ? 'Resposta do seu Amor' : 'Partner\'s Answer';
  String get submitAnswer => isPortuguese ? 'Enviar Resposta' : 'Submit Answer';
  String get waitingToReveal => isPortuguese
      ? 'Sua resposta está salva! Assim que seu parceiro(a) responder, ambas serão reveladas simultaneamente 🔒'
      : 'Your answer is locked! Once your partner answers, both answers will be revealed together 🔒';
  String get answersRevealedTitle => isPortuguese ? 'Respostas Reveladas! 🎉' : 'Answers Revealed! 🎉';
  String get historyTab => isPortuguese ? 'Histórico de Perguntas' : 'Past Questions';
  String get nextQuestionCountdown => isPortuguese ? 'Próxima pergunta em:' : 'Next question in:';

  // --- Tasks ---
  String get tasksTitle => isPortuguese ? 'Tarefas & Compromissos' : 'Couple Tasks';
  String get tasksSubtitle => isPortuguese ? 'Organizem sua rotina e planos juntos' : 'Manage your shared to-dos';
  String get addTaskBtn => isPortuguese ? 'Nova Tarefa' : 'Add Task';
  String get taskTitleHint => isPortuguese ? 'O que precisa ser feito?' : 'Task description...';
  String get assignedToMe => isPortuguese ? 'Para Mim' : 'For Me';
  String get assignedToPartner => isPortuguese ? 'Para Meu Amor' : 'For Partner';
  String get assignedToBoth => isPortuguese ? 'Para Ambos' : 'For Both';
  String get filterAll => isPortuguese ? 'Todas' : 'All';
  String get filterPending => isPortuguese ? 'Pendentes' : 'Pending';
  String get filterDone => isPortuguese ? 'Concluídas' : 'Completed';
  String get categoryChores => isPortuguese ? 'Casa' : 'Chores';
  String get categoryShopping => isPortuguese ? 'Compras' : 'Shopping';
  String get categoryRomance => isPortuguese ? 'Romance' : 'Romance';
  String get categoryTravel => isPortuguese ? 'Viagens' : 'Travel';

  // --- Calendar ---
  String get calendarTitle => isPortuguese ? 'Calendário & Datas Especiais' : 'Couple Calendar';
  String get addEventBtn => isPortuguese ? 'Novo Evento' : 'New Event';
  String get eventTitleHint => isPortuguese ? 'Nome do evento ou comemoração' : 'Event title...';
  String get dateNightTag => isPortuguese ? 'Noite de Encontro' : 'Date Night';
  String get anniversaryTag => isPortuguese ? 'Aniversário' : 'Anniversary';
  String get milestoneTag => isPortuguese ? 'Marco Especial' : 'Milestone';
  String get reminder => isPortuguese ? 'Lembrete' : 'Reminder';

  // --- Decide & Date Ideas ---
  String get decideTitle => isPortuguese ? 'Decidir & Ideias de Encontros' : 'Decide & Date Ideas';
  String get decideSubtitle => isPortuguese
      ? 'Sem saber o que fazer hoje? Girem a roleta ou escolham uma ideia!'
      : 'Can\'t decide what to do? Spin the wheel or pick a curated idea!';
  String get spinWheelBtn => isPortuguese ? 'Girar a Roleta do Encontro! 🎡' : 'Spin Date Night Wheel! 🎡';
  String get addCustomDateBtn => isPortuguese ? 'Sugerir Ideia' : 'Add Date Idea';
  String get budgetAll => isPortuguese ? 'Todos' : 'All';
  String get budgetFree => isPortuguese ? 'Grátis' : 'Free';
  String get budgetLow => isPortuguese ? '\$ Econômico' : '\$ Low';
  String get budgetMedium => isPortuguese ? '\$\$ Médio' : '\$\$ Medium';
  String get budgetFancy => isPortuguese ? '\$\$\$ Especial' : '\$\$\$ Fancy';
  String get markAsDone => isPortuguese ? 'Já fizemos!' : 'Completed';

  // --- Love Notes ---
  String get notesTitleBar => isPortuguese ? 'Mural de Recados & Notas' : 'Love Notes & Sticky Wall';
  String get addNoteBtn => isPortuguese ? 'Escrever Recado' : 'Write Note';
  String get pinToWidget => isPortuguese ? 'Fixar no Widget da Tela Inicial' : 'Pin to Home Widget';
  String get noteHint => isPortuguese ? 'Escreva uma mensagem doce para seu amor...' : 'Write a sweet note...';

  // --- Finance & Piggy Bank ---
  String get financeTitleBar => isPortuguese ? 'Finanças & Economias' : 'Shared Finance';
  String get addExpenseBtn => isPortuguese ? 'Novo Gasto' : 'Add Expense';
  String get piggyBankTitle => isPortuguese ? 'Cofrinho de Metas' : 'Savings Piggy Bank';
  String get addSavingsGoal => isPortuguese ? 'Nova Meta de Economia' : 'New Savings Goal';
  String get totalBalance => isPortuguese ? 'Balanço Geral' : 'Net Balance';
  String get youOwe => isPortuguese ? 'Você deve' : 'You owe';
  String get partnerOwes => isPortuguese ? 'Seu amor te deve' : 'Partner owes you';
  String get settled => isPortuguese ? 'Tudo acertado! 💖' : 'All settled up! 💖';

  // --- Memories, Wishlist & Capsules ---
  String get memoriesTitleBar => isPortuguese ? 'Memórias & Desejos' : 'Memories & Wishlist';
  String get addMemoryBtn => isPortuguese ? 'Adicionar Foto / Memória' : 'Add Memory';
  String get timeCapsuleTitle => isPortuguese ? 'Cápsulas do Tempo' : 'Time Capsules';
  String get createCapsuleBtn => isPortuguese ? 'Criar Cápsula do Tempo' : 'Create Time Capsule';
  String get wishlistTitle => isPortuguese ? 'Lista de Desejos' : 'Shared Wishlist';
  String get addWishBtn => isPortuguese ? 'Adicionar Desejo' : 'Add Wish';
  String get lockedUntil => isPortuguese ? 'Bloqueada até:' : 'Locked until:';

  // --- Private Vault ---
  String get vaultTitleBar => isPortuguese ? 'Cofre Secreto' : 'Private Encrypted Vault';
  String get authenticatePrompt => isPortuguese ? 'Autentique-se com biometria ou PIN' : 'Authenticate with biometrics';
  String get addSecretBtn => isPortuguese ? 'Novo Registro Seguro' : 'Add Secret Card';
  String get unlockVault => isPortuguese ? 'Desbloquear Cofre' : 'Unlock Vault';
  String get cheatsheetTitle => isPortuguese ? 'Manual & Gostos do Meu Amor' : 'Partner Cheat Sheet';
}
