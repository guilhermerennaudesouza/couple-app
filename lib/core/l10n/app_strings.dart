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
  String get dailyConnectionTitle => isPortuguese ? 'Conexão Diária' : 'Daily Connection';
  String get dailyQuestionSubtitle => isPortuguese
      ? 'Respondam todos os dias para se conhecerem ainda mais fundo 💕'
      : 'Answer daily to deepen your connection and spark sweet moments 💕';
  String get tabTodayPrompt => isPortuguese ? 'Pergunta de Hoje' : "Today's Prompt";
  String get tabPastMemories => isPortuguese ? 'Memórias Anteriores' : 'Past Memories';
  String get dualBlindRevealBadge => isPortuguese ? 'Revelação Dupla' : 'Dual-Blind Reveal';
  String get todayQuestionTag => isPortuguese ? 'PERGUNTA DE HOJE' : "TODAY'S QUESTION";
  String get sealedNotice => isPortuguese
      ? 'Sua resposta fica oculta até que ambos respondam. Sem espiar!'
      : 'Your answer stays sealed until both of you reply. No peeking!';
  String get answerPlaceholder => isPortuguese
      ? 'Compartilhe seus pensamentos, sentimentos ou memórias com seu amor...'
      : 'Share your loving thought, memory, or feeling...';
  String get sendAnswerBtn => isPortuguese ? 'Enviar Minha Resposta' : 'Send My Answer';
  String get emptyAnswerError => isPortuguese
      ? 'Por favor, escreva uma resposta antes de enviar!'
      : 'Please write an answer before sending!';
  String get answerSealedSuccess => isPortuguese
      ? 'Sua resposta foi guardada! Aguardando seu parceiro(a)...'
      : 'Your answer is sealed! Waiting for partner...';
  String get waitingForPartnerTitle => isPortuguese ? 'Resposta Guardada a Sete Chaves! 🔒' : 'Your Answer is Sealed! 🔒';
  String waitingForPartnerDesc(String name) => isPortuguese
      ? 'Aguardando $name responder para revelar ambas as respostas simultaneamente 💕'
      : 'Waiting for $name to answer to reveal both answers together 💕';
  String get bothAnsweredTitle => isPortuguese ? 'Respostas Reveladas! 💕' : 'Both Answered! 💕';
  String get tapToReadAnswers => isPortuguese
      ? 'Vocês dois responderam à pergunta de hoje!'
      : 'Both of you answered today\'s question!';
  String get noPastAnswers => isPortuguese ? 'Nenhuma resposta anterior ainda.' : 'No past answers yet.';
  String get loveNotesTooltip => isPortuguese ? 'Mural de Recados & Notas' : 'Love Notes & Sticky Wall';
  String get howItWorksTooltip => isPortuguese ? 'Como Funciona a Revelação Dupla' : 'How Dual Reveal Works';
  String get howItWorksTitle => isPortuguese ? 'Como Funciona a Revelação Dupla' : 'How Dual Reveal Works';
  String get howItWorksBody => isPortuguese
      ? 'Para incentivar respostas 100% sinceras e sem viés, a resposta de cada parceiro fica oculta até que ambos tenham respondido. Assim que os dois enviarem suas respostas, elas serão reveladas juntas!'
      : 'To encourage completely honest answers, each response remains sealed until both partners have replied. Once both have answered, both responses are unlocked together!';
  String get understood => isPortuguese ? 'Entendido!' : 'Got it!';
  String get yourAnswer => isPortuguese ? 'Sua Resposta' : 'Your Answer';
  String get partnerAnswer => isPortuguese ? 'Resposta do seu Amor' : 'Partner\'s Answer';
  String get submitAnswer => isPortuguese ? 'Enviar Resposta' : 'Submit Answer';
  String get waitingToReveal => isPortuguese
      ? 'Sua resposta está salva! Assim que seu parceiro(a) responder, ambas serão reveladas simultaneamente 🔒'
      : 'Your answer is locked! Once your partner answers, both answers will be revealed together 🔒';
  String get answersRevealedTitle => isPortuguese ? 'Respostas Reveladas! 🎉' : 'Answers Revealed! 🎉';
  String get historyTab => isPortuguese ? 'Histórico de Perguntas' : 'Past Questions';
  String get nextQuestionCountdown => isPortuguese ? 'Próxima pergunta em:' : 'Next question in:';
  String get couldNotLoadQuestion => isPortuguese ? 'Não foi possível carregar a pergunta:' : 'Could not load today\'s question:';
  String get errorLoadingArchive => isPortuguese ? 'Erro ao carregar o histórico:' : 'Error loading archive:';
  String get searchPastQuestions => isPortuguese ? 'Buscar perguntas anteriores...' : 'Search past questions...';
  String get noMatchingQuestions => isPortuguese ? 'Nenhuma pergunta encontrada.' : 'No matching questions.';
  String get unrevealedMemoryBadge => isPortuguese ? 'Não Revelada' : 'Unrevealed';
  String get mutualMemoryBadge => isPortuguese ? 'Revelada Juntos 💕' : 'Revealed Together 💕';
  String get answeredDateLabel => isPortuguese ? 'Respondido' : 'Answered';
  String get writeYourAnswerFirst => isPortuguese ? 'Responda primeiro para ver!' : 'Answer first to see!';

  // --- Tasks ---
  String get sharedTasksTitle => isPortuguese ? 'Tarefas & Listas' : 'Shared Tasks & Lists';
  String get tasksTab => isPortuguese ? 'Tarefas & Afazeres' : 'Tasks & Chores';
  String get listsTab => isPortuguese ? 'Listas Compartilhadas' : 'Shared Lists';
  String get newTask => isPortuguese ? 'Nova Tarefa' : 'New Task';
  String get newList => isPortuguese ? 'Nova Lista' : 'New List';
  String get noSpaceConnected => isPortuguese ? 'Nenhum Espaço Conectado' : 'No Couple Space Connected';
  String get noSpaceConnectedDesc => isPortuguese
      ? 'Por favor, conecte-se ao seu parceiro(a) antes de gerenciar tarefas e listas.'
      : 'Please pair with your partner before managing shared tasks and lists.';

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


  // --- Love Notes ---
  String get notesTitleBar => isPortuguese ? 'Mural de Recados & Notas' : 'Love Notes & Sticky Wall';
  String get loveNotesAndWidget => isPortuguese ? 'Notas de Amor & Widget' : 'Love Notes & Widget';
  String get addNoteBtn => isPortuguese ? 'Escrever Recado' : 'Write Note';
  String get newNote => isPortuguese ? 'Novo Recado' : 'New Note';
  String get leaveFirstLoveNote => isPortuguese ? 'Deixar Primeiro Recado' : 'Leave First Love Note';
  String get noStickyNotesYet => isPortuguese ? 'Nenhum recado ainda' : 'No Sticky Notes Yet';
  String get noStickyNotesDesc => isPortuguese
      ? 'Deixe surpresas carinhosas, elogios diários ou lembretes para seu amor. Fixe seu recado favorito no widget da tela inicial do celular dele(a)!'
      : 'Leave sweet surprises, daily compliments, or reminders for your partner. Pin your favorite note directly to their Android Home Screen widget!';
  String get widgetInfo => isPortuguese ? 'Sobre o Widget' : 'Widget Info';
  String get widgetInfoTitle => isPortuguese ? 'Como Funciona o Widget?' : 'How Notes Widget Works';
  String get widgetInfoDesc => isPortuguese
      ? 'Ao fixar um recado com o ícone de alfinete 📌, ele será exibido diretamente na tela inicial do celular do seu parceiro(a) através do Widget do Android!'
      : 'When you pin a note using the pin icon 📌, it will appear directly on your partner\'s home screen via the Android Widget!';
  String get editNoteTitle => isPortuguese ? 'Editar Recado' : 'Edit Note';
  String get createNoteTitle => isPortuguese ? 'Novo Recado de Amor' : 'New Love Note';
  String get noteContentHint => isPortuguese ? 'Escreva aqui sua mensagem carinhosa...' : 'Write your loving message here...';
  String get pinToWidget => isPortuguese ? 'Fixar no Widget da Tela Inicial' : 'Pin to Home Widget';
  String get pinnedToWidgetBadge => isPortuguese ? 'Fixado no Widget 📌' : 'Pinned to Widget 📌';
  String get noteHint => isPortuguese ? 'Escreva uma mensagem doce para seu amor...' : 'Write a sweet note...';

  // --- Finance & Piggy Bank ---
  String get financeTitleBar => isPortuguese ? 'Finanças & Economias' : 'Shared Finance & Savings';
  String get tabSharedExpenses => isPortuguese ? 'Gastos Compartilhados' : 'Shared Expenses';
  String get tabSavingsPiggyBank => isPortuguese ? 'Cofrinho de Metas' : 'Savings Piggy Bank';
  String get addExpenseBtn => isPortuguese ? 'Novo Gasto' : 'Add Expense';
  String get newGoal => isPortuguese ? 'Nova Meta' : 'New Goal';
  String get allSettledUp => isPortuguese ? 'Tudo acertado! 🎉' : 'All settled up! 🎉';
  String noPendingBalances(String name) => isPortuguese
      ? 'Sem pendências financeiras entre você e $name.'
      : 'No pending balances between you and $name.';
  String youAreOwed(String amount) => isPortuguese
      ? 'Você tem a receber R\$ $amount 💚'
      : 'You are owed R\$ $amount 💚';
  String partnerOwesYou(String name) => isPortuguese
      ? '$name deve a você pelos gastos compartilhados.'
      : '$name owes you for shared expenses.';
  String youOweAmount(String amount) => isPortuguese
      ? 'Você deve R\$ $amount 🧡'
      : 'You owe R\$ $amount 🧡';
  String youOwePartner(String name) => isPortuguese
      ? 'Você deve a $name pelos gastos compartilhados.'
      : 'You owe $name for shared expenses.';
  String unsettledTotal(String amount) => isPortuguese
      ? 'Total Pendente: R\$ $amount'
      : 'Unsettled Total: R\$ $amount';
  String openItemsCount(int count) => isPortuguese
      ? '$count ite${count == 1 ? "m" : "ns"} em aberto'
      : '$count open item(s)';
  String get settleUpBtn => isPortuguese ? 'Acertar Contas' : 'Settle Up';
  String get settleUpConfirmTitle => isPortuguese ? 'Acertar todas as contas?' : 'Settle All Balances?';
  String get settleUpConfirmDesc => isPortuguese
      ? 'Isso marcará todos os gastos em aberto como quitados, zerando o saldo entre vocês.'
      : 'This will mark all open expenses as settled, resetting your balance.';
  String get noExpensesRecorded => isPortuguese ? 'Nenhum gasto registrado' : 'No expenses recorded';
  String get noExpensesDesc => isPortuguese
      ? 'Toque em "+ Novo Gasto" para registrar jantares, compras do mercado ou viagens juntos!'
      : 'Tap "+ Add Expense" to log dinners, groceries, or vacations together!';
  String get categoryAll => isPortuguese ? 'Todos' : 'All';
  String get categoryDining => isPortuguese ? 'Restaurantes' : 'Dining';
  String get categoryGroceries => isPortuguese ? 'Mercado' : 'Groceries';
  String get categoryTravelFinance => isPortuguese ? 'Viagens' : 'Travel';
  String get categoryHomeFinance => isPortuguese ? 'Casa' : 'Home';
  String get categoryEntertainment => isPortuguese ? 'Lazer' : 'Entertainment';
  String get categoryBills => isPortuguese ? 'Contas' : 'Bills';
  String get categoryOther => isPortuguese ? 'Outros' : 'Other';
  String get piggyBankTitle => isPortuguese ? 'Cofrinho de Metas' : 'Savings Piggy Bank';
  String get addSavingsGoal => isPortuguese ? 'Nova Meta de Economia' : 'New Savings Goal';
  String get totalBalance => isPortuguese ? 'Balanço Geral' : 'Net Balance';
  String get youOwe => isPortuguese ? 'Você deve' : 'You owe';
  String get partnerOwes => isPortuguese ? 'Seu amor te deve' : 'Partner owes you';
  String get settled => isPortuguese ? 'Tudo acertado! 💖' : 'All settled up! 💖';

  // --- Memories, Wishlist & Capsules ---
  String get memoriesTitleBar => isPortuguese ? 'Memórias & Desejos' : 'Memories & Vault';
  String get tabTimeline => isPortuguese ? 'Linha do Tempo' : 'Timeline';
  String get tabTimeCapsules => isPortuguese ? 'Cápsulas do Tempo' : 'Time Capsules';
  String get tabWishlist => isPortuguese ? 'Lista de Desejos' : 'Wishlist';
  String get noMemoriesYet => isPortuguese ? 'Nenhuma memória ainda' : 'No Memories Yet';
  String get noMemoriesDesc => isPortuguese
      ? 'Registre seus encontros favoritos, viagens e momentos inesquecíveis juntos.'
      : 'Capture your favorite dates, trips, and milestone moments together.';
  String get addFirstMemory => isPortuguese ? 'Adicionar Primeira Memória' : 'Add First Memory';
  String get addMemoryBtn => isPortuguese ? 'Adicionar Memória' : 'Add Memory';
  String get sealCapsule => isPortuguese ? 'Selar Cápsula' : 'Seal Capsule';
  String get timeCapsuleTitle => isPortuguese ? 'Cápsulas do Tempo' : 'Time Capsules';
  String get createCapsuleBtn => isPortuguese ? 'Criar Cápsula do Tempo' : 'Create Time Capsule';
  String get wishlistTitle => isPortuguese ? 'Lista de Desejos' : 'Shared Wishlist';
  String get addWishBtn => isPortuguese ? 'Adicionar Desejo' : 'Add Wish';
  String get lockedUntil => isPortuguese ? 'Bloqueada até:' : 'Locked until:';

  // --- Decide & Date Ideas ---
  String get decideTitle => isPortuguese ? 'Decidir Juntos' : 'Decide & Do Together';
  String get tabDecideTogether => isPortuguese ? 'Votações' : 'Decide Together';
  String get tabDateIdeas => isPortuguese ? 'Ideias de Encontros' : 'Date Ideas';
  String get noBallotsYet => isPortuguese ? 'Nenhuma votação ainda' : 'No Ballots Yet';
  String get noBallotsDesc => isPortuguese
      ? 'Não conseguem decidir o que comer, qual filme assistir ou para onde ir? Criem uma votação secreta!'
      : 'Cannot decide what to eat, what movie to watch, or where to go? Create your first secret ballot!';
  String get newBallotBtn => isPortuguese ? 'Nova Votação' : 'New Ballot';
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

  // --- Calendar ---
  String get calendarTitle => isPortuguese ? 'Nosso Calendário & Momentos' : 'Our Calendar & Moments';
  String get anniversaryCountdown => isPortuguese ? 'CONTAGEM REGRESSIVA' : 'ANNIVERSARY COUNTDOWN';
  String get daysUntilAnniversary => isPortuguese ? 'dias para o nosso aniversário ✨' : 'days until our anniversary ✨';
  String get dayUntilAnniversary => isPortuguese ? 'dia para o nosso aniversário ✨' : 'day until our anniversary ✨';
  String daysTogetherMilestone(int days, int year) => isPortuguese
      ? '$days dias de muito amor · Rumo ao ano $year 💕'
      : '$days days of shared love · Year $year milestone ahead';
  String get happyAnniversaryToday => isPortuguese ? '🎉 Feliz Aniversário de Namoro! ❤️' : '🎉 Happy Anniversary! ❤️';
  String get happyAnniversaryDesc => isPortuguese
      ? 'Hoje é o dia especial de vocês. Comemorem cada segundo juntos!'
      : 'Today is your special day. Cherish every second together!';
  String get addMoment => isPortuguese ? 'Adicionar Momento' : 'Add Moment';
  String get annualEvent => isPortuguese ? 'Anual' : 'Annual';
  String inDays(int n) => isPortuguese ? 'Em $n dias' : 'In $n days';
  String get todayTag => isPortuguese ? 'Hoje!' : 'Today!';
  String notifyDaysBefore(int d) => isPortuguese ? '${d}d antes' : '${d}d before';
  String get addEventBtn => isPortuguese ? 'Novo Evento' : 'New Event';
  String get eventTitleHint => isPortuguese ? 'Nome do evento ou comemoração' : 'Event title...';
  String get dateNightTag => isPortuguese ? 'Noite de Encontro' : 'Date Night';
  String get anniversaryTag => isPortuguese ? 'Aniversário' : 'Anniversary';
  String get milestoneTag => isPortuguese ? 'Marco Especial' : 'Milestone';
  String get reminder => isPortuguese ? 'Lembrete' : 'Reminder';

  // --- Tasks extra ---
  String get noTasksFound => isPortuguese ? 'Nenhuma tarefa encontrada' : 'No tasks found';
  String get noCompletedTasksDesc => isPortuguese ? 'Nenhuma tarefa concluída ainda. Finalizem uma tarefa juntos para vê-la aqui!' : 'No completed tasks yet. Finish a task together to see it here!';
  String get noTasksDesc => isPortuguese ? 'Tudo em dia! Toque no botão abaixo para adicionar sua primeira tarefa ou afazer.' : 'All caught up! Tap the button below to add your first chore or to-do.';
  String get sharedBadge => isPortuguese ? 'Compartilhada' : 'Shared';
  String get youBadge => isPortuguese ? 'Você' : 'You';
  String get todayBadge => isPortuguese ? 'Hoje' : 'Today';
  String overdueBadge(String date) => isPortuguese ? 'Atrasada ($date)' : 'Overdue ($date)';
  String taskDeleted(String title) => isPortuguese ? 'Tarefa "$title" excluída' : 'Task "$title" deleted';
  String get noChecklistsYet => isPortuguese ? 'Nenhuma lista ainda' : 'No checklists yet';
  String get noChecklistsDesc => isPortuguese ? 'Comece com nossos modelos prontos ou crie a sua!' : 'Start with our curated templates or make your own!';
  String get addTemplatesBtn => isPortuguese ? 'Adicionar Modelos Prontos' : 'Add Pre-made Templates';
  String get deleteList => isPortuguese ? 'Excluir Lista' : 'Delete List';
  String get noItemsYet => isPortuguese ? 'Nenhum item ainda. Digite abaixo para adicionar!' : 'No items yet. Type below to add!';
  String get addAnItem => isPortuguese ? 'Adicionar item...' : 'Add an item...';
  String get addTaskOrChore => isPortuguese ? 'Adicionar Tarefa ou Afazer' : 'Add Task or Chore';
  String get taskTitleLabel => isPortuguese ? 'Título da Tarefa *' : 'Task Title *';
  String get taskTitleExample => isPortuguese ? 'ex: Limpar a máquina de café' : 'e.g., Clean the coffee machine';
  String get taskNotesLabel => isPortuguese ? 'Notas / Detalhes (Opcional)' : 'Notes / Description (Optional)';
  String get taskNotesHint => isPortuguese ? 'Adicione detalhes ou contexto...' : 'Add details or context...';
  String get categoryLabel => isPortuguese ? 'Categoria' : 'Category';
  String get assignToLabel => isPortuguese ? 'Atribuir a' : 'Assign To';
  String get unassignedLabel => isPortuguese ? 'Não atribuído' : 'Unassigned';
  String get meLabel => isPortuguese ? 'Para Mim' : 'Me';
  String get setDueDate => isPortuguese ? 'Definir Data de Vencimento' : 'Set Due Date';
  String dueOn(String date) => isPortuguese ? 'Vence: $date' : 'Due: $date';
  String get saveTask => isPortuguese ? 'Salvar Tarefa' : 'Save Task';
  String get createSharedChecklist => isPortuguese ? 'Criar Lista Compartilhada' : 'Create Shared Checklist';
  String get listTitleLabel => isPortuguese ? 'Título da Lista *' : 'List Title *';
  String get listTitleExample => isPortuguese ? 'ex: Compras da semana' : 'e.g., Weekly Farmers Market';
  String get createListBtn => isPortuguese ? 'Criar Lista' : 'Create List';

  // --- Private Vault & Cheatsheet ---
  String get vaultTitleBar => isPortuguese ? 'Cofre Secreto & Medidas' : 'Private Vault & Cheatsheet';
  String get tabSecretVault => isPortuguese ? 'Cofre Criptografado 🔐' : 'Private Vault 🔐';
  String get tabPartnerCheatsheet => isPortuguese ? 'Guia do Amor 📝' : 'Partner Cheatsheet 📝';
  String get lockNow => isPortuguese ? 'Trancar Agora' : 'Lock Now';
  String get vaultLocked => isPortuguese ? 'Cofre trancado 🔒' : 'Vault locked 🔒';
  String get enterPinPrompt => isPortuguese ? 'Digite seu PIN de 6 dígitos' : 'Enter your 6-digit PIN';
  String get setupPinPrompt => isPortuguese ? 'Cadastre um PIN de 6 dígitos' : 'Set up a 6-digit PIN';
  String get confirmPinPrompt => isPortuguese ? 'Confirme o PIN de 6 dígitos' : 'Confirm your 6-digit PIN';
  String get unlockWithBiometrics => isPortuguese ? 'Desbloquear com Biometria' : 'Unlock with Biometrics';
  String get incorrectPin => isPortuguese ? 'PIN incorreto. Tente novamente.' : 'Incorrect PIN. Please try again.';
  String get cheatsheetMe => isPortuguese ? 'Minhas Medidas & Gostos' : 'My Sizes & Preferences';
  String cheatsheetPartner(String name) => isPortuguese ? 'Medidas de $name' : '$name\'s Sizes & Preferences';
  String get authenticatePrompt => isPortuguese ? 'Autentique-se com biometria ou PIN' : 'Authenticate with biometrics';
  String get addSecretBtn => isPortuguese ? 'Novo Registro Seguro' : 'Add Secret Card';
  String get unlockVault => isPortuguese ? 'Desbloquear Cofre' : 'Unlock Vault';
  String get cheatsheetTitle => isPortuguese ? 'Manual & Gostos do Meu Amor' : 'Partner Cheat Sheet';
  String get ringSize => isPortuguese ? 'Tamanho do Anel' : 'Ring Size';
  String get shoeSize => isPortuguese ? 'Tamanho do Calçado' : 'Shoe Size';
  String get clothingSize => isPortuguese ? 'Tamanho de Roupa' : 'Clothing Size';
  String get favoriteCoffee => isPortuguese ? 'Café Favorito' : 'Favorite Coffee';
  String get comfortFood => isPortuguese ? 'Comida Favorita' : 'Comfort Food';
  String get allergiesDislikes => isPortuguese ? 'Alergias / Não Gosta' : 'Allergies / Dislikes';
  String get favoriteFlowers => isPortuguese ? 'Flores Favoritas' : 'Favorite Flowers';
  String get giftNotes => isPortuguese ? 'Ideias de Presentes' : 'Gift Notes';
  String get notSetYet => isPortuguese ? 'Não informado' : 'Not set yet';
  String get cheatsheetVisibilityHint => isPortuguese ? 'Isso é o que seu parceiro(a) vê ao planejar surpresas e presentes para você 💕' : 'This is what your partner sees when planning surprises and gifts for you 💕';
  String get editMyCheatsheet => isPortuguese ? 'Editar Meu Guia 💕' : 'Edit My Cheatsheet 💕';
  String editPartnerCheatsheet(String name) => isPortuguese ? 'Editar Guia de $name 💕' : 'Edit $name\'s Cheatsheet 💕';
  String get saveCheatsheet => isPortuguese ? 'Salvar Guia' : 'Save Cheatsheet';
  String get cheatsheetSaved => isPortuguese ? 'Guia salvo com sucesso 💕' : 'Cheatsheet saved 💕';
  String get newSecret => isPortuguese ? 'Novo Registro' : 'New Secret';
  String get newEncryptedSecret => isPortuguese ? 'Novo Registro Seguro 🔐' : 'New Encrypted Secret 🔐';
  String get secretContentLabel => isPortuguese ? 'Conteúdo Secreto (Criptografado AES-256)' : 'Secret Content (Encrypted AES-256)';
  String get copySecret => isPortuguese ? 'Copiar Segredo' : 'Copy Secret';
  String get reveal => isPortuguese ? 'Revelar' : 'Reveal';
  String get hide => isPortuguese ? 'Ocultar' : 'Hide';
  String get deleteSecretTitle => isPortuguese ? 'Excluir Segredo?' : 'Delete Secret?';
  String deleteSecretConfirm(String title) => isPortuguese ? 'Tem certeza que deseja excluir "$title"? Esta ação não pode ser desfeita.' : 'Are you sure you want to delete "$title"? This cannot be undone.';
  String get copiedToClipboard => isPortuguese ? 'Copiado para a área de transferência 📋' : 'Copied to clipboard 📋';
  String get noEncryptedItemsYet => isPortuguese ? 'Nenhum item criptografado ainda' : 'No encrypted items yet';
  String get noEncryptedItemsDesc => isPortuguese ? 'Toque no botão abaixo para guardar senhas, bilhetes românticos, códigos ou segredos com criptografia AES-256.' : 'Tap the button below to store passwords, romantic notes, document codes, or personal secrets with AES-256 encryption.';
  String get encryptAndSaveBtn => isPortuguese ? 'Criptografar e Salvar' : 'Encrypt & Save Secret';
  String get secretSaved => isPortuguese ? 'Segredo criptografado e salvo com segurança 🔐' : 'Secret encrypted and saved securely 🔐';
  String get pinSetupTitle => isPortuguese ? 'Definir PIN do Cofre' : 'Set Up Vault PIN';
  String get pinConfirmTitle => isPortuguese ? 'Confirme o PIN de 6 dígitos' : 'Confirm Your 6-Digit PIN';
  String get vaultPrivateTitle => isPortuguese ? 'Cofre Privado Criptografado' : 'Private Encrypted Vault';
  String get pinSetupDesc => isPortuguese ? 'Escolha um PIN de 6 dígitos para proteger sua chave de criptografia AES-256.' : 'Choose a 6-digit PIN to securely derive your AES-256 encryption key.';
  String get pinConfirmDesc => isPortuguese ? 'Redigite o PIN de 6 dígitos para confirmar a configuração.' : 'Re-enter your 6-digit PIN to confirm encryption key setup.';
  String get pinUnlockDesc => isPortuguese ? 'Digite seu PIN de 6 dígitos ou biometria para abrir seus segredos criptografados.' : 'Enter your 6-digit PIN or use biometrics to unlock zero-knowledge secrets.';
  String get biometricScanReason => isPortuguese ? 'Toque no sensor biométrico para desbloquear o Cofre Privado' : 'Scan fingerprint to unlock your Private Vault';
  String get pinMismatch => isPortuguese ? 'Os PINs não coincidem. Tente novamente.' : 'PINs do not match. Please start over.';
  String get pinSetSuccess => isPortuguese ? 'PIN do Cofre definido com sucesso! 🔐' : 'Vault PIN set successfully! 🔐';
}
