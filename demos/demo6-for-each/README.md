# Demo 6: Duas subnets com for_each

> **Slide:** 76 · **Parte 7** · **Duração:** 6 min, fora a espera do apply.

**Objetivo:** repetir o cenário da Demo 5, substituindo duas chamadas de subnet por um único bloco `module` com `for_each`.

```hcl
subnets = {
  app  = "10.10.1.0/24"
  data = "10.10.2.0/24"
}
```

- `each.key`: `app` ou `data`, usado no nome da subnet.
- `each.value`: prefixo de endereço de cada subnet.
- Referências aos outputs conectam RG → VNet → subnets.

Reutiliza o **código** dos módulos em `../demo5-modules/modules`, não seus recursos. State próprio nesta pasta e sufixo `-demo6-<rand>`, compartilhado pelos quatro recursos Azure. Não depende de um apply da Demo 5; mantenha ambas as pastas no repositório.

## Preparação

No Git Bash, com `ARM_SUBSCRIPTION_ID` configurado, a partir da raiz:

```bash
cd demos/demo6-for-each
terraform init
```

## Demonstração

1. Comparar o root da Demo 5 com este: duas chamadas viraram um bloco `module.subnet`.
2. Abrir `locals.tf`: chave identifica a instância, valor configura o prefixo.
3. Executar, sem editar código:

```bash
terraform plan -var-file=dev.tfvars
# Revisar: 5 to add, 0 to change, 0 to destroy.
terraform apply -var-file=dev.tfvars
terraform state list
terraform output subnet_ids
```

Endereços das duas subnets:

```text
module.subnet["app"].azurerm_subnet.this
module.subnet["data"].azurerm_subnet.this
```

São random + RG + VNet + duas subnets, como na Demo 5. As chaves do map são conhecidas antes do apply; o random entra apenas nos nomes, não nas chaves. Renomear/remover uma chave pode planejar substituição/remoção: leia o plan.

## Limpeza

Nesta pasta, confira a subscription e os alvos. **Usa `-auto-approve`**:

```bash
(
  set -euo pipefail
  terraform destroy -var-file=dev.tfvars -auto-approve
  addresses=$(terraform state list)
  [[ -z $addresses ]] || {
    echo "Ainda há recursos; state preservado." >&2; exit 1;
  }
)
```

Esperado: **5 destroyed**, sem afetar a Demo 5. Preserve states vazios/backups. Não apague state para reiniciar.

**Plano B:** API lenta ou Policy/RBAC bloqueando recursos: explique o erro e use gravação/prints do ensaio.
