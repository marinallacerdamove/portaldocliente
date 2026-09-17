json.payload do
  json.array! @bot_flows do |bot_flow|
    json.partial! 'api/v1/accounts/bot_flows/partials/bot_flow', formats: [:json], bot_flow: bot_flow
  end
end
