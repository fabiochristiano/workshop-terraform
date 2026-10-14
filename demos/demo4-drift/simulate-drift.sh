#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
resource_group=""
vnet_name=""
while (($#)); do
  case "$1" in
    --resource-group|--vnet-name)
      if (($# < 2)) || [[ -z $2 || $2 == --* ]]; then
        echo "Falta o valor de $1." >&2
        exit 1
      fi
      case "$1" in
        --resource-group) resource_group=$2 ;;
        --vnet-name) vnet_name=$2 ;;
      esac
      shift 2
      ;;
    --help)
      echo "Uso: bash simulate-drift.sh [--resource-group RG] [--vnet-name NOME]"
      exit 0
      ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 1 ;;
  esac
done

if [[ -z $resource_group ]]; then
  resource_group=$(terraform -chdir="$script_dir" output -raw resource_group_name | tr -d '\r')
fi
if [[ -z $vnet_name ]]; then
  vnet_name=$(terraform -chdir="$script_dir" output -raw vnet_name | tr -d '\r')
fi
if [[ -z $resource_group || -z $vnet_name ]]; then
  echo "Outputs ausentes; aplique primeiro a preparação da Demo 4. Nenhuma tag foi alterada." >&2
  exit 1
fi

id=$(MSYS_NO_PATHCONV=1 az network vnet show -g "$resource_group" -n "$vnet_name" --query id -o tsv | tr -d '\r')
if [[ -z $id ]]; then
  echo "Não foi possível obter o ID da VNet; nenhuma tag foi alterada." >&2
  exit 1
fi
echo "VNet alvo: $vnet_name ($resource_group)"
MSYS_NO_PATHCONV=1 az tag update --resource-id "$id" --operation Merge \
  --tags owner=time-engenharia centro_custo=1234 --output none
echo "Drift criado: owner alterado e centro_custo incluído; managed_by preservado."
echo 'Rode: terraform plan -var-file=dev.tfvars'
