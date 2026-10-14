# Demo 1: Resource Group + VNet

> **Slide:** 36 · **Parte 2** · **Duração:** ~16 min
> **Objetivo:** criar e editar um único `main.tf` ao vivo: `init → fmt → validate → plan → apply → alterar → destroy`.
> **Terminal:** Git Bash no VS Code. Os recursos são gerenciados via Azure Resource Manager; não há Storage, Private Endpoint ou autenticação por Shared Key.

## Uma pasta, um arquivo

O `main.tf` presente é o código inicial válido do ensaio, já sem Storage. Para começar do zero na apresentação, remova-o **somente após o destroy e a conferência do state vazio**, conforme a seção de reinício.

```text
demo1-rg-vnet/
├── README.md
├── main.tf                 ← criado e editado ao vivo
├── .terraform/             ← init
├── .terraform.lock.hcl      ← init
├── tfplan                  ← plan salvo
└── terraform.tfstate       ← state local padrão, nesta mesma pasta
```

| Recurso | Nome |
|---|---|
| RG | `rg-workshop-demo1-<rand>`, em `brazilsouth` |
| VNet | `vnet-workshop-demo1-<rand>`, espaço `10.10.0.0/16` |

`<rand>` são 4 caracteres minúsculos/numéricos de um único `random_string.suffix`, compartilhado pelos recursos da Demo 1. O valor fica no state: não muda a cada plan/apply. Um novo ciclo após destroy gera outro valor. Há **3 recursos Terraform**: random + RG + VNet; apenas 2 são recursos Azure.

Uma VNet representa uma rede privada, mas **criá-la/consultá-la não exige entrar nessa rede**: Terraform usa o plano de gerenciamento. Nenhuma VM, Private Endpoint ou serviço de dados será criado. Ainda é necessário RBAC de gerenciamento e que as Policies permitam RGs/VNets na região escolhida.

Não use o state da antiga tentativa com Storage. Ele permanece em [`../demo1-rg-storage/`](../demo1-rg-storage/README.md), com orientação de recuperação. Os nomes de RG diferentes evitam confusão entre os dois ambientes.

## Preparação

A partir da raiz do repositório:

```bash
az login
az account set --subscription "<sub-id>"
export ARM_SUBSCRIPTION_ID="$(
  az account show --query id -o tsv | tr -d '\r'
)"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p "$TF_PLUGIN_CACHE_DIR"
cd demos/demo1-rg-vnet
az account show -o table
```

Confirme a subscription e se os nomes estão livres ou vinculados ao state deste laboratório. Não aplique com state vazio para tentar adotar recursos existentes.

## Roteiro (~16 min)

| # | Ação | Evidência | Tempo |
|---|---|---|---|
| 1 | Conferir subscription | Ambiente correto | 0,5' |
| 2 | Criar `main.tf` com Terraform/provider | Um único arquivo | 1,5' |
| 3 | `init` | Provider e lock file | 1' |
| 4 | Adicionar RG com erro; `fmt -check` e `fmt` | Formatação, não correção de digitação | 0,5' |
| 5 | `validate`, corrigir e validar | Erro e depois sucesso | 1' |
| 6 | Acrescentar VNet; `fmt`, `validate`, `plan -out=tfplan` | **3 to add** (random + RG + VNet) | 1,5' |
| 7 | `apply tfplan`; conferir no Portal | RG antes da VNet | 3' |
| 8 | `apply` de novo | **No changes** | 0,5' |
| 9 | Adicionar tags; `plan` e `apply` | **1 to change** | 2' |
| 10 | Alterar nome; só `plan`; restaurar | **1 to add / 1 to destroy**, depois No changes | 1,5' |
| 11 | `ls -l terraform.tfstate`; `state list` | State na pasta | 0,5' |
| 12 | `destroy` | **3 destroyed** | 1,5' |

Pare e corrija erros antes de avançar. As únicas falhas esperadas são o fmt/validate do exemplo proposital.

### 2–3. Criar main.tf e inicializar

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

Salve e rode:

```bash
terraform init
```

O `subscription_id` vem de `ARM_SUBSCRIPTION_ID`. O provider `random` gera o sufixo localmente; não cria um serviço no Azure. Não há configuração de Storage.

### 4–5. Formatar e corrigir

Acrescente ao mesmo arquivo, propositalmente errado:

```hcl
resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "rg" {
name = "rg-workshop-demo1-${random_string.suffix.result}"
      locaton    =     "brazilsouth"
}
```

```bash
terraform fmt -check
terraform fmt
terraform validate
```

O check retorna código 3; fmt corrige a indentação, mas validate aponta `locaton` e a ausência de `location`. Troque `locaton` por `location`, salve e rode:

```bash
terraform fmt
terraform validate
```

### 6–7. Acrescentar VNet e aplicar

Mantenha o RG já corrigido. Acrescente:

```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-workshop-demo1-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.10.0.0/16"]
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}
```

```bash
terraform fmt
terraform validate
terraform plan -out=tfplan
```

Revise `Plan: 3 to add, 0 to change, 0 to destroy.`, os `+` e `(known after apply)`. O sufixo e os nomes completos só ficam conhecidos após apply. Se correto:

```bash
terraform apply tfplan
```

Plano salvo não pede outra confirmação. Não edite entre plan e apply. Mostre RG e VNet no Portal; não há endpoint de dados para aguardar.

### 8. Idempotência

```bash
terraform apply
```

Sem mudanças externas, resultado esperado: **No changes**.

### 9. Tags — update in-place

Dentro do bloco da VNet, acrescente:

```hcl
  tags = {
    env   = "dev"
    owner = "workshop"
  }
```

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

Revise `0 to add, 1 to change, 0 to destroy` e confirme `yes`. Mostre as tags da VNet.

### 10. Nome novo — apenas plan

Troque somente o nome da VNet:

```hcl
  name = "vnet-alterada-demo1-${random_string.suffix.result}"
```

```bash
terraform fmt
terraform plan
```

Mostre `-/+`, `forces replacement` e `1 to add, 0 to change, 1 to destroy`. **Não aplique.** Em produção, substituir uma rede pode afetar recursos associados.

Restaure:

```hcl
  name = "vnet-workshop-demo1-${random_string.suffix.result}"
```

```bash
terraform fmt
terraform plan
```

Esperado: **No changes**; as tags permanecem.

### 11–12. State e destroy

```bash
ls -l terraform.tfstate
terraform state list
terraform destroy
```

Revise `0 to add, 0 to change, 3 to destroy` e confirme `yes`. Esperado: **3 destroyed**. As outras demos têm recursos, sufixos e states próprios.

## Plano B

- Init lento: providers no cache desde o ensaio.
- Erro de edição: compare com os trechos do README e valide antes de prosseguir.
- Policy/RBAC bloqueando RG/VNet: explique o erro e use a gravação; não contorne a restrição.
- API lenta: use o vídeo do ensaio, sem prometer um tempo fixo de criação.

## Reinício seguro após o ensaio

Se interrompeu a demo, preserve o código e o state. Termine primeiro:

```bash
terraform init
terraform destroy
```

Só após destroy bem-sucedido, use este bloco para voltar à pasta sem `.tf`:

```bash
(
  set -euo pipefail
  [[ $(basename "$PWD") == demo1-rg-vnet ]] || {
    echo "Entre na pasta demo1-rg-vnet." >&2
    exit 1
  }
  remaining=$(terraform state list)
  [[ -z $remaining ]] || {
    echo "Ainda há recursos no state; não remova os arquivos." >&2
    exit 1
  }
  rm -f -- main.tf tfplan terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
  rm -rf -- .terraform
)
```

Não remova o README nem o state da tentativa antiga com Storage.
