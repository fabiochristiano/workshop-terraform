# Demo 4: Drift de tags na VNet

> **Slide:** 59 · **Parte 5** · **Duração:** 11 min de demonstração
> **Independente:** cria uma base própria; não depende das Demos 2/3.

State local nesta pasta. Recursos `rg-workshop-dev-demo4-<rand>` e `vnet-workshop-dev-demo4-<rand>`, com o mesmo random de 4 caracteres minúsculos/numéricos. Nenhum state compartilhado com outra demo.

| Mudança no Portal, na VNet | Tipo de drift |
|---|---|
| `owner`: `time-plataforma` → `time-engenharia` | Alteração de uma tag existente |
| Adicionar `centro_custo = "1234"` | Inclusão de uma tag |

**Nesta demo, as duas mudanças do Portal estão corretas.** Vamos detectá-las com plan e atualizar o state sem revertê-las. `managed_by` permanece `terraform`; não há mudança de TLS, acesso público ou Shared Key.

## Preparação própria

No Git Bash, com `ARM_SUBSCRIPTION_ID` configurado, a partir da raiz do repositório:

```bash
cd demos/demo4-drift
terraform init
terraform plan -var-file=dev.tfvars -out=tfplan
# Revisar: 3 to add no primeiro ciclo (random + RG + VNet).
terraform apply tfplan
terraform output -raw vnet_name
```

Na primeira inicialização, não é necessário `-reconfigure`. **`apply tfplan` executa o plan salvo sem pedir nova confirmação**; revise-o antes de aplicar. Se houver erro de backend ou state antigo, investigue antes de reconfigurar. Os comandos seguintes são executados nesta mesma pasta.

Crie a base no início ou na preparação técnica para manter os 11 min de exposição. Procure no Portal o **nome completo** retornado pelo output. Não use o nome de outra demo.

Se já ensaiou a versão anterior, confira as tags antes de começar: VNet/RG com `owner = "time-plataforma"`, `managed_by = "terraform"` e sem `centro_custo`. Revise o plan; só restaure essa base com `apply -var-file=dev.tfvars` se as mudanças do ensaio forem descartáveis e a reversão estiver autorizada.

## Roteiro (nesta pasta)

| # | Ação | Evidência | Tempo |
|---|---|---|---|
| 1 | `terraform plan -var-file=dev.tfvars` | **No changes** | 0,5' |
| 2 | Output → abrir a VNet correta no Portal | Alvo exclusivo desta demo | 1' |
| 3 | Tags da VNet: owner = time-engenharia; adicionar centro_custo = 1234; salvar | Alteração + inclusão; manter managed_by = terraform | 2' |
| 4 | `terraform plan -var-file=dev.tfvars` | Quer restaurar owner e remover centro_custo; **1 to change** | 2' |
| 5 | Decidir: **o Portal está correto** | Não aplicar o plan de reversão | 0,5' |
| 6 | `terraform plan -refresh-only -var-file=dev.tfvars` | Mostra o que mudou entre o state e o Azure | 1,5' |
| 7 | `terraform apply -refresh-only -var-file=dev.tfvars` | Revisar e confirmar; grava a realidade no state, sem mudar o Azure | 1,5' |
| 8 | `terraform state show azurerm_virtual_network.vnet` | State contém owner novo e centro_custo | 1' |
| 9 | `terraform plan -var-file=dev.tfvars` | Ainda **1 to change**: o código continua antigo; não aplicar | 1' |

Depois de decidir que o Portal está correto, execute:

```bash
terraform plan -refresh-only -var-file=dev.tfvars
terraform apply -refresh-only -var-file=dev.tfvars
terraform state show azurerm_virtual_network.vnet
```

**Plan apenas mostra; apply salva.** Com `-refresh-only`, o apply atualiza o state e outputs, mas não altera os recursos nem os arquivos de código. Não use um plan salvo da preparação depois de alterar as tags.

O state agora reflete o Portal, mas `dev.tfvars` ainda define o owner antigo. Por isso, o plan normal do passo 9 propõe reverter as duas tags. Um novo `plan -refresh-only` deve mostrar **No changes**, pois compara state × Azure, não os valores desejados do código.

## Continuidade: alinhar o código

Para preservar essas mudanças nos próximos applies, as entradas também precisam refletir a decisão. Fora do roteiro principal, o arquivo pronto `dev-centro-custo.tfvars` inclui **owner = time-engenharia e centro_custo = 1234**, sem edição ao vivo.

```bash
terraform plan -var-file=dev-centro-custo.tfvars
```

Esperado: **1 to change no RG**, não na VNet. Ambos usam tags comuns; adotar essas entradas também propõe atualizar o RG. Só aplique se quiser aprovar essa extensão da mudança. Depois de um apply com esse arquivo, o plan normal correspondente deve mostrar **No changes**.

## Plano B

Portal lento: nesta mesma pasta, use:

```bash
bash simulate-drift.sh
```

O script obtém RG/VNet dos outputs **desta demo** e faz merge das tags via APIs de gerenciamento, sem apagar as demais. Para outro alvo autorizado, use `--resource-group` e `--vnet-name` explicitamente. Se uma Policy negar a mudança, explique a prevenção de drift e use gravação; não altere a Policy.

## Limpeza

Após a demonstração:

```bash
terraform destroy -var-file=dev.tfvars
terraform state list
```

São **3 destroyed**. A Demo 5 prepara seu próprio ambiente, sem usar este state.
