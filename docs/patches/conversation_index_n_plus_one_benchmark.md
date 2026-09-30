# Benchmark: patch N+1 da listagem de conversas

## Real (produção, antes do patch)

Capturado direto do log do container `chatwoot-rails-1` em 2026-09-23, `GET /api/v1/accounts/1/conversations?inbox_id=1&status=open&assignee_type=unassigned&sort_by=created_at_desc&updated_within=18`, conta "Move Tecnologia" (id 1, 78 conversas reais, histórico de anos de uso):

| Métrica | Valor |
|---|---|
| Total de queries | 6.893 |
| Tempo total | 9736ms |
| ActiveRecord | 6340,8ms |
| Renderização (Views) | 3372,4ms |

Não foi medido "depois" nesse mesmo ambiente ainda porque isso exigiria reconstruir a imagem `chatwoot-custom` e reiniciar o container que serve as contas reais (Plus Consultoria, Exact, Move Tecnologia) - pendente de aprovação explícita antes de fazer isso.

## Controlado (dataset sintético, mesma escala: 78 conversas)

Rodado localmente contra `chatwoot_fork_test`, mesma conta/dados em ambas as medições (`git stash`/`pop` pra alternar entre código original e com patch, sem recriar dado nenhum entre as duas rodadas). Dataset mais leve que a conta real (3-5 mensagens por conversa, anexo em metade delas, sem meses de histórico acumulado) - por isso a redução relativa aqui é menor do que a projetada pra conta real, onde o custo por mensagem/anexo pesa mais.

| Métrica | Antes | Depois | Redução |
|---|---|---|---|
| Queries | 190 | 66 | 65% |
| Tempo total (wall clock) | 950,0ms | 540,8ms | 43% |

Script usado: consultar sessão (não commitado - script de bench ad hoc, não faz parte do patch).

## Leitura

O ganho relativo em produção real deve ser maior que o medido no dataset sintético, porque o N+1 original cresce com a profundidade de cada conversa (mensagens, anexos, remetentes distintos) além da contagem de conversas - a conta real tem muito mais histórico por conversa do que o dataset de teste. A validação final com número real só acontece depois do deploy no container de produção (ver docs/patches/conversation_index_n_plus_one.md).
