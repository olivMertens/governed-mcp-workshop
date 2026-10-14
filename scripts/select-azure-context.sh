#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf '%s\n' 'Run in your current bash terminal: source ./scripts/select-azure-context.sh [en|fr]' >&2
  exit 1
fi

_workshop_select_azure_context() {
  local language="${1:-en}" name cloud tenant subscription confirmation actual
  [[ "$language" == en || "$language" == fr ]] || { printf '%s\n' 'Language must be en or fr.' >&2; return 1; }
  command -v az >/dev/null || { printf '%s\n' 'Azure CLI is required.' >&2; return 1; }
  for name in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_CLIENT_CERTIFICATE_PATH ARM_CLIENT_CERTIFICATE \
    ARM_CLIENT_CERTIFICATE_PASSWORD ARM_USE_MSI ARM_USE_OIDC ARM_OIDC_TOKEN ARM_ACCESS_KEY \
    AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_CLIENT_CERTIFICATE_PATH ARM_ENVIRONMENT \
    ARM_USE_CLI ARM_USE_AKS_WORKLOAD_IDENTITY ARM_OIDC_TOKEN_FILE_PATH ARM_OIDC_REQUEST_TOKEN \
    ARM_OIDC_REQUEST_URL AZURE_FEDERATED_TOKEN_FILE AZURE_AUTHORITY_HOST ARM_MSI_ENDPOINT \
    ARM_CLIENT_ID_FILE_PATH ARM_TENANT_ID_FILE_PATH ARM_SUBSCRIPTION_ID_FILE_PATH; do
    if [[ -n "${!name:-}" ]]; then
      printf '%s\n' 'An authentication override is present. Use a separate approved interactive-user terminal; do not combine credential flows.' >&2
      return 1
    fi
  done
  cloud="$(az cloud show --query name --output tsv)" || return 1
  [[ "$cloud" == AzureCloud ]] || { printf '%s\n' 'This workshop targets Azure public cloud. Stop here.' >&2; return 1; }
  if [[ "$language" == fr ]]; then
    read -r -p 'ID du tenant Entra de test approuvé (terminal uniquement) : ' tenant || return 1
    read -r -p 'ID de votre abonnement Azure de test approuvé : ' subscription || return 1
    read -r -p 'Tapez NONPROD pour confirmer le périmètre de test et la connexion interactive : ' confirmation || return 1
  else
    read -r -p 'Approved non-production Entra tenant ID (terminal only): ' tenant || return 1
    read -r -p 'Your approved non-production Azure subscription ID: ' subscription || return 1
    read -r -p 'Type NONPROD to confirm the approved test scope and interactive sign-in: ' confirmation || return 1
  fi
  local id_pattern='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  if [[ ! "$tenant" =~ $id_pattern || ! "$subscription" =~ $id_pattern ||
    -z "${tenant//[0-]/}" || -z "${subscription//[0-]/}" ]]; then
    printf '%s\n' 'Enter valid approved tenant/subscription IDs; never paste them into the board.' >&2
    return 1
  fi
  [[ "$confirmation" == NONPROD ]] || { printf '%s\n' 'Selection cancelled. No sign-in or deployment was started.' >&2; return 1; }
  az login --tenant "$tenant" --output none || { printf '%s\n' 'Azure sign-in failed. Stop here.' >&2; return 1; }
  az account set --subscription "$subscription" || { printf '%s\n' 'Subscription selection failed. Stop here.' >&2; return 1; }
  actual="$(az account show --query "join('|', [id, tenantId, state])" --output tsv)" ||
    { printf '%s\n' 'Could not verify Azure context. Stop here.' >&2; return 1; }
  if [[ "${actual,,}" != "${subscription,,}|${tenant,,}|enabled" ]]; then
    printf '%s\n' 'The active tenant/subscription does not match the approved target, or the subscription is not enabled. Stop here.' >&2
    return 1
  fi
  export ARM_TENANT_ID="$tenant" ARM_SUBSCRIPTION_ID="$subscription"
  if [[ "$language" == fr ]]; then
    printf '%s\n' 'PASS contexte : tenant et abonnement vérifiés. Variables ARM dans ce processus uniquement. Aucune ressource créée ; le module 00 reste à valider.'
  else
    printf '%s\n' 'PASS context: tenant and subscription verified. ARM variables set in this process only. No resources created; module 00 still needs validation.'
  fi
}

_workshop_select_azure_context "$@"
