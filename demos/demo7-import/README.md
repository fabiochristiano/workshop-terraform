# Demo 7: Da Azure CLI para o Terraform com import

> **Demo complementar, sem slide e fora da agenda da apresentação.**
> Independente das Demos 1–6: recursos exclusivos e state local nesta pasta.

**Cenário:** alguém criou um RG, uma VNet e uma subnet pela Azure CLI, fora do Terraform. Agora queremos assumir a gestão com Terraform, sem recriar a infraestrutura.

| Etapa | O que acontece |
|---|---|
| Criar pela Azure CLI | Infraestrutura existe no Azure, mas não no state |
| Ler o código pronto | Os blocos `resource` descrevem a infraestrutura existente |
| Importar os três recursos | Terraform associa cada ID Azure a um endereço no state |
| Conferir o plan | Código e Azure alinhados: nenhuma alteração de infraestrutura |
| Evoluir pelo código | Tags e ampliação da subnet, com plan/apply |

## Por que import nativo, e não aztfexport?

O nome da ferramenta da Microsoft é **Azure Export for Terraform (`aztfexport`)**.

| Opção | Quando usar | O que entrega |
|---|---|---|
| `terraform import` | Poucos recursos, código já escrito; ideal para esta demo | Importa para o state; **não gera código** |
| Blocos `import` | Importação declarativa, revisável no fluxo plan/apply | Planeja e aplica a importação; pode gerar configuração com `plan -generate-config-out=...` |
| `aztfexport` | Descobrir/exportar conjuntos maiores de recursos Azure | Gera HCL e state; ainda exige revisão e organização do código |

**Escolha desta demo: três comandos `terraform import`.** Fica explícita a relação **endereço no código ↔ ID Azure**. Não precisamos instalar outra ferramenta. Em uma adoção maior, vale avaliar `aztfexport`, primeiro em uma pasta separada, nunca sobre o state desta demo. Exportar não dispensa conferir o plan nem garante um código pronto para produção.

Para ver a descoberta e a geração de HCL + state na prática, siga a [Demo 8 — aztfexport](../demo8-aztfexport/README.md), com recursos próprios e sem reutilizar este state.

## 1. Preparar o terminal e os nomes

**Git Bash no VS Code**, a partir da raiz do repositório. Requisitos: Terraform ≥ 1.9, Azure CLI autenticado, RBAC e Policies que permitam RG/VNet/subnet na região. Não precisamos de VMs, Storage ou acesso a endpoints de dados.

```bash
cd demos/demo7-import
az login
az account set --subscription "<sub-id>"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv | tr -d '\r')"
az account show -o table

# Execute uma vez para este ensaio; não gere outro sufixo depois de importar.
export TF_VAR_suffix="$(printf '%04x' "$RANDOM")"
export RG_NAME="rg-workshop-dev-demo7-${TF_VAR_suffix}"
export VNET_NAME="vnet-workshop-dev-demo7-${TF_VAR_suffix}"
export SUBNET_NAME="snet-app-demo7-${TF_VAR_suffix}"
printf 'RG: %s\nVNet: %s\nSubnet: %s\n' "$RG_NAME" "$VNET_NAME" "$SUBNET_NAME"
```

Os comandos seguintes usam esses nomes diretamente. Confirme que o RG ainda não existe; se houver colisão, escolha outro sufixo **antes** de criar a base. Não use recursos de outra demo nem de produção.

O sufixo nasce no terminal, não de um `random_string`: os nomes já existem quando o Terraform assume a gestão. A variável é obrigatória para evitar um nome padrão diferente do recurso real.

Se fechar o terminal, recupere o sufixo de 4 caracteres dos nomes no Portal ou do state e refaça os `export` acima, **sem executar novamente a geração aleatória**:

```bash
export TF_VAR_suffix="<mesmo-sufixo>"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv | tr -d '\r')"
export RG_NAME="rg-workshop-dev-demo7-${TF_VAR_suffix}"
export VNET_NAME="vnet-workshop-dev-demo7-${TF_VAR_suffix}"
export SUBNET_NAME="snet-app-demo7-${TF_VAR_suffix}"
```

## 2. Criar pela Azure CLI, fora do Terraform

Na mesma pasta e terminal do passo 1, use a subscription de `ARM_SUBSCRIPTION_ID`. A região padrão é **Brazil South**. Se não for permitida, execute `export TF_VAR_location="<regiao>"` **antes** dos comandos abaixo e mantenha essa variável nos próximos passos. Não contorne Policies.

Execute um comando por vez e só avance se ele terminar com sucesso:

```bash
az group create \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --name "$RG_NAME" \
  --location "${TF_VAR_location:-brazilsouth}" \
  --tags ambiente=dev owner=time-plataforma managed_by=cli

az network vnet create \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --resource-group "$RG_NAME" \
  --name "$VNET_NAME" \
  --location "${TF_VAR_location:-brazilsouth}" \
  --address-prefixes "10.10.0.0/16" \
  --tags ambiente=dev owner=time-plataforma managed_by=cli

az network vnet subnet create \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --resource-group "$RG_NAME" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --address-prefixes "10.10.0.0/24" \
  --default-outbound-access false \
  --private-endpoint-network-policies Disabled
```

A VNet é criada sem `--subnet-name`; a única subnet é criada pelo terceiro comando. As tags são aplicadas separadamente no RG e na VNet: **tags do RG não são herdadas automaticamente**.

Não criamos VMs, NAT Gateway, NSG, route table, service endpoints, delegações ou serviços pagos adicionais. A subnet fica vazia e privada, com `default_outbound_access_enabled = false`, alinhada ao código Terraform.

Confira o resultado sem sair do terminal:

```bash
az network vnet show \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --resource-group "$RG_NAME" \
  --name "$VNET_NAME" \
  --query '{name:name,addressSpace:addressSpace.addressPrefixes,tags:tags,subnets:subnets[].{name:name,prefix:addressPrefix,prefixes:addressPrefixes,defaultOutboundAccess:defaultOutboundAccess,privateEndpointNetworkPolicies:privateEndpointNetworkPolicies}}' \
  --output json
```

Esperado: VNet `10.10.0.0/16`, uma única subnet `10.10.0.0/24`, default outbound access `false`, policies de Private Endpoints `Disabled` e as três tags. A API pode retornar o prefixo em `prefix` ou `prefixes`.

Se a CLI/Policy resultar em propriedades diferentes, investigue o plan e alinhe o código à configuração que deseja preservar; não aplique uma alteração acidental para “concluir o import”.

## 3. Mostrar o código e inicializar

Abra [main.tf](main.tf) e [01-importar.tfvars](01-importar.tfvars). Já descrevem exatamente a base manual. Não é necessário editar código ao vivo.

- `azurerm_resource_group.rg`: RG existente.
- `azurerm_virtual_network.vnet`: VNet existente.
- `azurerm_subnet.app`: subnet existente, como recurso separado.
- Sem bloco `subnet` inline na VNet: não misturamos as duas formas de gerenciar subnets.

```bash
terraform init
terraform validate
terraform state list
terraform plan -var-file=01-importar.tfvars
```

Em uma pasta sem state, `state list` pode informar que ainda não existe state. O plan deve propor **3 to add**: o Terraform não conhece os vínculos, mesmo que os nomes já existam no Azure.

**Não execute apply.** Isso não é uma descoberta automática de recursos existentes. O próximo passo é importar, não tentar criá-los novamente. Se aparecerem recursos no state de um ensaio anterior, confira os alvos antes de continuar.

## 4. Importar RG, VNet e subnet

Os IDs são montados a partir da subscription selecionada e dos nomes que você acabou de usar. No Portal, também é possível conferi-los em **JSON View / Resource ID**.

```bash
export RG_ID="/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}"
export VNET_ID="${RG_ID}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}"
export SUBNET_ID="${VNET_ID}/subnets/${SUBNET_NAME}"
printf '%s\n' "$RG_ID" "$VNET_ID" "$SUBNET_ID"

MSYS_NO_PATHCONV=1 terraform import -var-file=01-importar.tfvars \
  azurerm_resource_group.rg "$RG_ID"
MSYS_NO_PATHCONV=1 terraform import -var-file=01-importar.tfvars \
  azurerm_virtual_network.vnet "$VNET_ID"
MSYS_NO_PATHCONV=1 terraform import -var-file=01-importar.tfvars \
  azurerm_subnet.app "$SUBNET_ID"
```

Execute um comando por vez e confira o sucesso antes do seguinte. `MSYS_NO_PATHCONV=1` impede que o Git Bash transforme `/subscriptions/...` em um caminho do Windows.

**O import lê o Azure e grava o vínculo no state; não recria nem altera os recursos.** Também não escreve o HCL. O código desta pasta foi preparado antes.

**Importar o RG não importa seus filhos. Importar a VNet não substitui a importação da subnet para o endereço separado.** Neste modelo são três vínculos, portanto três imports.

Se um comando falhar, corrija o erro e repita somente o import que faltou. Preserve os vínculos já importados. Um recurso deve pertencer a **um único endereço em um único state**; não importe os mesmos objetos em outra demo.

## 5. Comprovar a adoção sem mudanças

```bash
terraform state list
terraform state show azurerm_subnet.app
terraform plan -var-file=01-importar.tfvars
```

O state deve listar exatamente:

```text
azurerm_resource_group.rg
azurerm_subnet.app
azurerm_virtual_network.vnet
```

**Critério: `0 to add, 0 to change, 0 to destroy` para recursos.** O plan pode mostrar apenas novos outputs, pois o import via CLI não os persiste necessariamente. Nesse caso, após conferir que não há alterações de recursos:

```bash
terraform apply -var-file=01-importar.tfvars
terraform plan -var-file=01-importar.tfvars
```

Agora esperamos **No changes**, inclusive para outputs.

Se aparecer criação, exclusão, `-/+` ou alteração de recurso, **pare**. Compare nomes, região, tags (inclusive as adicionadas por Policy), prefixos e opções da subnet. Não use `ignore_changes` para esconder diferenças nem aplique para “ver se funciona”. O objetivo é reproduzir a base existente antes de evoluir.

## 6. Evoluir a infraestrutura pelo Terraform

No VS Code, use **Select for Compare / Compare with Selected** entre [01-importar.tfvars](01-importar.tfvars) e [02-evoluir.tfvars](02-evoluir.tfvars):

- RG e VNet: `managed_by` muda de `cli` para `terraform`.
- RG e VNet: inclusão de `centro_custo = "1234"`.
- Subnet app: ampliação de **`10.10.0.0/24` para `10.10.0.0/23`**, dentro da mesma VNet.

Essa ampliação pressupõe subnet **vazia**, sem outro prefixo sobreposto. Não use essa mudança como receita para redes de produção ocupadas.

```bash
terraform plan -var-file=02-evoluir.tfvars -out=tfplan
# Revisar: 0 to add, 3 to change, 0 to destroy; somente alterações in-place (~).
terraform apply tfplan
terraform plan -var-file=02-evoluir.tfvars
terraform output
```

**`apply tfplan` aplica o plan salvo sem pedir confirmação.** Só execute se o plan contiver exatamente as três alterações esperadas, sem substituições.

Confira no Portal as novas tags e o prefixo `/23`. O último plan deve mostrar **No changes**. A infraestrutura mantém os mesmos IDs: agora suas mudanças passam por código e revisão de plan.

**Daqui em diante, use `02-evoluir.tfvars`.** Voltar ao arquivo `01-importar.tfvars` propõe desfazer a evolução. Os dois arquivos usam **o mesmo state**, não representam ambientes diferentes.

## 7. Limpeza opcional e autorizada

O import também permite ao Terraform **destruir** esses recursos. Só faça isso no laboratório descartável e depois de verificar no Portal que o RG contém **apenas a VNet e a subnet desta demo**, sem recursos adicionados por terceiros.

```bash
terraform plan -destroy -var-file=02-evoluir.tfvars -out=destroy.tfplan
# Esperado: 0 to add, 0 to change, 3 to destroy. Conferir nomes e IDs.
terraform apply destroy.tfplan
terraform state list
```

O apply do plan salvo não pede nova confirmação. Excluir um RG pode excluir recursos dentro dele que nem constam no state; por isso a inspeção do RG é obrigatória.

Não quer destruir? Não execute esses comandos e preserve o state. **Apagar o state não é cleanup.** O script geral `demos/setup/cleanup.sh` **não inclui a Demo 7**; a limpeza desta adoção manual é explícita e separada.

## Validação sem Azure

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```


## Referências oficiais

- [Terraform CLI: import](https://developer.hashicorp.com/terraform/cli/import)
- [Blocos import e geração de configuração](https://developer.hashicorp.com/terraform/language/import)
- [Azure Export for Terraform: visão geral](https://learn.microsoft.com/azure/developer/terraform/azure-export-for-terraform/export-terraform-overview)
- [AzureRM: import de Resource Group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group#import)
- [AzureRM: import de Virtual Network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network#import)
- [AzureRM: import de Subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet#import)
