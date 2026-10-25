# Cedarbridge — Security, Access & Operational Risk Assessment

**Project:** Cedarbridge internal IT ticketing proof of concept  
**Document type:** Architecture risk assessment and security design decisions  
**Status:** Draft — proposed controls; not evidence of deployed security  
**Scope:** Simulated internal organization (~115 employees), local FastAPI proof of concept and planned Azure architecture  
**Review date:** October 25, 2026

## 1. Purpose and scope

Identify credible security, authorization, operational, and cost risks before introducing real users or deploying the Cedarbridge prototype. The objective is proportional, testable controls for a low-volume internal IT ticketing service—not enterprise-scale infrastructure for its own sake.

### Known implementation baseline

- **Implemented locally:** HTML/FastAPI ticket submission and retrieval; basic input validation, ticket IDs/timestamps and in-memory storage. Data is lost on application restart.
- **Defined and validated in Terraform:** Azure Resource Group, Container Apps Environment, sample-image Container App, Log Analytics workspace, Azure SQL logical server, and free-offer database configuration. SQL-only Terraform *plan* has been generated; this is **not** deployment.
- **Current SQL Terraform design:** SQL public network access enabled, SQL administrator configured for bootstrap, minimum TLS 1.2, and requested free-offer exhaustion behavior `AutoPause`. No verified SQL firewall/managed-identity access or SQL diagnostic-settings deployment yet.
- **Planned:** Container image in ACR; GitHub Actions CI/CD and remote Terraform state; Azure-hosted FastAPI; SQL persistence; Entra sign-in; app roles and ticket-level checks; managed-identity SQL access; logs and diagnostics.
- **Not currently implemented:** Production user authentication/authorization, IT assignment/status workflow, attachment handling, centralized audit trail, Azure-hosted integration and a tested recovery plan.

The Target State diagram represents **proposed architecture**, not completed controls.

## 2. Risk rating and priorities

- **P0 — Block real-user access:** Exposure could let users or outsiders access unauthorized tickets, change privileged data, or compromise application/database access.
- **P1 — Address before pilot:** Material operational, compliance, cost, or integrity concern that should be verified before expanding usage.
- **P2 — Future hardening:** Valid enhancement that is not proportionate to the immediate synthetic-data prototype.

## 3. Risk register

| ID | Risk / failure scenario | Priority | Decision and planned control | Acceptance evidence |
|---|---|---|---|---|
| SEC-01 | Public Container App endpoint receives unauthenticated traffic | P0 | Require Entra sign-in through Container Apps built-in authentication or a fully validated application authentication flow; HTTPS only; restrict authorized tenant/users. Add input and request-size limits. | Anonymous request is denied/redirected; an authenticated, authorized user succeeds. |
| SEC-02 | Employee accesses someone else's ticket by changing `/tickets/{id}` (BOLA/IDOR) | P0 | Derive requester identity from trusted authentication claims and enforce record ownership in *every* read/update query; IT role must be checked separately. | Employee A receives 403 or intentionally indistinguishable 404 for Employee B's ticket; IT role behaves as designed. |
| SEC-03 | Employee directly invokes `/admin` or admin API | P0 | Enforce `Tickets.Admin`/`Tickets.User` application authorization in FastAPI for every relevant endpoint; hiding UI elements is insufficient. Validate verified token/identity claims, never trust role fields from request body. | Non-admin receives 403 for every admin API; assigned admin succeeds. |
| SEC-04 | Application connects to Azure SQL with administrator privileges or stored password | P0 | Use a Container App managed identity for Entra authentication to SQL. Provision a dedicated database principal with only necessary table permissions; separate schema migration/admin operations. | Ticket creation works using managed identity; runtime has no SQL admin credential; unauthorized SQL operations are denied. |
| SEC-05 | SQL public endpoint plus permissive firewall permits unexpected connections | P0 | For proof of concept, restrict SQL firewall to required known sources, review `Allow Azure services and resources to access this server`, require TLS and identity-based access. Target production: Private Endpoint/VNet/private DNS and disable public network access. | Unapproved source cannot connect; approved identity/source can; effective firewall is documented. |
| SEC-06 | Ticket text, stack traces, connection strings, passwords or tokens leak into logs or Git | P0 | Minimize ticket PII; provide employee warning not to paste passwords; redact logs; never log bearer tokens or connection strings; ignore secrets/state files; use GitHub environment secrets for unavoidable bootstrap credentials. | Sample log scan and Git history review contain no secrets or full ticket descriptions. |
| APP-01 | Input injection, unsafe HTML rendering or malformed values | P0 | Use parameterized SQL queries, strict request schemas and length limits, and escaped output for ticket descriptions. Do not render untrusted content as HTML. | Injection/XSS-oriented test inputs remain plain text and do not modify database structure or execute code. |
| APP-02 | Ticket status, ownership or priority changes with no trace | P1 | Add `ticket_history` records with actor, timestamp, action, and before/after values; perform update and audit insertion atomically. | Each assignment/status change produces an attributable history entry. |
| APP-03 | Duplicate submissions, partial updates or race conditions | P1 | Database uniqueness constraints; transactional writes for ticket + history; define allowed status transitions; consider idempotency for retries. | Duplicate request ID does not create multiple records; invalid transition fails safely. |
| OPS-01 | Log ingestion grows unexpectedly or captures sensitive content | P1 | Select only useful Container Apps and SQL diagnostic categories, redact content, review ingestion and budget alerts, choose supported retention, use daily cap *as a fallback*. | Inspect actual ingestion and costs; alert and cap behaviour verified, including loss of monitoring when cap is reached. |
| OPS-02 | Container restarts or database auto-pauses, making support slow/unavailable | P1 | Persist tickets in SQL; handle connection errors, timeouts and retries safely; validate health checks; document cold starts, replica minimum and SQL auto-pause tradeoff. | Ticket survives app restart; controlled SQL outage produces a safe error, not false success. |
| CICD-01 | Workflow identity or Terraform state is overly privileged/exposed | P1 | GitHub OIDC federation; restrict `dev` environment and protected branch; remote state in private Azure Blob with RBAC; review plan before apply; avoid broad permanent privileges. | Workflow authenticates without an Azure client secret; unauthorized branch cannot deploy; state access audited. |
| DATA-01 | Lost or unrecoverable ticket data | P1 | Verify Azure SQL backup/restore capability, define restore expectations and test recovery with synthetic data. Don't assume free-tier availability meets a business SLA. | Successful restore exercise or documented verified recovery runbook. |
| DATA-02 | Sensitive ticket details retained indefinitely or accessible broadly | P1 | Collect minimal requester data, control who can view/support cases, decide retention/deletion policy and limit read access to logs/backups. | Data access matrix and retention decision documented; prohibited actor cannot read ticket. |
| PERF-01 | Single FastAPI container overloaded by large uploads or reports | P2 | Keep frontend and API together at current scale; limit payloads, concurrency and DB query duration. If attachments are later required, use private Blob Storage with identity checks and time-limited access; scan files where appropriate. | Load test under expected small workload; oversized request rejected. |
| NET-01 | No WAF or private ingress | P2 | Public authenticated HTTPS is acceptable for POC with strict authorization and network controls. Reassess WAF/private ingress according to real threat model, compliance and cost. A WAF does not replace authorization. | Threat-model review explains why this control is deferred or added. |

## 4. Design decisions

### D-01 — Authentication and authorization

**Decision:** Require Microsoft Entra authentication before serving the internal portal; maintain role- and ticket-level authorization in FastAPI. Define `Tickets.User` and `Tickets.Admin` (subject to tenant permissions). Use verified platform-provided identity or cryptographically validated tokens; validate issuer, audience and token validity when parsing a token directly. Identify the requester by immutable claims such as tenant ID and object ID, not by a user-entered email.

**Reason:** Authentication only says *who* the user is. Authorization decides *which ticket* they may access and *what actions* they may take. A valid employee session must not grant other employees' records.

### D-02 — SQL access and networking

**Decision:** The running Container App will use managed identity / Entra authentication to Azure SQL. Application identity receives narrow database permissions, not `db_owner` or SQL admin rights. Network access during the POC will use restricted SQL firewall settings and TLS. A private endpoint is the target for a production hardening phase after evaluating VNet connectivity, private DNS and cost.

**Reason:** Managed identity removes application-managed database passwords; firewall/private endpoint controls restrict the network route. They solve different security problems.

### D-03 — Application packaging

**Decision:** Keep one FastAPI container serving the HTML frontend and API for the initial low-volume workload.

**Reason:** Reduced operational complexity. Splitting a static frontend and backend is not automatically necessary; resource limits, efficient handlers, sensible query patterns and safe request-size limits are more proportional safeguards today.

### D-04 — Monitoring and cost

**Decision:** Route useful Container Apps console/system logs and selected SQL diagnostics to Log Analytics. Avoid logging ticket bodies or secrets. Configure Azure budget and ingestion monitoring, selective collection and supported retention. Treat daily caps as emergency safeguards, not precise cost limits.

**Reason:** Monitoring needs to be useful without exhausting credits or collecting private ticket information. Daily caps can stop telemetry and can be exceeded slightly.

### D-05 — Deployment

**Decision:** GitHub Actions will use OIDC for Azure deployment, keep Terraform state in a private Azure Blob container, and separate infrastructure plans from application image releases. Deploy tagged Docker images via ACR and Azure Container Apps. Require deliberate review of material Terraform changes.

**Reason:** Automated deployments should remain auditable and avoid embedding long-lived Azure credentials in the repository.

## 5. Access-control matrix — target behaviour

| Operation | Employee | IT administrator | Unauthenticated |
|---|---|---|---|
| Submit own ticket | Allowed | Allowed if authorized by business rules | Denied |
| View own tickets | Allowed | Allowed | Denied |
| View another employee's ticket | Denied | Allowed for support purposes | Denied |
| Change ticket assignment | Denied | Allowed | Denied |
| Change ticket priority/status | Denied | Allowed | Denied |
| View change history | Own authorized tickets only | Authorized ticket queue | Denied |
| Change Azure infrastructure/SQL admin configuration | Denied | Denied through ticketing app | Denied |

Even if the frontend hides an operation, the backend must reject an unauthorized API request for it.

## 6. Minimum security verification plan before any real user pilot

- [ ] Authentication required on the website and API; anonymous calls do not return ticket data.
- [ ] Employee A cannot view or change Employee B's tickets, even with a known valid ticket ID.
- [ ] Ordinary employee cannot call any IT admin API directly.
- [ ] Requester/actor identity is derived from trusted Entra identity, not form fields.
- [ ] SQL application identity has only required permissions; app has no SQL administrator password.
- [ ] SQL firewall restrictions are confirmed from an approved and an unapproved client.
- [ ] SQL queries are parameterized; ticket descriptions are safely escaped on rendering.
- [ ] No credentials, tokens or ticket bodies appear in Git, browser errors or operational logs.
- [ ] Ticket creation persists across container restarts; writes and audit history are consistent.
- [ ] Budget alerts and Log Analytics ingestion are configured and reviewed.
- [ ] Health/error handling, backup/restore expectations and known cold-start behaviour are documented.

**Launch gate:** Do not expose a real organizational ticket portal until P0 items are verified. Synthetic-data demonstrations can proceed in a restricted development environment with limitations disclosed.

## 7. Deferred enhancements — not required for the low-load prototype

- WAF through Azure Front Door or Application Gateway, based on actual threat and budget.
- Azure SQL private endpoints, VNet integration and private DNS; shut off SQL public network access once private connectivity is proven.
- Dedicated Blob Storage workflow for attachments, secure uploads, scanning and lifecycle management.
- Separate static frontend hosting and backend API only if scaling/operational evidence justifies it.
- Automated SLA policies, advanced reporting, ITSM integrations, comprehensive load testing.

## 8. References

- [Azure Container Apps built-in authentication](https://learn.microsoft.com/en-us/azure/container-apps/authentication)
- [Azure SQL network access controls](https://learn.microsoft.com/en-us/azure/azure-sql/database/network-access-controls-overview)
- [Azure SQL Private Link](https://learn.microsoft.com/en-us/azure/azure-sql/database/private-endpoint-overview)
- [Azure SQL Microsoft Entra authentication](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview)
- [Azure SQL user creation and privileges](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure)
- [Azure Container Apps logging](https://learn.microsoft.com/en-us/azure/container-apps/log-options)
- [Log Analytics daily cap considerations](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/daily-cap)
- [OWASP API1:2023 — Broken Object Level Authorization](https://api-security.owasp.org/editions/2023/en/0xa1-broken-object-level-authorization/)
