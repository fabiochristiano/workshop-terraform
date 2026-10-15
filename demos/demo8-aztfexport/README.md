# Demo 8: Descobrir recursos e gerar Terraform com aztfexport

> **Demo complementar, sem slide e fora da agenda da apresentação.**
> Independente das Demos 1–7: recursos exclusivos e state local na pasta de exportação.

**Objetivo:** ver como o **Azure Export for Terraform (`aztfexport`)** descobre recursos existentes no Azure e gera os blocos HCL e os vínculos no state, sem escrever os `resource` manualmente.

Na [Demo 7](../demo7-import/README.md), o código já estava pronto e usamos `terraform import` para registrar cada recurso. Aqui começamos **sem arquivos `.tf`**: a ferramenta descobre e gera. O resultado é um ponto de partida para revisão, não um módulo pronto para produção.

| Etapa | O que mostrar |
|---|---|
| Criar a base pela Azure CLI | RG, VNet e subnet existem fora do Terraform |
| Executar `aztfexport resource-group` | Descoberta dos recursos e mapeamento para tipos Terraform |
| Exportar | Geração de HCL e state local |
| Inspecionar e executar plan | Os recursos foram adotados, não recriados |
| Limpar | Destruição apenas dos recursos desta demo |

Não usamos recursos da Demo 7: **o mesmo recurso não deve ser gerenciado por dois states**. Não criamos VMs, Storage, Private Endpoints ou serviços que exijam acesso ao plano de dados.

## 1. Preparar as ferramentas e o terminal

**Git Bash no VS Code**, a partir da raiz do repositório. Requisitos: Terraform ≥ 1.9, Azure CLI, `aztfexport`, permissão **Contributor** e Policies que permitam RG/VNet/subnet na região.

Se o `aztfexport` ainda não estiver instalado, instale antes da apresentação:

```bash
winget install --id Microsoft.Azure.AztfExport --exact --source winget
```

Após instalar, **feche todas as janelas do VS Code e abra-o novamente** para carregar o PATH atualizado. Abrir apenas outra aba de terminal pode manter o PATH antigo.

Se aparecer `bash: aztfexport: command not found`, confira a instalação:

```bash
winget list --id Microsoft.Azure.AztfExport --exact
```

Na instalação padrão do Windows, é possível liberar o comando no Git Bash atual, sem reiniciar o VS Code:

```bash
export PATH="/c/Program Files/aztfexport:$PATH"
hash -r
aztfexport --version
```

Esse ajuste vale somente para o terminal atual. Se o pacote estiver instalado em outro local, use a pasta que contém `aztfexport.exe`; se não estiver instalado, conclua a instalação antes de continuar.

Confira as versões e autentique:

```bash
cd demos/demo8-aztfexport
terraform version
az version
aztfexport --version
aztfexport resource-group --help

az login
az account set --subscription "<sub-id>"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv | tr -d '\r')"
az account show -o table
```

Usamos autenticação da Azure CLI, sem client secret. A subscription do provider vem de `ARM_SUBSCRIPTION_ID`, não de um ID fixo no código.

## 2. Definir nomes exclusivos

Execute **uma vez por ensaio**, no mesmo terminal:

```bash
export DEMO8_SUFFIX="$(printf '%04x' "$RANDOM")"
export DEMO8_RG="rg-workshop-dev-demo8-${DEMO8_SUFFIX}"
export DEMO8_VNET="vnet-workshop-dev-demo8-${DEMO8_SUFFIX}"
export DEMO8_SUBNET="snet-app-demo8-${DEMO8_SUFFIX}"
export DEMO8_LOCATION="brazilsouth"
export DEMO8_OUTPUT="exportacao-${DEMO8_SUFFIX}"

printf 'Subscription: %s\nRG: %s\nVNet: %s\nSubnet: %s\nPasta: %s\n' \
  "$ARM_SUBSCRIPTION_ID" "$DEMO8_RG" "$DEMO8_VNET" "$DEMO8_SUBNET" "$DEMO8_OUTPUT"
az group exists --subscription "$ARM_SUBSCRIPTION_ID" --name "$DEMO8_RG"
```

**Esperado: `false`.** Se o RG já existir, pare e escolha outro sufixo antes de continuar. Não reutilize um RG existente. Se Brazil South não for permitida, ajuste `DEMO8_LOCATION` antes de criar a base; não contorne Policies.

Se fechar o terminal, recupere o mesmo sufixo dos nomes no Portal ou da pasta de exportação e refaça as variáveis acima com ele, **sem gerar outro valor aleatório**. Confirme também a subscription.

## 3. Criar a infraestrutura fora do Terraform

Execute um comando por vez e só avance após sucesso:

```bash
az group create \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --name "$DEMO8_RG" \
  --location "$DEMO8_LOCATION" \
  --tags ambiente=dev owner=time-plataforma managed_by=cli demo=demo8

az network vnet create \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --resource-group "$DEMO8_RG" \
  --name "$DEMO8_VNET" \
  --location "$DEMO8_LOCATION" \
  --address-prefixes "10.18.0.0/16" \
  --tags ambiente=dev owner=time-plataforma managed_by=cli demo=demo8

az network vnet subnet create \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --resource-group "$DEMO8_RG" \
  --vnet-name "$DEMO8_VNET" \
  --name "$DEMO8_SUBNET" \
  --address-prefixes "10.18.0.0/24" \
  --default-outbound-access false \
  --private-endpoint-network-policies Disabled
```

A VNet é criada sem subnet inline; o terceiro comando cria a única subnet. Tags do RG não são herdadas automaticamente pela VNet.

## 4. Descobrir e exportar em modo interativo

Ainda na pasta desta demo, crie uma pasta **nova e vazia** e execute a ferramenta:

```bash
mkdir "$DEMO8_OUTPUT" &&
MSYS_NO_PATHCONV=1 aztfexport resource-group \
  --subscription-id "$ARM_SUBSCRIPTION_ID" \
  --provider-name azurerm \
  --provider-version 4.81.0 \
  --output-dir "$DEMO8_OUTPUT" \
  "$DEMO8_RG"
```

O `&&` impede a exportação se a pasta já existir. **Não use `--overwrite` nem `--append`**: preserve qualquer exportação/state de um ensaio anterior. `MSYS_NO_PATHCONV=1` evita conversão indevida de IDs Azure pelo Git Bash.

Fixamos o provider AzureRM em **4.81.0**, versão 4.x também usada no ensaio da Demo 7, em vez de depender do padrão da versão instalada do exportador. Preserve o lock file gerado para repetir o ensaio.

Na interface:

1. Percorra a lista e confira os IDs do **RG, VNet e subnet desta demo**.
2. Confira os tipos `azurerm_resource_group`, `azurerm_virtual_network` e `azurerm_subnet`. Os nomes Terraform podem ser genéricos, como `res-0`; isso é esperado.
3. Se houver recurso inesperado, tipo não resolvido ou erro, **pare e investigue**. A tecla `r` mostra recomendações; `e` mostra erros.
4. Pressione **`w`** para exportar e aguarde a conclusão. Saia com **`q`** se a interface permanecer aberta.

**Fala:** “Na demo anterior, eu escrevi o código e importei os IDs. Agora a ferramenta descobre os recursos, faz o import e gera uma configuração que representa o que existe.”

O processo lê o Azure e grava arquivos locais; **não executa apply nem recria a infraestrutura**. Pode levar alguns minutos. Não selecionamos `--hcl-only`, pois queremos demonstrar **HCL + state**.

### Alternativa não interativa

Use **em vez do bloco anterior**, não depois dele, com uma pasta nova e vazia:

```bash
mkdir "$DEMO8_OUTPUT" &&
MSYS_NO_PATHCONV=1 aztfexport resource-group \
  --non-interactive \
  --subscription-id "$ARM_SUBSCRIPTION_ID" \
  --provider-name azurerm \
  --provider-version 4.81.0 \
  --output-dir "$DEMO8_OUTPUT" \
  "$DEMO8_RG"
```

Não usamos `--continue`: falhas de importação precisam ficar visíveis, não virar uma exportação aparentemente completa.

## 5. Ler os arquivos e conferir o plan

Abra a pasta de exportação no Explorer do VS Code. Os nomes exatos dos arquivos podem variar conforme a versão da ferramenta; procure:

- **Configuração de providers:** AzureRM 4.x e `features {}`; a autenticação usa a sessão da CLI e `ARM_SUBSCRIPTION_ID`.
- **Blocos `resource`:** nomes reais, região, tags, address space da VNet e prefixo da subnet.
- **`aztfexportResourceMapping.json`:** relação entre IDs Azure e endereços Terraform.
- **`terraform.tfstate`:** inventário local dos recursos importados; não é código para versionar.

Não coloque um `subscription_id` real no provider caso alguma versão da ferramenta o gere; use a variável de ambiente. Confira também que a subnet não ficou gerenciada simultaneamente como bloco inline na VNet e como `azurerm_subnet`.

```bash
terraform -chdir="$DEMO8_OUTPUT" fmt -check -recursive
terraform -chdir="$DEMO8_OUTPUT" init -backend=false -input=false
terraform -chdir="$DEMO8_OUTPUT" validate
terraform -chdir="$DEMO8_OUTPUT" state list
terraform -chdir="$DEMO8_OUTPUT" plan
```

**Resultado esperado:** RG, VNet e subnet representados no state, e **`No changes`** no plan. Não há `random_string`: o sufixo já existia nos nomes criados pela CLI.

Se houver diferenças de formatação, execute `terraform -chdir="$DEMO8_OUTPUT" fmt -recursive` e repita a verificação. Se o plan propuser criação, alteração, substituição ou exclusão, **não execute apply**. Confira recursos ignorados, erros de exportação, versão do provider, propriedades preenchidas pela API e Policies. Exportar não garante automaticamente um plan sem diferenças.

Não é necessário evoluir nem editar o código ao vivo: esta demo termina na descoberta, geração e conferência.

## 6. O que o exportador não resolve

- Código gerado descreve o observado; não revela a intenção original nem garante reprodução completa da infraestrutura.
- Nomes genéricos, valores literais e propriedades opcionais exigem revisão antes de virar variables, locals ou modules.
- Recursos sem suporte, dependências fora do RG e configurações não expostas pelas APIs podem exigir tratamento manual.
- **Não use duas cópias do state para gerenciar os mesmos recursos.** Migrar para um projeto real é outra atividade, com revisão e ownership definidos.
- Configuração, mapping e state podem conter IDs reais e dados sensíveis. As pastas `exportacao-*` estão ignoradas no Git; não as publique nem force sua inclusão.

**Mensagem-chave:** “O exportador acelera o ponto de partida. Revisão do código e leitura do plan continuam sendo responsabilidade nossa.”

## 7. Limpeza

Depois de revisar os três recursos no state e confirmar que todos pertencem ao RG exclusivo desta demo:

```bash
terraform -chdir="$DEMO8_OUTPUT" plan -destroy
terraform -chdir="$DEMO8_OUTPUT" destroy
az group exists --subscription "$ARM_SUBSCRIPTION_ID" --name "$DEMO8_RG"
```

Leia o plan de destruição antes de confirmar. **Esperado ao final: `false`.** Não usamos `-auto-approve`.

Se a criação/exportação falhou parcialmente, ou o RG não foi importado, a limpeza pelo state pode ser incompleta. Confira o nome, a subscription, a tag `demo=demo8` e **todo o conteúdo do RG**, inclusive eventuais recursos adicionados depois:

```bash
az group show --subscription "$ARM_SUBSCRIPTION_ID" --name "$DEMO8_RG" \
  --query '{id:id,tags:tags}' --output json
az resource list --subscription "$ARM_SUBSCRIPTION_ID" \
  --resource-group "$DEMO8_RG" --output table
```

Somente após confirmar que é o RG descartável deste ensaio, exclua-o pela CLI, com confirmação interativa:

```bash
az group delete --subscription "$ARM_SUBSCRIPTION_ID" --name "$DEMO8_RG"
az group exists --subscription "$ARM_SUBSCRIPTION_ID" --name "$DEMO8_RG"
```

Preserve os arquivos locais até confirmar a exclusão. A limpeza geral das Demos 1–6 **não inclui esta demo**.

## Plano B e referências

Ensaie antes e guarde localmente prints da descoberta, dos blocos gerados e do plan sem mudanças. Se a ferramenta falhar ao vivo, mostre essa exportação como **registro de um ensaio**, não como execução atual. Nunca copie seu state para outra pasta para repetir o gerenciamento.

- [Quickstart oficial: exportar recursos e verificar o plan](https://learn.microsoft.com/azure/developer/terraform/azure-export-for-terraform/export-first-resources)
- [Conceitos, modos e limitações](https://learn.microsoft.com/azure/developer/terraform/azure-export-for-terraform/export-terraform-concepts)
- [Instalação e releases do aztfexport](https://github.com/Azure/aztfexport)
