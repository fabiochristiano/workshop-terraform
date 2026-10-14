# Demo 3: Dev e prd com states locais separados

> **Slide:** 55 · **Parte 4** · **Duração:** 12 min, fora preparação e espera dos applies.

**Objetivo:** criar dev e prd com o mesmo código, sem um ambiente substituir o outro. Cada ambiente tem seu próprio state e cria random + RG + VNet.

| Ambiente | Backend | State local | Entradas |
|---|---|---|---|
| dev | `backend-dev.hcl` | `states/dev/terraform.tfstate` | `dev.tfvars` |
| prd | `backend-prd.hcl` | `states/prd/terraform.tfstate` | `prd.tfvars` |

**`-backend-config` no init seleciona o state; `-var-file` no plan/apply seleciona os valores.** O `.tfvars` não troca o backend.

## Preparação

No Git Bash, com `ARM_SUBSCRIPTION_ID` configurado, a partir da raiz:

```bash
cd demos/demo3-remote-state
terraform init -backend-config=backend-dev.hcl
terraform plan -var-file=dev.tfvars
# Revisar: 3 to add no primeiro ciclo.
terraform apply -var-file=dev.tfvars
```

Prepare dev antes da demonstração e deixe prd sem recursos. Revise o plan de cada apply antes de confirmar. Todos os próximos comandos são executados nesta mesma pasta.

## Demonstração

Compare `backend-dev.hcl` × `backend-prd.hcl` e `dev.tfvars` × `prd.tfvars` com **Compare Selected**, sem editar código.

### 1. Inspecionar dev

```bash
terraform state list
terraform state show azurerm_virtual_network.vnet
terraform output -raw resource_group_name
terraform plan -var-file=dev.tfvars
# Esperado: No changes.
```

### 2. Selecionar e criar prd

```bash
terraform init -reconfigure -backend-config=backend-prd.hcl
terraform plan -var-file=prd.tfvars
# Revisar: 3 to add, 0 to change, 0 to destroy.
terraform apply -var-file=prd.tfvars
terraform output
```

Mostre os dois RGs no Portal: **dev e prd coexistem**, com nomes `rg-workshop-<env>-demo3-<rand>`. Cada state mantém seu próprio random; RG/VNet do mesmo ambiente compartilham o sufixo.

### 3. Voltar a dev

```bash
terraform init -reconfigure -backend-config=backend-dev.hcl
terraform plan -var-file=dev.tfvars
# Esperado: No changes.
```

## Limpeza e reinício

Na pasta desta demo, confira a subscription e os alvos antes de copiar o bloco inteiro. **Usa `-auto-approve`** e interrompe na primeira falha. Não execute outras operações Terraform nesta pasta durante a limpeza.

```bash
(
  set -euo pipefail
  [[ -f backend-dev.hcl && -f backend-prd.hcl ]] || {
    echo "Execute na pasta da Demo 3." >&2; exit 1;
  }
  for dir in . .terraform states states/dev states/prd; do
    [[ ! -L $dir && ! -f $dir/.terraform.tfstate.lock.info ]] || {
      echo "Link ou lock ativo em $dir; limpeza interrompida." >&2; exit 1;
    }
  done
  if [[ -f terraform.tfstate ]]; then
    addresses=$(terraform state list -state=terraform.tfstate)
    [[ -z $addresses ]] || {
      echo "State antigo com recursos; preserve-o e revise a recuperação." >&2; exit 1;
    }
  fi

  terraform init -reconfigure -backend-config=backend-prd.hcl -input=false
  terraform destroy -var-file=prd.tfvars -auto-approve -input=false
  terraform init -reconfigure -backend-config=backend-dev.hcl -input=false
  terraform destroy -var-file=dev.tfvars -auto-approve -input=false

  for file in terraform.tfstate states/dev/terraform.tfstate states/prd/terraform.tfstate; do
    if [[ -f $file ]]; then
      addresses=$(terraform state list -state="$file")
      [[ -z $addresses ]] || {
        echo "Ainda há recursos em $file; arquivos preservados." >&2; exit 1;
      }
    fi
  done
  rm -f -- terraform.tfstate terraform.tfstate.backup terraform.tfstate.before-envs.bak \
    states/dev/terraform.tfstate states/dev/terraform.tfstate.backup \
    states/prd/terraform.tfstate states/prd/terraform.tfstate.backup \
    tfplan .terraform.lock.hcl
  for dir in states/dev states/prd states; do
    if [[ -d $dir ]]; then rmdir -- "$dir"; fi
  done
  rm -rf -- .terraform
  echo "Demo 3 limpa e pronta para repetir a preparação."
)
```

Destrói dev/prd (3 recursos por ambiente aplicado) e remove states vazios, backups padrão, plan, cache e a pasta `states`. **`rmdir` só remove diretórios vazios**: arquivos inesperados interrompem o reinício. Preserva código/configurações e não afeta outras demos.

Depois, repita a preparação: o primeiro init não precisa de `-reconfigure`.

## Cuidados

- Ao alternar ambientes, use `-reconfigure`, **não `-migrate-state`**. Combine sempre o backend e o `.tfvars` do mesmo ambiente.
- O backend selecionado permanece ativo até outro init. Execute em sequência; não rode dev/prd simultaneamente nesta pasta.
- Não apague um state com recursos. Se existir um state antigo na raiz ou ocorrer erro de backend, pare e investigue; a limpeza preserva arquivos em caso de falha ou lock ativo.
- Os states são exclusivos desta demo e ficam nesta máquina. Backend remoto e locking são conceituais; não há Storage provisionado.

**Plano B:** se houver bloqueio de RBAC/Policy ou falta de tempo para o apply, explique o limite e use gravação do ensaio. Um plan não comprova que os recursos foram criados.
