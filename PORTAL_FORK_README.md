# Fork do Chatwoot para o Portal do Cliente

Este diretório é um fork de verdade do [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot),
não uma cópia solta. Existe pra rodar as customizações da Move Tecnologia sem perder a
capacidade de atualizar de versão via `git merge` em vez de reaplicar patch por patch à mão.

## Estrutura

- Remote `upstream` → aponta pro repositório oficial do Chatwoot (sem remote `origin` configurado,
  não há push para lugar nenhum — isso é só local).
- Branch `portal-custom` → nossas customizações, commitadas em cima da tag `v4.16.2` do upstream.
- Base atual: tag `v4.16.2`.

## Como atualizar para uma nova versão do Chatwoot

```bash
cd /home/move/chatwoot-portal/chatwoot-fork

# 1. Buscar as novidades do Chatwoot oficial
git fetch upstream

# 2. Ver quais tags novas existem
git tag -l 'v4.*' --sort=-v:refname | head -5

# 3. Mesclar a nova versão na nossa branch (troque v4.17.0 pela versão desejada)
git merge v4.17.0

# 4. Resolver conflitos, se houver (provavelmente nos mesmos arquivos listados abaixo)
#    Depois de resolver: git add <arquivos> && git commit

# 5. Rebuildar a imagem Docker
docker build -f docker/Dockerfile -t chatwoot-custom:v4.17.0-ticketdetails .

# 6. Trocar o container (ver docs/chatwoot_integration.md no chatwoot-portal pra o passo a passo
#    completo de deploy — env vars, volume de storage, rename do container antigo como backup)
```

Se o merge vier limpo (sem conflito), é só rebuildar e trocar o container. Se der conflito,
os arquivos abaixo são os mais prováveis de precisar de resolução manual, já que são os que
modificamos:

- `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue`
- `app/javascript/dashboard/routes/dashboard/conversation/ConversationAction.vue`
- `app/javascript/dashboard/routes/dashboard/conversation/ConversationInfo.vue`
- `app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue`
- `app/javascript/dashboard/routes/dashboard/conversation/customAttributes/CustomAttributes.vue`
- `app/javascript/dashboard/components/widgets/conversation/MoreActions.vue`
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `app/javascript/dashboard/composables/useUISettings.js`
- `app/javascript/dashboard/store/modules/contactConversations.js`
- `app/views/api/v1/models/_agent.json.jbuilder`
- `app/javascript/dashboard/i18n/locale/{en,pt_BR}/conversation.json`

Os arquivos novos (não deveriam conflitar, mas confirme que ainda existem/fazem sentido após
o merge):

- `app/javascript/dashboard/constants/ticketDetailAttributes.js`
- `app/javascript/dashboard/routes/dashboard/conversation/TicketLinkDialog.vue`
- `app/javascript/dashboard/components-next/NewConversation/NewInternalTicket.vue`

## O que cada customização faz

Ver a mensagem do commit `9b57a46` (`git show 9b57a46`) pra descrição completa. Resumo:

1. Seções novas na barra lateral da conversa ("Detalhes do Atendimento", "Informações do
   Portal do Cliente") agrupando os atributos customizados que vêm do Portal, separados da
   seção genérica nativa do Chatwoot.
2. Campo "Serviço" dentro de "Ações da conversa".
3. Botão "Novo ticket interno" (tela cheia) pra criar uma conversa interna do zero.
4. Vínculo de ticket pai/filho — menu "Opções" no cabeçalho da conversa (perto do "Resolver").
5. Tag colorida de "Classificação do Cliente" (A/B/C) no card do contato.
6. Correção de um bug latente no `contactConversations.js` (source_id/assignee_id virando a
   string `"undefined"` quando ausentes).

## Dados do Chatwoot que dependem do Portal

Vários desses recursos dependem de `CustomAttributeDefinition`s que **não fazem parte do
código-fonte** — foram criadas diretamente no banco via Rails console (servico, liberacoes,
issue_jira, decisao_po, status_cobranca, data_entrega, data_atualizacao_sistema, categoria,
ticket_pai_id, ticket_filhos_ids, classificacao_cliente, produto, sla_horas, prazo_resolucao,
ticket_id_externo, tipo_de_solicitao, visivel_parceiro, motivo_encerramento). Uma atualização
de versão do Chatwoot **não afeta esses dados** (ficam no Postgres, não no código), só o
código-fonte deste fork é que precisa do merge acima.
