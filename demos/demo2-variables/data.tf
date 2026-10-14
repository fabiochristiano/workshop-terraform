# Data source: apenas LÊ informação. Não cria nem gerencia nada.
# Aqui lemos "quem eu sou" no Azure (tenant, subscription e identidade autenticada).
data "azurerm_client_config" "current" {}
