# Demo 2: Variables, locals, outputs e data source

> **Slide:** 45 · **Parte 3** · **Duração:** 12 min
> **Independente:** cria seus recursos do zero, sem usar a Demo 1.

Código pronto, sem edição ao vivo. Compare o `main.tf` da [Demo 1](../demo1-rg-vnet/README.md) com este: valores fixos viraram `var.`/`local.`, e Terraform/providers estão em `providers.tf`.

| Arquivo | Conceito |
|---|---|
| `variables.tf` | project, env com validation, location, tags e address_space |
| `naming.tf` | Um random de 4 caracteres, persistido no state |
| `locals.tf` | Prefixo, sufixo `demo2-<rand>` e tags comuns com merge |
| `main.tf` | RG + VNet parametrizados |
| `data.tf` | Consulta a identidade atual, não gerencia recursos |
| `outputs.tf` | Nome do RG, nome/ID da VNet e tenant |
| `dev.tfvars` / `prd.tfvars` | Valores dos ambientes |

Nomes em dev: `rg-workshop-dev-demo2-<rand>` e `vnet-workshop-dev-demo2-<rand>`. O mesmo `<rand>` de 4 caracteres minúsculos/numéricos é usado nos dois recursos; não muda entre plans/applies. O backend local padrão grava `terraform.tfstate` **nesta pasta**, nunca usado por outra demo.

**Ensaio anterior ao isolamento:** se há state com recursos de nomes antigos, preserve-o e revise a recuperação antes de aplicar este código. Mudar o naming pode planejar substituições. Não copie nem apague states para reiniciar.

## Preparação

No Git Bash, a partir da raiz do repositório, entre na pasta da demo e inicialize:

```bash
cd demos/demo2-variables
terraform init
```

O `init` prepara esta pasta: baixa os providers `azurerm` e `random`, inicializa o backend local e gera o lock file. **Não cria recursos no Azure.** Na primeira execução, não é necessário `-reconfigure`; essa opção serve para descartar uma configuração de backend previamente inicializada, sem migrar o state. Se houver um ensaio antigo, investigue antes de reconfigurar.

Os comandos da seção seguinte são executados nesta mesma pasta.

Confira subscription/`ARM_SUBSCRIPTION_ID`. Somente APIs de gerenciamento: não há Storage ou conectividade privada.

## Execução (nesta pasta)

| # | Ação | Mostrar | Tempo |
|---|---|---|---|
| 1 | Abrir variables/main | Entradas e uso | 2' |
| 2 | Abrir naming/locals | Um sufixo para os dois recursos; tags | 1,5' |
| 3 | `terraform plan -var-file=dev.tfvars` | **3 to add**, incluindo random | 2' |
| 4 | `terraform plan -var-file=prd.tfvars` | **3 to add**, outro env; não aplicar | 1,5' |
| 5 | `terraform plan -var="env=producao"` | Validation barra o valor | 1' |
| 6 | `terraform apply -var-file=dev.tfvars` | Revisar e confirmar; cria dev | 2' |
| 7 | `terraform output`; `terraform output -raw vnet_name` | Nomes completos com sufixo e outputs | 1' |
| 8 | Abrir data e output tenant_id | Data source lê, não gerencia | 1' |

Trocar tfvars **não isola ambientes nem troca state**. Aqui os dois plans são feitos antes do apply de dev. Não aplique prd nem tente reutilizar esse state para ambos os ambientes. Antes do primeiro apply, os nomes derivados do random aparecem como `(known after apply)`.

## Extra: precedência

```bash
terraform plan -var-file=dev.tfvars -var="location=eastus"
export TF_VAR_location="eastus2"
terraform plan -var-file=dev.tfvars
unset TF_VAR_location
```

O tfvars fornecido na CLI vence uma variável de ambiente que declare o mesmo valor.

## Plano B e limpeza

- Falta de env: forneça `-var-file=dev.tfvars`.
- Policy/RBAC bloqueando recursos ou API lenta: explique o erro e use gravação.
- Após a demonstração, revise e destrua **somente esta demo**:

```bash
terraform destroy -var-file=dev.tfvars
terraform state list
```

São **3 destroyed**. Preserve o state vazio/backups. A Demo 3 começa do zero, em outra pasta/state.
