# Demos: Terraform no Azure — laboratório RG/VNet

Roteiro vigente: [v4](../Apresentação/v4/apresentacao-v4.md). **Seis demos ao vivo (1–6)**, sem Storage Account, Private Endpoint, Shared Key ou serviços que exijam conectividade com endpoints de dados.

VNets são redes privadas, mas o laboratório só cria/consulta sua configuração pelas APIs de gerenciamento. Não conecta VMs nem serviços nelas. Continua sendo necessário acesso às APIs do Azure, RBAC de gerenciamento e aprovação das Policies para RGs/VNets.

## Terminal

**Git Bash no VS Code**, em todas as etapas. Use caminhos `/`, `export`/`unset` e `bash script.sh`. Para chamadas Azure CLI com IDs `/subscriptions/...`, use `MSYS_NO_PATHCONV=1` para evitar conversão de caminhos do Git Bash. Os scripts já tratam isso.

```bash
az login
az account set --subscription "<sub-id>"
export ARM_SUBSCRIPTION_ID="$(
  az account show --query id -o tsv | tr -d '\r'
)"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p "$TF_PLUGIN_CACHE_DIR"
az account show -o table
terraform version
```

Requisitos: Terraform ≥ 1.9, Azure CLI, Git for Windows/VS Code com extensão Terraform, e permissão **Contributor** para os recursos do laboratório. Não há role de dados de Storage nem atribuições RBAC criadas nas demos. OIDC/pipeline permanecem conceituais nos slides, sem projeto de apoio.

## Mapa das demos

| Demo | Pasta | Slide | Objetivo | Duração |
|---|---|---|---|---|
| 1 | [demo1-rg-vnet](demo1-rg-vnet/README.md) | 36 | Um main.tf ao vivo; RG/VNet, tags, substituição e destroy | 16' |
| 2 | [demo2-variables](demo2-variables/README.md) | 45 | Variables, locals, outputs e data source | 12' |
| 3 | [demo3-remote-state](demo3-remote-state/README.md) | 55 | **Dev/prd com states locais separados**, mesmo código | 12' |
| 4 | [demo4-drift](demo4-drift/README.md) | 59 | Drift: owner + centro_custo; aceitar Portal no state com refresh-only | 11' |
| 5 | [demo5-modules](demo5-modules/README.md) | 69 | Módulos RG/VNet; módulo subnet chamado duas vezes | 10,5' |
| 6 | [demo6-for-each](demo6-for-each/README.md) | 76 | Mesmo cenário da Demo 5; duas subnets via map + for_each | 6' |

A pasta `demo3-remote-state` mantém o nome histórico, mas sua execução atual é **local**.

## Cada demo é independente

```text
Demo 1: cria random + RG + VNet; state em demo1-rg-vnet/
Demo 2: cria random + RG + VNet; state em demo2-variables/
Demo 3: mesmo código para dev/prd; states em demo3-remote-state/states/dev/ e states/prd/
Demo 4: prepara sua base; drift de tags; state em demo4-drift/
Demo 5: cria random + RG + VNet + duas subnets via módulos; state em demo5-modules/
Demo 6: mesmo código de módulos da Demo 5; duas subnets via for_each; state em demo6-for-each/
```

Nenhuma demo lê o state de outra. Nas Demos 1/2/4/5/6, ele fica na pasta executada. A Demo 6 referencia as pastas dos módulos da Demo 5 para reutilizar código, mas não depende dos recursos criados por ela. A Demo 3 seleciona `states/dev/terraform.tfstate` ou `states/prd/terraform.tfstate` com `init -backend-config`; o `.tfvars` não seleciona o state. Não execute ambientes da mesma demo simultaneamente no mesmo diretório.

Todos os nomes de recursos Azure terminam em **`-demo<N>-<rand>`**, com 4 caracteres minúsculos/numéricos. Um único `random_string.suffix` é compartilhado pelos recursos daquela execução. Exemplo: `rg-workshop-dev-demo4-a7k2` e `vnet-workshop-dev-demo4-a7k2`. Na Demo 3, dev/prd são ambientes isolados e cada um mantém seu próprio valor. O random persiste no state, não muda a cada plan, e é recriado após destroy. Ele não é um serviço Azure: o plan inicial das Demos 1–4 tem **3 to add** por ambiente; as Demos 5/6 têm **5 to add**, incluindo random + RG + VNet + duas subnets.

O fim de cada demo inclui limpeza própria; não é preciso manter recursos para a seguinte. A Demo 3 prepara dev antes do bloco ao vivo e cria prd na demonstração; a Demo 4 cria sua base no início ou na preparação técnica. A Demo 5 só precisa de init antecipado: plan/apply criam todo o cenário ao vivo. Os tempos de exposição não incluem essa preparação, a espera dos applies nem a limpeza; ensaie antes de prometer a duração.

Backend Azure Storage, proteção de blobs e leases permanecem **conceitos nos slides**, não infraestrutura provisionada neste laboratório.

## Preparação

- D-5: ensaio cronometrado das Demos 1–6, depois cleanup. Confirme contagens dos plans, coexistência de dev/prd na Demo 3 e retorno ao state de dev com **No changes**.
- D-3: gravação/prints de cada demo como Plano B.
- D-1: verifique RBAC, região permitida e Policies para RGs/VNets. Não ajuste Policies para contornar bloqueios.
- D-0: autentique no Git Bash, configure subscription/cache. Demo 1 começa sem `.tf` após reinício seguro. Init antecipado, na raiz:

```bash
(
  set -euo pipefail
  pastas=(
    demo2-variables demo4-drift demo5-modules demo6-for-each
  )
  for p in "${pastas[@]}"; do
    terraform -chdir="demos/$p" init -reconfigure -input=false
  done
  # Demo 3: somente providers aqui; o README orienta migração/seleção de cada state.
  terraform -chdir=demos/demo3-remote-state init -backend=false -input=false
)
```

Se houver states de **ensaios anteriores ao isolamento/sufixo**, com ou sem Storage, pare e siga a [orientação de recuperação](setup/README.md). O novo código pode planejar substituições e os backends antigos podem apontar para outra demo. Não copie, migre, apague ou sobrescreva esses states automaticamente. O novo fluxo não precisa de state remoto.

Se a Demo 3 tiver um `terraform.tfstate` na raiz com recursos, preserve-o e revise a recuperação antes de selecionar outro backend. A limpeza bloqueia esse inventário enquanto ele contiver recursos; veja os [cuidados da Demo 3](demo3-remote-state/README.md#cuidados).

## Limpeza e validação

```bash
bash demos/setup/cleanup.sh
terraform fmt -check -recursive demos
```

Para reiniciar somente a Demo 3, use `bash demos/setup/cleanup.sh --demo3`: destrói dev/prd e, após confirmar states sem recursos, remove os artefatos locais padrão do ensaio/cache. Nas demais demos, a limpeza preserva states vazios e backups.

Para validar uma pasta sem criar recursos:

```bash
terraform -chdir=demos/demo2-variables init -backend=false -input=false
terraform -chdir=demos/demo2-variables validate
```

Repita nas demais configurações. Não versione `.terraform`, state, backups ou plans. Em projetos reais, versione o lock file; aqui a exceção didática do ignore permanece para mostrar sua geração na Demo 1.

As versões anteriores da apresentação foram preservadas como histórico e não descrevem o novo laboratório. A pasta [demo1-rg-storage](demo1-rg-storage/README.md) é exclusivamente recuperação da tentativa antiga, não uma demo.
