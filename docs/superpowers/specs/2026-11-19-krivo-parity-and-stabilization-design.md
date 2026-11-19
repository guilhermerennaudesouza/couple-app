# Documento de Design: Estabilização, Home Viva e Paridade Krivo

**Data:** 2026-11-19  
**Versão Base:** `v1.0.7+8`  
**Idioma Principal:** Português (Brasil) — `pt_BR` (com suporte secundário a `en_US`)  
**Status:** Pronto para aprovação do usuário (revisado via Builder Check)

---

## 1. Intenção e o Porquê

Transformar o Couple App (hoje em `v1.0.7+8`) em uma experiência verdadeiramente equivalente ao **Krivo Couple App** para o casal (Android, Samsung Galaxy S22 Ultra e S24 Plus), eliminando bugs críticos que quebram o uso real e criando **presença viva entre os dois** — motivos concretos para abrir o app todos os dias, responder juntos, receber avisos e ver atualizações direto na tela inicial do celular, mantendo **custo R$ 0 no Firebase Spark**.

---

## 2. Objetivos, Não-Objetivos e Anti-Objetivos

### Objetivos
1. **Confiabilidade total (Fase 1):** eliminar todos os bugs críticos levantados na auditoria QA (Pergunta do Dia, Decidir Juntos, Wishlist, Cofre/PIN, Tarefas, Calendário, Notas/Raspadinha, Ciclo, Jogos 18+, Cupons, Retrospectiva, Pareamento, Notificações Android e Widgets Glance).
2. **Integração viva e retenção diária (Fase 2):** substituir a tela inicial passiva por um painel **"Nosso Dia"** com ofensiva (streak), humor do dia, toque rápido *"Tô pensando em você"*, banners de ações ativas do par, badges na navegação, edição de perfil/avatares e sincronização em segundo plano no Android (`WorkManager`, ~15 min) para atualizar widgets e disparar notificações locais com o app fechado.
3. **Paridade de features assinatura do Krivo (Fase 3):** tela cheia colaborativa de **Desenhar Juntos** em tempo real (com envio para o Widget da tela inicial e opção de salvar imagem/wallpaper), **Swipe de Encontros** com detecção de *"Deu Match!"* e agendamento direto no Calendário, reações/comentários na Pergunta do Dia e fluxo de edição completo nos módulos restantes.
4. **Compatibilidade com dados já existentes:** nenhuma alteração de schema pode quebrar ou apagar dados já salvos no Firestore do casal atual.

### Não-Objetivos
- Suporte a iOS ou Web.
- Multi-casal / contas públicas / login social (mantém pareamento privado via Firebase Anonymous Auth + código de 6 dígitos).
- Chat completo estilo WhatsApp (o app é para micro-interações, rituais e organização do casal, não substituir mensageiros).

### Anti-Objetivos
- **Zero infraestrutura paga:** nada de Firebase Blaze, Cloud Functions, servidores externos ou contas em provedores pagos de push.
- **Zero "Big Bang" arriscado:** não reescrever tudo sem marcos intermediários testáveis.

---

## 3. Restrições Técnicas

- **Firebase Free Spark Tier (R$ 0):**
  - Cloud Firestore (persistência offline 100 MB, limite rígido de **1 MB por documento**).
  - Fotos e avatares armazenados como Base64 comprimido direto no Firestore (sem depender de Firebase Storage bucket).
  - Sem Cloud Functions; sincronização com app fechado feita no Android via `workmanager`.
- **Android 14/15 (Samsung One UI):**
  - `minSdk` / `targetSdk` atuais preservados, `release.keystore` fixa para OTA via GitHub Releases (`CoupleApp-Release.apk`).
  - Permissões de alarme exato e notificações (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`).
- **Idioma:** PT-BR como idioma padrão de primeira classe; toda nova string deve passar por `AppStrings` (e módulos v1.0.4 alinhados para PT-BR/EN sem quebrar usuários PT-BR).

---

## 4. Abordagens Consideradas e Escolha Aprovada

### Estratégia de Execução
- **Abordagem A — 3 Fases Incrementais *(Escolhida pelo usuário)*:**
  - Fase 1 (Estabilização & QA) → Fase 2 (Home Viva & Integração) → Fase 3 (Paridade Krivo).
  - Cada fase fecha com `flutter test` verde, `flutter analyze` limpo e pronta para release OTA.
  - *Trade-off:* tocamos em `main.dart` e nos widgets Kotlin em mais de uma fase, mas reduzimos drasticamente o risco de regressão e entregamos valor imediato ao casal desde a Fase 1.
- **Abordagem B — Pacote Único ("Big Bang") *(Descartada)*:**
  - Refatoração única de todas as telas, banco, notificações e widgets. Alto risco de regressões cruzadas e atraso até a primeira entrega usável.

### Notificações e Atualização de Widgets com App Fechado
- **Opção 1 — 100% Spark + Android `WorkManager` periódico (~15 min) *(Escolhida pelo usuário)*:**
  - Worker nativo/Flutter roda periodicamente em background (~15 min, respeitando Doze/restrições do Android), lê apenas os documentos leves de estado no Firestore (REST/SDK), atualiza os 4 Glance Widgets e dispara notificação local se houver novidade do parceiro desde o último timestamp visto.
  - *Trade-off:* latência de até ~15 min com o app fechado (instantâneo enquanto o app está aberto), em troca de R$ 0 e zero contas/serviços de terceiros.
- **Opção 2 — Serviço de Push Externo (OneSignal / ntfy.sh) *(Descartada)*:**
  - Entregaria push em ~1s, mas exige conta, chaves e manutenção fora do Firebase.

---

## 5. Design Detalhado por Fase

---

### FASE 1 — Estabilização & QA (Bugs Críticos)

#### 1.1. Pareamento, UID & Migração Segura (`lib/features/auth/`, `lib/main.dart`)
- **UID canônico garantido:** criar um provider central `currentUserUidProvider` (que aguarda `FirebaseAuth.instance.currentUser?.uid` após inicialização anônima) e eliminar todos os fallbacks divergentes (`'guest_uid'`, `'local_user'`, `'partner_uid'`, `'default_couple_id'`, `'user_<timestamp>'`).
- **Re-pareamento por nome com migração de histórico:** quando `joinCouple` (`pairing_repository.dart`) substitui `oldUid` por `newUid` em `couple.members` e `partnerProfiles`:
  - Executar dentro de uma **transação** para o documento `/couples/{coupleId}` e gravar um mapa `uidAliases: { oldUid: newUid }` no documento do casal.
  - Em seguida, rodar um utilitário idempotente `migratePartnerUid(coupleId, oldUid, newUid)` que atualiza em batches (`WriteBatch`) os documentos existentes referenciando `oldUid` em: `daily_questions` (chave em `answers`), `tasks` (`assignedTo`), `finance_entries` (`paidByUid`, `customShares`), `notes` (`authorUid`), `decide_sessions` (chave em `votes`), `wishlist` (`createdBy`, `purchasedBy`) e `partner_cheatsheet/{oldUid}` → `partner_cheatsheet/{newUid}`.
  - *Decisão de engenharia (nossa chamada):* manter `uidAliases` no `CoupleModel` como rede de segurança caso algum documento offline sincronize depois.
- **QR Code na tela de Pareamento:**
  - *Decisão de engenharia (nossa chamada):* substituir `_StylizedQrPainter` (falso) por geração real de QR Code contendo `coupleapp://join?code=<6digits>` (pacote `qr_flutter`) e adicionar botão de leitura de QR na aba "Entrar" (`mobile_scanner`), mantendo a digitação manual dos 6 dígitos como fluxo principal.
- **Desparear (`Unpair`):** limpar `coupleId` local, limpar dados em cache dos 4 widgets Glance, cancelar alarmes locais do casal e remover o próprio UID de `couple.members` (se falhar por offline, ainda completa o logout local com aviso).

#### 1.2. Notificações Locais & Fuso Horário (`lib/core/notifications/`, `AndroidManifest.xml`)
- **Manifest Android:** registrar `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` e `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver` (com `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` e `QUICKBOOT_POWERON`).
- **Timezone local real:** adicionar `flutter_timezone` e configurar `tz.setLocalLocation(tz.getLocation(deviceTz))` em `LocalNotificationService.initialize()`, com fallback seguro para `America/Sao_Paulo` em caso de falha — corrigindo o desvio de 3h (UTC vs BRT).
- **Agendamento automático:** chamar `LocalNotificationService.scheduleDailyPrompt(hour: 20, minute: 0)` automaticamente após o pareamento e no boot do `MainNavigationShell` (respeitando preferência salva caso o usuário altere horário ou desative).
- **Lembretes para ambos os parceiros:** criar um listener reativo em `MainNavigationShell` (junto com o sync) que sincroniza os alarmes locais de `calendar_events` futuros e `tasks` com `dueDate` no celular de **ambos** os parceiros (não só de quem criou).
- **Deep-link ao tocar na notificação:** guardar o payload (`daily_question`, `calendar_event:<id>`, `tasks`, `notes`, `cycle`, `adult_games`, `decide`) em um `StateProvider<String?>` (`pendingNotificationRouteProvider`) ouvido pelo `MainNavigationShell` para abrir diretamente a aba/tela correspondente (inclusive no cold start via `getNotificationAppLaunchDetails()`).

#### 1.3. Widgets Android Jetpack Glance (`android/.../couple_app/`, `widget_sync_service.dart`)
- **Todos os 4 widgets clicáveis com rota dedicada:** adicionar `.clickable(actionStartActivity<MainActivity>(actionParametersOf(routeKey to ...)))` nos 4 widgets (`couple` → Home, `daily_prompt` → Pergunta do Dia, `note` → Recados, `tasks` → Tarefas) e ler o `Intent` extra em `MainActivity.kt` + `MethodChannel` (ou URI do `home_widget`) para navegar direto à tela certa.
- **Remover `runBlocking` da main thread:** eliminar os overrides customizados com `kotlinx.coroutines.runBlocking` em `onUpdate` nos 4 `GlanceAppWidgetReceiver` (deixando o ciclo nativo assíncrono do `GlanceAppWidgetReceiver` gerenciar o update sem risco de ANR).
- **Corrigir bugs de conteúdo nos widgets:**
  - `NoteGlanceWidget`: se a nota fixada for raspadinha ainda não raspada (`isScratchCard && !isScratched`), enviar texto mascarado `"🎁 Recado surpresa! Toque para raspar ✨"` em vez do conteúdo secreto.
  - `DailyPromptGlanceWidget`: aplicar `DailyQuestionRepository.translatePrompt(...)` antes de salvar `prompt_text`.
  - `CoupleGlanceWidget`: calcular `daysTogether` dinamicamente em Kotlin a partir do `anniversary` ISO salvo (usando `java.time.LocalDate` / `ChronoUnit.DAYS`), garantindo que vire à meia-noite mesmo sem abrir o app.
  - `WidgetSyncService`: salvar `language`/`app_locale` **antes** de disparar os updates dos widgets e adicionar debounce (~400 ms) para evitar rajadas duplicadas de broadcasts.

#### 1.4. Pergunta do Dia (`lib/features/daily_question/`)
- **Hash determinístico sem repetição mensal:** substituir a soma ASCII em `getPromptForDate` por índice baseado em dias corridos desde uma época fixa (`DateTime.utc(2025, 1, 1)` → `daysSinceEpoch % bank.length` com permutação determinística fixa de 50+ perguntas), garantindo que **todas** as perguntas apareçam antes de qualquer repetição.
- **Virada de meia-noite automática:** criar um `currentDateKeyProvider` (`YYYY-MM-DD`) que se atualiza via `WidgetsBindingObserver` (`AppLifecycleState.resumed`) + timer para a próxima meia-noite, e passar `dateKey` como parte do parâmetro de `todayDailyQuestionProvider`.
- **Fallback offline & Reveal seguro:** além de atualizar `isRevealed` na transação, fazer o getter `DailyQuestionModel.isRevealed` considerar `isRevealed || answers.length >= 2` e sempre preservar o prompt em PT-BR no fallback offline.
- **Responder perguntas passadas não reveladas:** na aba "Memórias Passadas", quando uma pergunta antiga ainda não estiver revelada e o usuário atual não respondeu, exibir o campo de resposta inline para desbloquear o histórico.

#### 1.5. Decidir Juntos, Memórias/Wishlist, Cofre, Tarefas, Calendário, Notas e Módulos v1.0.4
- **Decidir Juntos (`decide_repository.dart`):**
  - Corrigir `resetSessionForRevote` usando `docRef.update({'votes': <String, String>{}, 'status': statusOpen, 'resolvedAt': null, 'winningOption': null})` (sem `merge: true` sobre o mapa vazio) para realmente apagar os votos antigos.
  - Converter `castVote` para `runTransaction` (evitando race condition em votos simultâneos).
- **Wishlist (`memories_screen.dart` & `wish_model.dart`):**
  - Criar parser brasileiro `parseBrlCurrency(String input)` que trata `"150,50"`, `"1.250,90"` e `"150.50"` corretamente.
  - Corrigir `WishModel.==` / `hashCode` incluindo `isSecretRadar` e `occasion`.
- **Memórias & Cápsulas — Limite de 1 MB do Firestore (`memories_screen.dart`, `memories_repository.dart`):**
  - Remover a tentativa lenta de `FirebaseStorage.putData()` quando rodando no modo Spark Base64 (ir direto para compressão + Base64).
  - Validar tamanho acumulado do documento antes de salvar (limite seguro de **850 KB** por documento, máximo de 4 fotos comprimidas a ~150 KB cada com feedback claro ao usuário se exceder) e cachear `Uint8List` decodificados em memória (LRU simples) para evitar engasgo no scroll.
- **Cofre Privado (`vault_screen.dart`, `vault_crypto_service.dart`):**
  - **Sentinela compartilhada do PIN no Firestore:** ao criar o PIN no primeiro celular, gravar em `/couples/{coupleId}/vault_meta/config` um payload criptografado com a chave derivada (`sentinel = encrypt("KRIVO_VAULT_OK_V1", key)`).
  - **Upgrade seguro para casais que já têm itens no Cofre *(chamada de engenharia)*:** se `vault_meta/config` ainda não existir, mas já houver documentos em `vault_items`, o app **bloqueia "Criar novo PIN"** e pede o **PIN atual**, validando-o tentando descriptografar um item existente para só então gravar `vault_meta/config` — evitando que o segundo celular crie um sentinela incompatível.
  - Quando `vault_meta/config` já existir, o segundo celular exibe **"Digite o PIN do Casal"** e valida contra o sentinela antes de liberar o acesso.
  - Adicionar opção **"Alterar PIN"** (exige PIN atual, re-criptografa todos os `vault_items` e o sentinela atomicamente em batch) e uma saída explícita com dupla confirmação **"Resetar Cofre (apagar tudo)"** na tela de bloqueio para recuperação caso ambos esqueçam o PIN ou tenham ficado com PINs divergentes antes desta versão *(chamada de engenharia)*.
  - Mover PBKDF2 (`deriveKey`) para `Isolate.run()` para não travar a animação da tela.
- **Tarefas & Checklists (`tasks_screen.dart`, `task_repository.dart`):**
  - Corrigir lógica de "Atrasada": comparar apenas data calendário (`DateTime(y, m, d)`), marcando como atrasada somente se `dueDate < hoje (00:00)`; tarefas de hoje exibem badge **"Hoje"**.
  - Converter `addChecklistItem` e `removeChecklistItem` para `runTransaction`.
  - Adicionar confirmação antes de excluir tarefa/checklist e limpar `TextEditingController` vazados ao remover listas.
- **Calendário (`calendar_screen.dart`):**
  - Aplicar `_selectedCategoryFilter` também na grade mensal (`_buildMonthGridSliver`), diferenciar rótulos PT (`Aniversário de Namoro` vs `Aniversário`), corrigir vazamento de controllers e remover fallback `'default_couple_id'`.
- **Notas & Raspadinha (`notes_screen.dart`, `note_model.dart`):**
  - Impedir que o autor raspe a própria raspadinha (`isConcealedForMe = note.isScratchCard && !note.isScratched && note.authorUid != effectiveUid`); para o autor, mostrar selo *"Aguardando seu amor raspar 🎁"* com opção de editar sem revelar.
  - Preservar `isScratched` ao editar uma nota já raspada e incluir `isScratchCard`, `isScratched`, `drawingDataJson` no `NoteModel.==`/`hashCode`.
- **Módulos v1.0.4 (`loyalty`, `adult_games`, `cycle`, `stats`):**
  - **Cupons:** adicionar seletor de categoria no modal de criação e diálogo de confirmação ao excluir.
  - **Jogos 18+:** sincronizar `_selectedLevel` com `session.selectedLevel` do Firestore e adicionar botão "Dispensar / Topar 🔥" no banner de Convite Picante (`clearNudge()`).
  - **Ciclo Menstrual:** adicionar `isConfigured: bool` (evitando data falsa `hoje - 10 dias` antes do cadastro inicial), guardar `symptomsDate: YYYY-MM-DD` para resetar sintomas automaticamente no dia seguinte e diferenciar o papel de quem acompanha (`trackerUid`) para adaptar o texto (1ª pessoa para quem registra vs modo *"Cuidando de <Nome>"* para o parceiro).
  - **Retrospectiva & XP:** incluir a pergunta revelada de hoje na contagem e unificar o cálculo de `daysTogether` num helper único `CoupleDateUtils.daysTogether(anniversaryDate)`.
- **Limpeza de vazamentos:** descartar `TextEditingController` em todos os modais (Calendário, Cofre, Cupons, Jogos 18+) e cancelar `otaSub` ao fechar diálogo de atualização.

---

### FASE 2 — Home Viva ("Nosso Dia"), Presença & Integração em Background

#### 2.1. Nova Aba 0: Painel "Nosso Dia" (`lib/features/home/`)
- Substituir a Aba 0 atual (`DailyQuestionScreen` isolada) por `CoupleHomeScreen` (**"Nosso Dia"**), mantendo a navegação em 5 abas limpas:
  1. **Hoje (`CoupleHomeScreen`)** — painel central vivo
  2. **Tarefas (`TasksScreen`)** — com badge de tarefas pendentes/atrasadas
  3. **Calendário (`CalendarScreen`)**
  4. **Decidir (`DecideScreen`)** — com badge de votações abertas aguardando seu voto
  5. **Hub (`CoupleHubScreen`)** — atalhos organizados em grade visual + badges + configurações
- **Composição da tela "Nosso Dia" (de cima para baixo):**
  1. **Cabeçalho do Casal:** avatares dos dois lado a lado, nomes, contador de dias juntos, **badge de Ofensiva (🔥 X dias seguidos)** e atalho para editar perfil do casal.
  2. **Banners de Atenção Ativa (aparecem só quando há algo pendente do par):**
     - Banner **SOS Carinho** (do Ciclo) com botão de 1 toque *"Estou indo cuidar 💕"* (limpa o pedido).
     - Banner **Convite Picante** (dos Jogos 18+) com botão *"Abrir jogo 🔥"* ou dispensar.
     - Banner **Votação Aberta** no Decidir Juntos aguardando seu voto.
     - Banner **Cupom Resgatado** recentemente pelo parceiro.
  3. **Cartão "Como estamos hoje" (Presença & Micro-interação):**
     - Humor atual de cada parceiro (ex.: 💕 Apaixonado, 😴 Cansado, 🤗 Carente, ⚡ Animado, 🍫 Com fome, 🧘 Em paz) + nota curta opcional (até 40 chars), resetado visualmente quando de dias anteriores.
     - Botão **"Enviar Carinho / Tô com Saudade 💓"**: grava um pulso com lista rolante dos últimos 10 carinhos + contador vitalício `totalPulsesCount` dentro do próprio `activity_state/latest` *(chamada de engenharia — zero leitura extra e alimenta tanto a Home quanto a Retrospectiva/XP)*, dispara vibração háptica + animação de corações na tela do parceiro quando aberto e gera notificação local.
  4. **Card Destaque da Pergunta do Dia:**
     - Mostra o status em tempo real (*"Responda hoje"*, *"Aguardando <Parceiro> 🔒"* com botão **"Cutucar"**, ou *"Revelado! Toque para ver 💕"*), abrindo a `DailyQuestionScreen` completa ao tocar.
  5. **Resumo Vivo em Cartões Compactos:**
     - Recado/Desenho fixado (toque abre Notas ou Desenhar Juntos).
     - Próximas 2 tarefas urgentes + próximo evento do calendário (contagem regressiva).

#### 2.2. Ofensiva / Streak Diário (`lib/features/stats/` & `daily_question`)
- Calcular o streak real a partir dos documentos `daily_questions` onde `isRevealed == true` (dias consecutivos terminando em hoje ou ontem, para não zerar antes da meia-noite de hoje).
- Exibir na Home, na tela da Pergunta do Dia, na Retrospectiva/XP e no `CoupleGlanceWidget`.

#### 2.3. Edição de Perfil do Casal & Avatares (`lib/features/auth/`)
- Nova tela/sheet **Editar Perfil do Casal** acessível pela Home e pelo Hub:
  - Editar meu nome/apelido, escolher foto da galeria (comprimida para `256x256`, JPEG 70%, ~15–25 KB em Base64 Data URI em `partnerProfiles[uid].avatarUrl`), e editar `anniversaryDate` (atualizando automaticamente o evento de aniversário no calendário).
  - Atualizar todos os componentes de avatar (`DailyQuestionScreen`, `CoupleHomeScreen`, `CoupleHubScreen`) para suportar tanto `data:image/...;base64,` quanto URL HTTP ou iniciais estilizadas.

#### 2.4. Alertas em Tempo Real (App Aberto) + Sync em Segundo Plano (`WorkManager`, App Fechado)
- **Schema leve de atividade (`/couples/{coupleId}/activity_state/latest`):**
  - Documento único (< 2 KB) atualizado por qualquer ação relevante do parceiro (novo recado/desenho, resposta na pergunta diária, SOS Carinho, Convite Picante, carinho/"Saudade", nova votação, cupom resgatado, tarefa atribuída).
  - Campos: `lastEventId`, `lastEventType`, `lastActorUid`, `lastActorName`, `title`, `body`, `route`, `updatedAt`, além de um snapshot resumido (`moods`, `activeSos`, `activeNudge`, `pendingBallotCount`, `pinnedNotePreview`, `todayPromptStatus`, `topTasks`).
  - *Por que um documento único?* Em background (`WorkManager`), ler **1 único documento** no Firestore consome quase zero bateria, quase zero cota do plano Spark e traz tudo que precisa para atualizar os widgets e decidir se dispara notificação local.
- **Com o app aberto (tempo real):** listener em `activity_state/latest` exibe um banner/toast animado no topo se `lastActorUid != myUid` e `lastEventId != lastSeenEventId`, além de atualizar badges na `NavigationBar`.
- **Com o app fechado (`workmanager` no Android):**
  - Registrar tarefa periódica (`15 minutos`, com restrição `NetworkType.connected`) que inicializa Firebase no isolate de background, lê `activity_state/latest` (1 leitura), compara `lastEventId` com `SharedPreferences('last_notified_event_id')`, dispara `LocalNotificationService.showPartnerAlert(...)` se houver novidade do parceiro e atualiza os 4 widgets Android Glance via `HomeWidget`.
  - **Confiabilidade no Samsung One UI & Canais de Notificação *(chamada de engenharia)*:**
    - Como a distribuição é via APK OTA (fora da Play Store), declarar `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` no `AndroidManifest.xml` e incluir um card simples em **Hub → Preferências** (*"Garantir alertas no Samsung"*) guiando a isenção de otimização de bateria e permissão de alarmes exatos (`SCHEDULE_EXACT_ALARM`).
    - Separar as notificações Android em **2 canais** configuráveis pelo usuário: **Urgentes do Par** (SOS Carinho, Saudade/Beijo, Convite Picante — som + vibração altos) e **Rotina do Casal** (Pergunta do Dia, Tarefas, Calendário, Recados/Desenhos — configurável/silenciável).

---

### FASE 3 — Paridade de Features Assinatura do Krivo

#### 3.1. Desenhar Juntos em Tempo Real + Widget de Desenho (`lib/features/drawing/`)
- **Nova tela dedicada "Desenhar Juntos" (`DrawingTogetherScreen`)** acessível pela Home e pelo Hub:
  - Canvas em tela cheia com proporção amigável para widget/tela de bloqueio.
  - **Sincronização ao vivo:** documento `/couples/{coupleId}/shared_canvas/current` guarda lista de traços (`strokes`, com limite de pontos simplificados por distância mínima + teto de segurança de ~200 KB para nunca chegar perto de 1 MB) e `backgroundColorHex`. Quando um parceiro termina um traço (`onPanEnd`), grava via transação/merge e aparece imediatamente na tela do outro.
  - **Ferramentas:** paleta de 10 cores, 3 espessuras de pincel, borracha (apagar último traço ou modo borracha), Desfazer (`Undo`), Limpar tela (com confirmação), cor de fundo.
  - **Enviar para o Widget da Tela Inicial nos dois celulares *(chamada de engenharia)*:** gera um PNG comprimido (~60 KB via `ui.PictureRecorder`), grava em `/couples/{coupleId}/shared_canvas/widget_snapshot` (Base64 ~80 KB) e incrementa `drawingWidgetRevision` dentro de `activity_state/latest` (com modo ativo sincronizado para o casal: o último item fixado — recado ou desenho — define o modo do `NoteGlanceWidget` nos dois celulares). Quando o outro celular recebe o `drawingWidgetRevision` novo (em tempo real ou numa **2ª leitura condicional** do `WorkManager` só quando o desenho muda), salva o PNG em arquivo interno do app e atualiza o `NoteGlanceWidget`, que renderiza o **Bitmap do desenho** nativamente sem precisar de `dart:ui` em background.
  - **Salvar como Imagem / Papel de Parede:** salva o PNG na galeria do celular (via `gal` ou `MediaStore` nativo) com feedback imediato.

#### 3.2. Swipe de Ideias de Encontros ("Tinder de Encontros") (`lib/features/decide/`, `date_ideas/`)
- Adicionar modo **"Descobrir (Swipe)"** na aba de Ideias de Encontros em `DecideScreen` (alternável entre *Swipe* e *Lista*):
  - **Catálogo curado PT-BR separado da lista pessoal *(chamada de engenharia)*:** embutir um catálogo curado de **~40 ideias em PT-BR** direto no app para o baralho de Swipe (sem poluir a coleção `date_ideas` já existente do casal). Uma carta do catálogo só é gravada em `date_ideas` quando um dos dois interage (curtir/passar/match), mesclando naturalmente com as ideias personalizadas do casal.
  - Cada `DateIdeaModel` ganha mapa `votes: Map<String, String>` (`'like'` | `'pass'`), compatível com documentos antigos (default `{}`).
  - Os dois deslizam cartas em segredo (direita = *"Quero!"*, esquerda = *"Agora não"*), com botão **"Rever ideias puladas"** para resetar os `'pass'` quando quiserem.
  - Quando ambos marcam `'like'` na mesma ideia, grava `matchedAt` e exibe modal comemorativo **"Deu Match! 💕"** com botão de 1 toque **"Agendar no Calendário"** (abre o editor de evento já preenchido com título e descrição da ideia).
  - Incluir opção **"Sortear Encontro 🎲"** entre as ideias com match ou não concluídas.

#### 3.3. Pergunta do Dia Interativa (`lib/features/daily_question/`)
- **Reações e Comentários nas respostas reveladas:** adicionar `reactions: Map<String, String>` (emoji rápido: ❤️ 😂 🥺 🔥 😍) e `comments: List<QuestionComment>` ao `DailyQuestionModel` (compatível com documentos antigos).
- **Perguntas Personalizadas do Casal *(chamada de engenharia)*:** qualquer um dos dois pode propor uma pergunta própria; ao salvar, ela já é **vinculada à próxima data futura livre (`YYYY-MM-DD`)** (criando o doc em `daily_questions/{YYYY-MM-DD}` com `isCustom: true`, `proposedByUid`), evitando qualquer conflito offline à meia-noite. A pergunta fica **oculta como surpresa** até o dia chegar, e na data dela **ambos respondem às cegas** com o mesmo ritual de revelação dupla.
- **Botão "Cutucar parceiro"** no Estado 2 (aguardando resposta), registrando evento em `activity_state/latest` (com cooldown de 1h para não virar spam).
- **Busca nas Memórias Passadas** e **contador regressivo até a próxima pergunta** (usando as strings que já existem em `app_strings.dart`).

#### 3.4. Fluxos de Edição Completos & Padronização Final
- Adicionar edição (não apenas exclusão) em: **Tarefas**, **Checklists**, **Despesas**, **Metas do Cofrinho**, **Memórias**, **Desejos**, **Itens do Cofre** e **Cupons de Amor**.
- Finalizar localização PT-BR/EN nos 4 módulos da v1.0.4 (`Loyalty`, `AdultGames`, `Cycle`, `Stats`) e extrair os modais gigantes de `memories_screen.dart`, `finance_screen.dart` e `decide_screen.dart` em widgets/arquivos menores conforme tocarmos neles.

---

## 6. Decisões do Usuário vs. Chamadas de Engenharia vs. O que Fica a Cargo do Implementador

### Decidido pelo Usuário
- Executar todas as 3 frentes (Bugs/QA, Home Viva/Integração, Paridade Krivo).
- Abordagem **A** (3 fases incrementais, testadas separadamente).
- Opção **1** para background (100% Firebase Spark R$ 0 + Android `WorkManager` ~15 min).
- Aplicativo focado em Português (Brasil).

### Chamadas de Engenharia Feitas Neste Design (corrija se discordar)
- **QR Code real:** usar `qr_flutter` + `mobile_scanner` na tela de pareamento (substituindo o desenho falso atual).
- **Documento único `activity_state/latest`:** centralizar o resumo do casal (incluindo últimos 10 carinhos + `totalPulsesCount`) num único doc `< 2 KB` para o `WorkManager` gastar 1 leitura por ciclo em background e alimentar banners + badges + widgets.
- **Desenho no Widget nos dois celulares:** salvar snapshot PNG comprimido (~60 KB) em `shared_canvas/widget_snapshot` com leitura condicional no `WorkManager` só quando `drawingWidgetRevision` mudar; o último item fixado (recado ou desenho) define o modo do `NoteGlanceWidget` nos dois aparelhos.
- **Sentinela do PIN do Cofre (`vault_meta/config`) com upgrade seguro:** validar contra um item existente antes de criar o sentinela em casais que já usam o Cofre + botão "Resetar Cofre (apagar tudo)" com dupla confirmação caso o PIN seja esquecido.
- **Confiabilidade Samsung One UI:** `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` + card guia em Preferências + 2 canais de notificação Android (*Urgentes do Par* vs *Rotina do Casal*).
- **Catálogo de Swipe separado da lista pessoal:** ~40 ideias curadas em PT-BR no app (só gravam em `date_ideas` ao curtir/dar match), sem bagunçar a lista que vocês já têm, com botão "Rever ideias puladas".
- **Perguntas personalizadas vinculadas à próxima data futura:** ficam ocultas como surpresa até o dia chegar e seguem o mesmo ritual de resposta às cegas dos dois.

### Deixado ao Implementador (Planos por Fase)
- Quebra exata de arquivos/widgets internos ao refatorar telas grandes.
- Detalhes finos de micro-animações (`flutter_animate`), paleta exata de cada emoji de humor e duração dos haptics.
- Estrutura exata dos testes unitários e de widget adicionados em cada fase (garantindo cobertura de todos os bugs corrigidos e novos modelos).
