# PATCH LOCAL (fork) - contrato do ticket gravado na conversa, lido também pelo
# Portal do Cliente: chaves de custom_attributes e a caixa dos tickets internos.
# São valores persistidos (inclusive a grafia tipo_de_solicitao): mudar exige
# migrar os dados e o Portal. No front, os mesmos valores ficam em
# constants/ticketDetailAttributes.js e composables/useTicketCatalog.js.
module TicketContract
  SERVICE_KEY = 'servico'.freeze
  CATEGORY_KEY = 'tipo_de_solicitao'.freeze
  STATUS_KEY = 'status_atendimento'.freeze
  JUSTIFICATION_KEY = 'justificativa'.freeze
  CLOSE_REASON_KEY = 'motivo_encerramento'.freeze
  # Código de negócio do item do cadastro escolhido (o Portal é o dono). Chaves
  # ocultas, sem definição de atributo: a conversa guarda nome E código, e o
  # código sobrevive a renomear o item (ver TicketCatalogCodes).
  SERVICE_CODE_KEY = 'servico_codigo'.freeze
  CATEGORY_CODE_KEY = 'tipo_de_solicitao_codigo'.freeze
  STATUS_CODE_KEY = 'status_atendimento_codigo'.freeze
  JUSTIFICATION_CODE_KEY = 'justificativa_codigo'.freeze
  CLOSE_REASON_CODE_KEY = 'motivo_encerramento_codigo'.freeze
  CUSTOM_FIELDS_KEY = 'campos_adicionais'.freeze
  COMPANY_KEY = 'empresa'.freeze
  SUBJECT_KEY = 'assunto'.freeze
  PRODUCT_KEY = 'produto'.freeze
  EXTERNAL_TICKET_ID_KEY = 'ticket_id_externo'.freeze
  PARENT_TICKET_KEY = 'ticket_pai_id'.freeze
  CHILD_TICKETS_KEY = 'ticket_filhos_ids'.freeze
  # Gravada pelo Portal (= !is_internal): false marca ticket interno, "agente" na origem.
  PARTNER_VISIBLE_KEY = 'visivel_parceiro'.freeze

  # Chave do nome -> chave do código, na ordem dos cadastros.
  CODE_KEYS = {
    SERVICE_KEY => SERVICE_CODE_KEY,
    CATEGORY_KEY => CATEGORY_CODE_KEY,
    STATUS_KEY => STATUS_CODE_KEY,
    JUSTIFICATION_KEY => JUSTIFICATION_CODE_KEY,
    CLOSE_REASON_KEY => CLOSE_REASON_CODE_KEY
  }.freeze

  # Caixa dos tickets internos, identificada pelo nome: não renomear pela tela.
  INTERNAL_TICKETS_INBOX_NAME = 'Tickets Internos'.freeze
end
