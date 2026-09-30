# Patch local: N+1 na listagem de conversas (upstream)

## Onde

- `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` (usado por `index`, `filter` e `show` de `Api::V1::Accounts::ConversationsController` - **não** por `search`, que usa `api/v1/models/_conversation.json.jbuilder`, um arquivo separado, intocado)
- `app/services/conversation_preview_preloader.rb` (novo, não existe no upstream)

## Por que existe

Upstream, o partial busca a "última mensagem" e a "última mensagem não-atividade" de cada conversa com queries `.where(...).last` / `.first` separadas, sem reaproveitar o `includes` que `ConversationFinder#conversations_base_query` já carrega. Cada uma dessas mensagens, ao chamar `push_event_data` (`app/models/message.rb`), recarrega anexos, remetente e a própria conversa de novo (associação `sender`/`conversation` não preloadada), numa cascata recursiva.

Medido em produção em 2026-09-23, conta real "Move Tecnologia" (id 1, só 78 conversas): **6.893 queries, 9736ms totais, 6340ms em ActiveRecord, 3372ms de view**, por causa do polling normal do dashboard (`GET /conversations?...`) - não é tráfego sintético, é o comportamento upstream normal sob uma conta com histórico.

Confirmado via `git blame` que o trecho é 100% upstream (autores do core team Chatwoot, commits de 2020-2023), sem modificação nossa.

## O que o patch faz

1. `ConversationPreviewPreloader` busca, em lote (2 queries `DISTINCT ON` + 1 `Message.where(id: ...).includes(...)`), a última mensagem e a última mensagem não-atividade de **todas** as conversas da página de uma vez, com anexos e remetente pré-carregados.
2. Cada mensagem resolvida tem sua associação `conversation` apontada de volta pro objeto de conversa já carregado pelo finder (`message.association(:conversation).target = conversation`), evitando que `push_event_data` relance queries pra reler assignee/contact_inbox/etc.
3. O partial usa esse cache (memoizado por request, via `@conversation_preview_cache ||=`) em vez de `conversation.messages.where(...)`.

## O que o patch **não** faz (escopo deliberado)

- **Não** memoriza `Conversation#unread_incoming_messages`. Foi tentado e revertido: testes existentes (`spec/models/conversation_spec.rb`) provaram que `ActionCableListener#conversation_created` chama `conversation.push_event_data` (que usa `unread_incoming_messages`) **na criação da conversa, antes de qualquer mensagem existir** - memoizar no objeto travaria esse resultado vazio pro resto da vida do objeto, um bug real de contagem errada. Por isso essa chamada continua sem lote (até 3x por conversa: 1x direto no jbuilder, mais 1x dentro do `push_event_data` de cada uma das 2 mensagens resolvidas acima) - é o único ponto do N+1 original que sobra, deliberadamente, por segurança.
- **Não** toca `Message#push_event_data`/`#conversation_push_event_data` (upstream, usado em todo o app - broadcasts, webhooks, etc.) - risco de blast radius grande demais pra um patch local.
- **Não** muda a paginação (o parâmetro `updated_within` já bypassava `.page/.per` no upstream; isso é comportamento existente, fora do escopo daqui).
- **Não** altera o JSON retornado - mesmo shape, mesmos valores, só buscado em lote.

## Risco

Diverge do upstream em 2 arquivos (`_conversation.json.jbuilder` novo topo + 2 trechos trocados; nenhuma mudança em `conversation.rb`). Reconferir esses pontos a cada merge do upstream (`git log --oneline -- app/views/api/v1/conversations/partials/_conversation.json.jbuilder` pra ver se o upstream mexeu nas mesmas linhas).

## Testes

- `spec/services/conversation_preview_preloader_spec.rb` - equivalência (mensagem certa escolhida, não mistura conversas, anexo vem preloadado, aponta a conversa de volta).
- `spec/controllers/api/v1/accounts/conversations_controller_spec.rb` - equivalência do JSON completo (última mensagem = a mais recente de qualquer tipo, mesmo sendo atividade; `last_non_activity_message` pula a atividade; anexo presente) + teste de regressão de N+1 (conta queries via `ActiveSupport::Notifications`, 6 conversas com anexo cada, `< 60` queries totais).

## Benchmark

Ver `docs/patches/conversation_index_n_plus_one_benchmark.md` pro antes/depois medido.
