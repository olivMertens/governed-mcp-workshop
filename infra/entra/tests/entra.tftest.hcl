# Mock-only plans: no tenant is contacted and no Microsoft Entra object is created.
mock_provider "azuread" {
  override_during = plan

  mock_data "azuread_client_config" {
    defaults = {
      object_id = "99999999-9999-4999-8999-999999999999"
      tenant_id = "00000000-0000-4000-8000-000000000000"
    }
  }
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/33333333-3333-4333-8333-333333333333"
      object_id = "33333333-3333-4333-8333-333333333333"
      client_id = "44444444-4444-4444-8444-444444444444"
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = {
      object_id = "55555555-5555-4555-8555-555555555555"
    }
  }
}

variables {
  tenant_id          = "00000000-0000-4000-8000-000000000000"
  participant_prefix = "p01"
  resource_suffix    = "0123456789abcdef"
  owner              = "alice"
  expiry             = "2099-12-31"
}

run "creates_single_tenant_api_with_scope_roles_and_assignment_required" {
  command = plan

  assert {
    condition = alltrue([
      azuread_application.mcp[0].sign_in_audience == "AzureADMyOrg",
      azuread_application.mcp[0].api[0].requested_access_token_version == 2,
      length(azuread_application.mcp[0].api[0].oauth2_permission_scope) == 1,
      one(azuread_application.mcp[0].api[0].oauth2_permission_scope).value == "user_impersonation",
      one(azuread_application.mcp[0].api[0].oauth2_permission_scope).enabled,
      azuread_application.mcp[0].prevent_duplicate_names,
      strcontains(azuread_application.mcp[0].display_name, "mcp-p01-0123456789abcdef"),
    ])
    error_message = "The MCP API must be single-tenant, issue v2 tokens and expose exactly one delegated scope, user_impersonation."
  }

  assert {
    condition = (
      length(azuread_application.mcp[0].app_role) == 3 &&
      toset([for role in azuread_application.mcp[0].app_role : "${role.value}=${join(",", role.allowed_member_types)}"]) ==
      toset(["Tools.Read=User", "Tools.Write=User", "Tools.Execute.All=Application"])
    )
    error_message = "App roles must be Tools.Read and Tools.Write for users and Tools.Execute.All for applications only."
  }

  assert {
    condition     = azuread_application_identifier_uri.mcp[0].identifier_uri == "api://44444444-4444-4444-8444-444444444444" && output.identifier_uri == "api://44444444-4444-4444-8444-444444444444"
    error_message = "The Application ID URI must be api://<client-id>."
  }

  assert {
    condition     = azuread_service_principal.mcp[0].app_role_assignment_required && azuread_service_principal.mcp[0].client_id == "44444444-4444-4444-8444-444444444444"
    error_message = "Assignment required must be enabled on the enterprise application."
  }

  assert {
    condition = (
      toset(keys(azuread_application_pre_authorized.clients)) == toset(["aebc6443-996d-45c2-90f0-388ff96faa56", "04b07795-8ddb-461a-bbee-02f9e1bf7b46"]) &&
      alltrue([for client in values(azuread_application_pre_authorized.clients) :
        client.permission_ids == toset([uuidv5("url", "https://workshop.invalid/governed-mcp/mcp-p01-0123456789abcdef/scope/user_impersonation")])
      ])
    )
    error_message = "Only Visual Studio Code and Azure CLI are pre-authorized, and only for user_impersonation."
  }

  assert {
    condition     = length(azuread_app_role_assignment.personas) == 0 && output.persona_assignments == {}
    error_message = "Without existing persona IDs, no assignment is planned."
  }

  assert {
    condition = alltrue([
      output.app_role_ids["Tools.Read"] == uuidv5("url", "https://workshop.invalid/governed-mcp/mcp-p01-0123456789abcdef/role/Tools.Read"),
      output.app_role_ids["Tools.Write"] == uuidv5("url", "https://workshop.invalid/governed-mcp/mcp-p01-0123456789abcdef/role/Tools.Write"),
      output.app_role_ids["Tools.Execute.All"] == uuidv5("url", "https://workshop.invalid/governed-mcp/mcp-p01-0123456789abcdef/role/Tools.Execute.All"),
    ])
    error_message = "Role IDs must be deterministic so that reruns never recreate roles."
  }

  assert {
    condition = (
      output.workload_module03_tfvars.enable_entra_auth &&
      !output.workload_module03_tfvars.entra_auth_replace_key_gate &&
      output.workload_module03_tfvars.mcp_api_client_id == "44444444-4444-4444-8444-444444444444" &&
      output.workload_module03_tfvars.mcp_api_identifier_uri == "api://44444444-4444-4444-8444-444444444444" &&
      output.workload_module03_tfvars.entra_tenant_id == var.tenant_id &&
      output.user_impersonation_scope == "api://44444444-4444-4444-8444-444444444444/user_impersonation"
    )
    error_message = "The workload hand-off must carry exactly the tenant, client ID, Application ID URI and allowed clients."
  }

  assert {
    condition = (
      output.module05_federated_credential.parent_application_object_id == "33333333-3333-4333-8333-333333333333" &&
      output.module05_federated_credential.audience == "api://AzureADTokenExchange" &&
      output.module05_federated_credential.issuer == "https://login.microsoftonline.com/00000000-0000-4000-8000-000000000000/v2.0"
    )
    error_message = "Module 05 needs the parent application, issuer and audience reserved, without creating a credential now."
  }
}

run "assigns_alice_read_write_and_bob_read_but_never_eve" {
  command = plan
  variables {
    test_user_object_ids = {
      alice = "a11ce000-0000-4000-8000-000000000001"
      bob   = "b0b00000-0000-4000-8000-000000000002"
      eve   = "e0e00000-0000-4000-8000-000000000003"
    }
  }

  assert {
    condition     = toset(keys(azuread_app_role_assignment.personas)) == toset(["alice-read", "alice-write", "bob-read"])
    error_message = "Alice gets Tools.Read and Tools.Write, Bob gets Tools.Read, nothing else."
  }

  assert {
    condition = alltrue([
      azuread_app_role_assignment.personas["alice-write"].app_role_id == output.app_role_ids["Tools.Write"],
      azuread_app_role_assignment.personas["bob-read"].app_role_id == output.app_role_ids["Tools.Read"],
      azuread_app_role_assignment.personas["bob-read"].principal_object_id == "b0b00000-0000-4000-8000-000000000002",
      !anytrue([for assignment in values(azuread_app_role_assignment.personas) : assignment.principal_object_id == "e0e00000-0000-4000-8000-000000000003"]),
      alltrue([for assignment in values(azuread_app_role_assignment.personas) : assignment.resource_object_id == "55555555-5555-4555-8555-555555555555"]),
      !anytrue([for assignment in values(azuread_app_role_assignment.personas) : assignment.app_role_id == output.app_role_ids["Tools.Execute.All"]]),
    ])
    error_message = "Assignments target the workshop enterprise application; Eve and the application role are never assigned."
  }
}

run "reads_existing_application_without_managing_it" {
  command = plan
  variables {
    create_application             = false
    existing_application_client_id = "66666666-6666-4666-8666-666666666666"
    test_user_object_ids           = { bob = "b0b00000-0000-4000-8000-000000000002" }
  }
  override_data {
    target = data.azuread_application.existing[0]
    values = {
      client_id                   = "66666666-6666-4666-8666-666666666666"
      object_id                   = "77777777-7777-4777-8777-777777777777"
      identifier_uris             = ["api://66666666-6666-4666-8666-666666666666"]
      app_role_ids                = { "Tools.Read" = "10000000-0000-4000-8000-000000000001", "Tools.Write" = "10000000-0000-4000-8000-000000000002", "Tools.Execute.All" = "10000000-0000-4000-8000-000000000003" }
      oauth2_permission_scope_ids = { user_impersonation = "20000000-0000-4000-8000-000000000001" }
    }
  }
  override_data {
    target = data.azuread_service_principal.existing[0]
    values = {
      object_id                    = "88888888-8888-4888-8888-888888888888"
      app_role_assignment_required = true
    }
  }

  assert {
    condition = alltrue([
      length(azuread_application.mcp) == 0,
      length(azuread_service_principal.mcp) == 0,
      length(azuread_application_identifier_uri.mcp) == 0,
      length(azuread_application_pre_authorized.clients) == 0,
      !output.application_managed_by_workshop,
    ])
    error_message = "With an administrator-provided application, this root must not create, change or delete it."
  }

  assert {
    condition = (
      output.identifier_uri == "api://66666666-6666-4666-8666-666666666666" &&
      azuread_app_role_assignment.personas["bob-read"].resource_object_id == "88888888-8888-4888-8888-888888888888" &&
      azuread_app_role_assignment.personas["bob-read"].app_role_id == "10000000-0000-4000-8000-000000000001"
    )
    error_message = "Existing IDs must flow to outputs and assignments unchanged."
  }
}

run "refuses_existing_application_without_assignment_required" {
  command = plan
  variables {
    create_application             = false
    existing_application_client_id = "66666666-6666-4666-8666-666666666666"
  }
  override_data {
    target = data.azuread_application.existing[0]
    values = {
      identifier_uris             = ["api://66666666-6666-4666-8666-666666666666"]
      app_role_ids                = { "Tools.Read" = "10000000-0000-4000-8000-000000000001", "Tools.Write" = "10000000-0000-4000-8000-000000000002", "Tools.Execute.All" = "10000000-0000-4000-8000-000000000003" }
      oauth2_permission_scope_ids = { user_impersonation = "20000000-0000-4000-8000-000000000001" }
    }
  }
  override_data {
    target = data.azuread_service_principal.existing[0]
    values = { app_role_assignment_required = false }
  }
  expect_failures = [output.service_principal_object_id]
}

run "refuses_existing_application_without_workshop_roles" {
  command = plan
  variables {
    create_application             = false
    existing_application_client_id = "66666666-6666-4666-8666-666666666666"
  }
  override_data {
    target = data.azuread_application.existing[0]
    values = {
      identifier_uris             = ["api://66666666-6666-4666-8666-666666666666"]
      app_role_ids                = { "Tools.Read" = "10000000-0000-4000-8000-000000000001" }
      oauth2_permission_scope_ids = { user_impersonation = "20000000-0000-4000-8000-000000000001" }
    }
  }
  override_data {
    target = data.azuread_service_principal.existing[0]
    values = { app_role_assignment_required = true }
  }
  expect_failures = [output.app_role_ids]
}

run "rejects_missing_existing_client_id" {
  command = plan
  variables {
    create_application = false
  }
  expect_failures = [var.create_application]
}

run "rejects_eve_sharing_an_account_with_alice" {
  command = plan
  variables {
    test_user_object_ids = {
      alice = "a11ce000-0000-4000-8000-000000000001"
      eve   = "a11ce000-0000-4000-8000-000000000001"
    }
  }
  expect_failures = [var.test_user_object_ids]
}

run "rejects_malformed_or_excessive_pre_authorized_clients" {
  command = plan
  variables {
    pre_authorized_client_ids = ["*"]
  }
  expect_failures = [var.pre_authorized_client_ids]
}
