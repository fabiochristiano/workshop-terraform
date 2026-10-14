#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
demos_root=$(dirname -- "$script_dir")
demo3_only=0
if (($#)); then
  if [[ $# == 1 && $1 == --help ]]; then
    echo "Uso: bash cleanup.sh [--demo3] (destrói os recursos; --demo3 limita a limpeza e o reinício à Demo 3)"
    exit 0
  elif [[ $# == 1 && $1 == --demo3 ]]; then
    demo3_only=1
  else
    echo "Argumento não suportado: $1." >&2
    exit 1
  fi
fi

has_resources() {
  local file=$1 addresses address found=1 has_suffix=0 has_azure=0
  [[ -f $file ]] || return 1
  if ! addresses=$(terraform -chdir="$script_dir" state list -state="$file"); then
    echo "Falha ao ler $file; limpeza interrompida e state preservado." >&2
    exit 1
  fi
  while IFS= read -r address; do
    address=${address//$'\r'/}
    if [[ $address =~ (^|\.)azurerm_storage_ ]]; then
      echo "Storage legado em $file: $address. Limpeza interrompida; siga a recuperação manual." >&2
      exit 1
    fi
    [[ $address != random_string.suffix ]] || has_suffix=1
    if [[ -n $address && ! $address =~ (^|\.)data\. ]]; then
      if [[ $file == "$demos_root/demo5-modules/terraform.tfstate" ]]; then
        case "$address" in
          random_string.suffix|module.resource_group.azurerm_resource_group.this|module.vnet.azurerm_virtual_network.this|module.subnet_app.azurerm_subnet.this|module.subnet_data.azurerm_subnet.this) ;;
          *) echo "State das etapas antigas da Demo 5 em $file. Preserve-o e revise a recuperação antes da limpeza." >&2; exit 1 ;;
        esac
      fi
      found=0
      if [[ $address =~ (^|\.)(azurerm_|azapi_) ]]; then
        has_azure=1
      fi
    fi
  done <<< "$addresses"
  if ((has_azure && !has_suffix)); then
    echo "State anterior ao isolamento detectado em $file. Revise a recuperação antes de executar o novo código." >&2
    exit 1
  fi
  return "$found"
}

states=(
  "$demos_root/demo1-rg-vnet/terraform.tfstate"
  "$demos_root/demo2-variables/terraform.tfstate"
  "$demos_root/demo3-remote-state/states/dev/terraform.tfstate"
  "$demos_root/demo3-remote-state/states/prd/terraform.tfstate"
  "$demos_root/demo4-drift/terraform.tfstate"
  "$demos_root/demo5-modules/terraform.tfstate"
  "$demos_root/demo6-for-each/terraform.tfstate"
)
dirs=(
  "$demos_root/demo1-rg-vnet"
  "$demos_root/demo2-variables"
  "$demos_root/demo3-remote-state"
  "$demos_root/demo3-remote-state"
  "$demos_root/demo4-drift"
  "$demos_root/demo5-modules"
  "$demos_root/demo6-for-each"
)
var_files=("" dev.tfvars dev.tfvars prd.tfvars dev.tfvars dev.tfvars dev.tfvars)
backend_files=("" "" backend-dev.hcl backend-prd.hcl "" "" "")
labels=("Demo 1" "Demo 2" "Demo 3 dev" "Demo 3 prd" "Demo 4" "Demo 5" "Demo 6")
indices=("${!states[@]}")
if ((demo3_only)); then
  indices=(2 3)
fi

demo3_dir="$demos_root/demo3-remote-state"
for dir in "$demo3_dir" "$demo3_dir/.terraform" "$demo3_dir/states" "$demo3_dir/states/dev" "$demo3_dir/states/prd"; do
  if [[ -L $dir ]]; then
    echo "Uma pasta da Demo 3 é um link simbólico. Reinício automático bloqueado; revise o destino." >&2
    exit 1
  fi
done

if has_resources "$demo3_dir/terraform.tfstate"; then
  echo "A Demo 3 ainda tem recursos no state antigo da raiz. Preserve o arquivo e revise a recuperação antes de reiniciar." >&2
  exit 1
fi

for file in "$demo3_dir/terraform.tfstate" "${states[2]}" "${states[3]}"; do
  if [[ -f ${file%/*}/.terraform.tfstate.lock.info ]]; then
    echo "Há um lock na Demo 3. Finalize a operação antes da limpeza; arquivos preservados." >&2
    exit 1
  fi
done

for i in "${indices[@]}"; do
  if has_resources "${states[$i]}"; then
    if [[ ! -f ${dirs[$i]}/main.tf ]]; then
      echo "${labels[$i]} tem recursos no state, mas main.tf está ausente. Restaure o código antes da limpeza." >&2
      exit 1
    fi
    if [[ -n ${backend_files[$i]} && ! -f ${dirs[$i]}/${backend_files[$i]} ]]; then
      echo "${labels[$i]} tem recursos, mas a configuração do backend está ausente. Limpeza interrompida." >&2
      exit 1
    fi
  fi
done

for i in "${indices[@]}"; do
  echo "${labels[$i]}: state próprio"
  if has_resources "${states[$i]}"; then
    init_args=(-reconfigure -input=false)
    if [[ -n ${backend_files[$i]} ]]; then
      init_args+=("-backend-config=${backend_files[$i]}")
    fi
    terraform -chdir="${dirs[$i]}" init "${init_args[@]}"
    args=(-auto-approve -input=false)
    if [[ -n ${var_files[$i]} ]]; then
      args+=("-var-file=${var_files[$i]}")
    fi
    terraform -chdir="${dirs[$i]}" destroy "${args[@]}"
    if has_resources "${states[$i]}"; then
      echo "Ainda há recursos em ${states[$i]}; limpeza interrompida." >&2
      exit 1
    fi
  else
    echo "Sem recursos gerenciados."
  fi
done

for file in "$demo3_dir/terraform.tfstate" "${states[2]}" "${states[3]}"; do
  if has_resources "$file"; then
    echo "Ainda há recursos na Demo 3; reinício interrompido e arquivos preservados." >&2
    exit 1
  fi
  if [[ -f ${file%/*}/.terraform.tfstate.lock.info ]]; then
    echo "Há uma operação na Demo 3; reinício interrompido e arquivos preservados." >&2
    exit 1
  fi
done

rm -f -- \
  "$demo3_dir/terraform.tfstate" \
  "$demo3_dir/terraform.tfstate.backup" \
  "$demo3_dir/terraform.tfstate.before-envs.bak" \
  "${states[2]}" "${states[2]}.backup" \
  "${states[3]}" "${states[3]}.backup" \
  "$demo3_dir/tfplan" "$demo3_dir/.terraform.lock.hcl"
for dir in "$demo3_dir/states/dev" "$demo3_dir/states/prd" "$demo3_dir/states"; do
  if [[ -d $dir ]]; then
    rmdir -- "$dir"
  fi
done
rm -rf -- "$demo3_dir/.terraform"
echo "Demo 3 reiniciada: states vazios, backups do ensaio, pasta states, plan, lock file e cache removidos; código e configurações preservados."

if ((!demo3_only)); then
  echo "Nas outras demos, states vazios e backups foram preservados; não são enviados ao Git."
  echo "A tentativa antiga em demo1-rg-storage não foi alterada; veja o README de recuperação."
  echo 'Confira no Portal ou com: az group list --query "[?starts_with(name, '\''rg-workshop'\'')].name" -o tsv'
fi
