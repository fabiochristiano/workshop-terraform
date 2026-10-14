# Apoio: limpeza dos labs RG/VNet

O laboratório não cria Azure Storage, Private Endpoint ou outro serviço com endpoint de dados. **Não é necessário provisionar um backend remoto.**

Use Git Bash no VS Code, Azure CLI e Terraform disponíveis no PATH. Selecione a subscription, exporte `ARM_SUBSCRIPTION_ID` e confira permissões de gerenciamento/Policies para RGs e VNets.

## Limpeza

A partir da raiz:

```bash
az account show -o table
bash demos/setup/cleanup.sh
```

O script usa `-auto-approve`: **revise a subscription e os states antes de executar**.

Para limpar e reiniciar **somente a Demo 3**, sem destruir outras demos:

```bash
bash demos/setup/cleanup.sh --demo3
```

- Demos 1/2/4: destroy na pasta da própria demo, usando exclusivamente seu state.
- Demo 3: dois destroys na mesma pasta, selecionando `backend-dev.hcl` + `dev.tfvars` e `backend-prd.hcl` + `prd.tfvars`; states em `states/dev/` e `states/prd/`.
- Demo 5: destroy na raiz `demo5-modules`, com state próprio; RG, VNet, duas subnets e random (5 recursos).
- Demo 6: destroy na raiz `demo6-for-each`, com state próprio; RG, VNet, duas subnets por for_each e random (5 recursos).
- Se init/destroy/leitura do state falhar, a limpeza para e preserva os arquivos.
- Antes de qualquer destroy, verifica os sete states locais do fluxo atual. Storage legado, state das etapas antigas da Demo 5, recursos Azure sem o novo `random_string.suffix` ou configuração de backend da Demo 3 ausente interrompem a limpeza. O random agora faz parte de todas as demos e não indica, sozinho, um Storage.
- Se `demo3-remote-state/terraform.tfstate` na raiz ainda contém recursos, interrompe antes de qualquer destroy: preserve o inventário e revise a recuperação antes de reiniciar. Veja os [cuidados da Demo 3](../demo3-remote-state/README.md#cuidados).
- Demo 3: depois de confirmar que os states antigo/dev/prd não têm recursos, remove seus states vazios e backups padrão, o backup `terraform.tfstate.before-envs.bak`, `tfplan`, `.terraform.lock.hcl`, `.terraform` e os diretórios vazios `states/dev`, `states/prd` e `states`. Arquivos inesperados nesses diretórios, lock ativo ou link simbólico na pasta/cache bloqueiam o reinício. O código e os arquivos de configuração permanecem. O [README da Demo 3](../demo3-remote-state/README.md#limpeza-e-reinício) também traz os comandos diretos para copiar e colar.
- Outras demos: states vazios, backups e código permanecem; siga o README da Demo 1 para reinício sem `.tf`.

Não há `--include-state`: não existe RG de backend a remover neste fluxo. O script antigo de criação do storage foi retirado.

## Tentativas antigas

Nenhum state existente foi apagado durante a migração. O cleanup **não tenta acessar ou destruir storages de ensaios antigos**, nem migra states remotos para locais.

- Tentativa da Demo 1 com Storage: siga [`../demo1-rg-storage/README.md`](../demo1-rg-storage/README.md).
- Se você já aplicou qualquer demo anterior ao isolamento/sufixo, **não execute o novo código contra seu state antigo**, mesmo que contenha apenas RG/VNet. Preserve state, backups e código daquela execução; revise a limpeza autorizada com a configuração anterior ou com o administrador. Só comece o novo laboratório depois de confirmar que não está abandonando recursos gerenciados pelo state antigo.
- Backends antigos das Demos 3–5 podem apontar para a Demo 2. Não copie ou migre esse state para várias demos: isso faria mais de uma configuração gerenciar os mesmos recursos. Metadados de backend antigos exigem investigação, não `init -migrate-state` automático.
