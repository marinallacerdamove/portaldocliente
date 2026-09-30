# PATCH LOCAL (fork) - variáveis extras das mensagens e macros: {{ticket.*}}
# (TicketDrop) e {{saudacao}} ("Bom dia", "Boa tarde" ou "Boa noite" no
# horário de Brasília). Mesmas chaves do menu "Variáveis" do painel
# (shared/constants/portalVariables.js).
module PortalVariables
  TIME_ZONE = 'America/Sao_Paulo'.freeze

  module_function

  def assigns(conversation)
    { 'ticket' => TicketDrop.new(conversation), 'saudacao' => greeting }
  end

  def greeting(time = Time.current)
    hour = time.in_time_zone(TIME_ZONE).hour
    return 'Bom dia' if hour < 12
    return 'Boa tarde' if hour < 18

    'Boa noite'
  end
end
