# Tarefas específicas do Portal do Cliente (Move) - não fazem parte do
# Chatwoot upstream. Mantidas em arquivo próprio pra não colidir com merges
# futuros do fork.
namespace :move do
  desc "Replica times, labels e atributos personalizados da conta de referência (Move Tecnologia) pras demais contas, sem sobrescrever o que já existir"
  task sync_account_config: :environment do
    source = Account.find_by(name: "Move Tecnologia")
    unless source
      puts "[move:sync_account_config] conta de referência 'Move Tecnologia' não encontrada"
      next
    end

    targets = Account.where.not(id: source.id)
    if targets.empty?
      puts "[move:sync_account_config] nenhuma conta de destino (só existe a conta de referência)"
      next
    end

    targets.find_each do |target|
      puts "== #{target.name} (##{target.id}) =="

      created_teams = 0
      source.teams.find_each do |team|
        next if target.teams.exists?(name: team.name)

        target.teams.create!(team.attributes.slice("name", "description", "icon", "icon_color", "allow_auto_assign"))
        created_teams += 1
      end
      puts "  times criados: #{created_teams}"

      created_labels = 0
      source.labels.find_each do |label|
        next if target.labels.exists?(title: label.title)

        target.labels.create!(label.attributes.slice("title", "description", "color", "show_on_sidebar"))
        created_labels += 1
      end
      puts "  labels criadas: #{created_labels}"

      created_cads = 0
      source.custom_attribute_definitions.find_each do |cad|
        next if target.custom_attribute_definitions.exists?(attribute_key: cad.attribute_key, attribute_model: cad.attribute_model)

        target.custom_attribute_definitions.create!(
          cad.attributes.slice("attribute_display_name", "attribute_description", "attribute_key",
                                "attribute_display_type", "attribute_model", "attribute_values",
                                "default_value", "regex_pattern", "regex_cue")
        )
        created_cads += 1
      end
      puts "  atributos personalizados criados: #{created_cads}"
    end
  end

  desc "Cria a regra de roteamento automático (equipe padrão de 1ª linha) e as macros operacionais em todas as contas, sem duplicar"
  task seed_automation: :environment do
    Account.find_each do |acc|
      dev_team = acc.teams.find_by(name: "desenvolvimento")
      suporte_team = acc.teams.find_by(name: "suporte técnico")

      # Roteamento: todo ticket vindo do Portal (tem o atributo "produto"
      # preenchido) cai por padrão na equipe de suporte de 1ª linha - quem
      # confirma que é bug de fato manda pro desenvolvimento via macro.
      if suporte_team && !acc.automation_rules.exists?(name: "Roteamento - 1ª linha (Portal)")
        acc.automation_rules.create!(
          name: "Roteamento - 1ª linha (Portal)",
          description: "Ticket criado a partir do Portal do Cliente cai automaticamente na equipe de suporte técnico",
          event_name: "conversation_created",
          conditions: [
            { attribute_key: "produto", filter_operator: "is_present", values: [], query_operator: "and", custom_attribute_type: "conversation_attribute" },
          ],
          actions: [{ action_name: "assign_team", action_params: [suporte_team.id] }],
          active: true,
        )
        puts "#{acc.name}: automation rule de roteamento criada"
      end

      macros = [
        {
          name: "Enviar para Desenvolvimento",
          actions: [
            { action_name: "assign_team", action_params: [dev_team&.id].compact },
            { action_name: "add_label", action_params: ["aguardando_dev"] },
            { action_name: "send_message", action_params: ["Identificamos que esse atendimento precisa de uma análise mais aprofundada da nossa equipe técnica. Vamos te atualizar assim que tivermos novidades."] },
          ],
        },
        {
          name: "Aguardando Cliente",
          actions: [
            { action_name: "add_label", action_params: ["aguardando_cliente"] },
            { action_name: "change_status", action_params: ["pending"] },
            { action_name: "send_message", action_params: ["Precisamos de algumas informações para continuar seu atendimento. Fico no aguardo do seu retorno."] },
          ],
        },
        {
          name: "Solução Enviada",
          actions: [
            { action_name: "remove_label", action_params: ["aguardando_dev"] },
            { action_name: "add_label", action_params: ["aguardando_validacao"] },
            { action_name: "send_message", action_params: ["Realizamos o ajuste referente ao seu atendimento. Poderia validar se ficou tudo certo?"] },
          ],
        },
        {
          name: "Bug Confirmado",
          actions: [
            { action_name: "add_label", action_params: ["bug_confirmado"] },
            { action_name: "assign_team", action_params: [dev_team&.id].compact },
            { action_name: "add_private_note", action_params: ["Bug confirmado. Preencher o atributo \"Issue Jira\" com o link/código da issue e indicar a versão prevista de correção."] },
          ],
        },
        {
          name: "Marcar como Incidente",
          actions: [
            { action_name: "add_label", action_params: ["incidente"] },
            { action_name: "add_private_note", action_params: ["Marcado como incidente - vincular os demais tickets/conversas relacionados usando o vínculo de ticket pai/filho."] },
          ],
        },
      ]

      macros.each do |m|
        next if acc.macros.exists?(name: m[:name])

        acc.macros.create!(name: m[:name], actions: m[:actions], visibility: "global")
        puts "#{acc.name}: macro criada - #{m[:name]}"
      end
    end
  end

  desc "Liga a pesquisa de satisfação (CSAT) em todas as inboxes de todas as contas"
  task enable_csat: :environment do
    count = 0
    Inbox.where(csat_survey_enabled: false).find_each do |inbox|
      inbox.update_column(:csat_survey_enabled, true)
      count += 1
      puts "  CSAT ligado: #{inbox.account.name} / #{inbox.name}"
    end
    puts "[move:enable_csat] #{count} inbox(es) atualizada(s)"
  end

  desc "Cria o atributo 'Setor' (menu do bot de WhatsApp) e a regra de aviso de encerramento pras inboxes de WhatsApp (a pesquisa CSAT em si já é nativa do Chatwoot via csat_survey_enabled)"
  task seed_whatsapp_encerramento: :environment do
    Inbox.where(channel_type: "Channel::Whatsapp").find_each do |inbox|
      acc = inbox.account
      inbox.update_column(:csat_survey_enabled, true)

      # As opções aqui embaixo são só o valor inicial - depois disso, é a
      # lista de valores desse atributo em Configurações > Atributos
      # personalizados que manda, não este seed (ver WhatsappSetorMenuListener).
      unless acc.custom_attribute_definitions.exists?(attribute_key: "setor", attribute_model: "conversation_attribute")
        acc.custom_attribute_definitions.create!(
          attribute_display_name: "Setor",
          attribute_key: "setor",
          attribute_display_type: "list",
          attribute_model: "conversation_attribute",
          attribute_values: ["Suporte Técnico", "Financeiro", "Comercial", "Implantação"]
        )
        puts "#{acc.name}: atributo 'Setor' criado"
      end

      rule_name = "WhatsApp - Encerramento (#{inbox.name})"
      next if acc.automation_rules.exists?(name: rule_name)

      acc.automation_rules.create!(
        name: rule_name,
        description: "Avisa o cliente que o atendimento foi finalizado quando a conversa dessa caixa de WhatsApp é resolvida",
        event_name: "conversation_resolved",
        conditions: [
          { attribute_key: "inbox_id", filter_operator: "equal_to", values: [inbox.id.to_s], query_operator: "and", custom_attribute_type: "standard" }
        ],
        actions: [
          { action_name: "send_message", action_params: ["Seu atendimento foi finalizado. Agradecemos o contato!"] }
        ],
        active: true
      )
      puts "#{acc.name}: regra de encerramento criada pra #{inbox.name}"
    end
  end
end
