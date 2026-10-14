# PATCH LOCAL (fork) - cadastro de atendimento ligado por código.
namespace :ticket_catalog do
  desc 'Grava o código dos itens do cadastro nas conversas existentes de uma conta (dry run; APPLY=1 grava)'
  task :backfill_conversation_codes, [:account_id] => :environment do |_task, args|
    abort 'uso: rake ticket_catalog:backfill_conversation_codes[account_id] [APPLY=1]' if args[:account_id].blank?

    TicketCatalog::BackfillConversationCodes.new(args[:account_id], apply: ENV['APPLY'] == '1').call
  end
end
