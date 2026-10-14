# Demo 5: RG, VNet e duas subnets com módulos locais

> **Slide:** 69 · **Parte 6** · **Duração:** até 10,5 min, fora a espera do apply.

**Objetivo:** repetir o cenário RG/VNet, agora com um módulo por recurso, e chamar o mesmo módulo de subnet duas vezes na mesma VNet. Código pronto, sem edição ao vivo, moved ou implantação AVM.

| Chamada no root | Módulo | Recurso |
|---|---|---|
| `module.resource_group` | `modules/resource-group` | Resource Group |
| `module.vnet` | `modules/vnet` | VNet `10.10.0.0/16` |
| `module.subnet_app` | `modules/subnet` | Subnet `10.10.1.0/24` |
| `module.subnet_data` | `modules/subnet` | Subnet `10.10.2.0/24` |

As referências aos outputs definem a ordem: **RG → VNet → duas subnets**. Um random de 4 caracteres é compartilhado pelos nomes, todos com sufixo `-demo5-<rand>`. State local nesta pasta, independente das outras demos.

## Preparação

No Git Bash, com `ARM_SUBSCRIPTION_ID` configurado, a partir da raiz:

```bash
cd demos/demo5-modules
terraform init
```

Não há base para aplicar antes da demo. Se houver state de um ensaio com as etapas antigas, preserve-o e revise a recuperação antes de usar este código; não aplique uma substituição sem investigar.

## Demonstração

1. Abrir `main.tf`: quatro chamadas, com `modules/subnet` reutilizado.
2. Mostrar `main.tf`, `variables.tf` e `outputs.tf` de um módulo: recurso, entradas e saídas.
3. Executar:

```bash
terraform plan -var-file=dev.tfvars
# Revisar: 5 to add, 0 to change, 0 to destroy.
terraform apply -var-file=dev.tfvars
# Revisar e confirmar.
```

São **4 recursos Azure + random**, sem VMs ou serviços dentro das subnets. As duas instâncias de subnet usam o mesmo código, com nomes e prefixos diferentes. AVM permanece conceitual nos slides.

## Limpeza

Nesta mesma pasta, confira a subscription. O bloco para na primeira falha:

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

**Usa `-auto-approve`**: revise os alvos antes. Esperado: **5 destroyed**; preserve state vazio/backups. Nenhuma outra demo é afetada.

**Plano B:** se a Policy/RBAC bloquear recursos ou o apply demorar, explique o erro e use gravação do ensaio; não contorne Policies.
