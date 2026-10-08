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
  CUSTOM_FIELDS_KEY = 'campos_adicionais'.freeze
  COMPANY_KEY = 'empresa'.freeze
  SUBJECT_KEY = 'assunto'.freeze
  PRODUCT_KEY = 'produto'.freeze
  EXTERNAL_TICKET_ID_KEY = 'ticket_id_externo'.freeze
  PARENT_TICKET_KEY = 'ticket_pai_id'.freeze
  CHILD_TICKETS_KEY = 'ticket_filhos_ids'.freeze

  # Caixa dos tickets internos, identificada pelo nome: não renomear pela tela.
  INTERNAL_TICKETS_INBOX_NAME = 'Tickets Internos'.freeze
end
