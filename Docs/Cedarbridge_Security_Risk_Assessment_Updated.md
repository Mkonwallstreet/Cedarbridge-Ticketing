# Cedarbridge — Security & Architecture Risk Assessment

**Project:** Cedarbridge Azure IT Ticketing Platform  
**Assessment basis:** Revised *Current State vs. Target State* architecture diagram  
**Assessment date:** 25 October 2026  
**Stage:** Local proof of concept; Azure cloud deployment and security configuration pending  
**Scope:** Simulated low-volume internal IT support platform. Only synthetic test data should be used at this stage.

> **How to read this document:** A control shown in the **target architecture** is a **design decision**, not evidence that the control has been deployed or tested. A risk is only *verified mitigated* after the control exists and its acceptance test passes. The public endpoint, database, and identity integrations are not yet deployed, based on the project status supplied.

## 1. Executive assessment

The revised design resolves several **architectural ambiguities**: users are intended to pass through Azure Container Apps built-in authentication (**Easy Auth**) backed by Microsoft Entra ID; FastAPI handles application-specific permissions; the Container App uses **managed identity** for Azure SQL and Azure Container Registry (ACR); SQL persists tickets independently of app restarts; and Container Apps and Azure SQL have separate diagnostic feeds to Log Analytics.

**These are design improvements, not completed security controls.** The most important remaining *launch blockers* are (1) restricting sign-in to approved users, (2) preventing employees from accessing other employees' tickets or administrative endpoints, (3) avoiding SQL administrator privileges in the running application, and (4) confirming secure database network access and safe data handling.

**Priorities:** `P0` = must pass before an actual-user pilot; `P1` = important for dependable operation and early hardening; `P2` = accepted/deferred low-load design tradeoff.

## 2. What changed with the latest architecture diagram?

| Area | Earlier ambiguity or gap | Target design now selected | What remains to implement or prove |
| --- | --- | --- | --- |
| Application entrance | HTTPS arrow did not indicate a pre-app authentication gate | **Easy Auth** sits at the Container App entry, using **Microsoft Entra ID** | Enable **Require authentication**; test anonymous rejection and sign-in redirect |
| Who may enter | Any tenant user might potentially authenticate | **Single-tenant** app and **assignment required** for approved employees/admins | Configure Enterprise Application assignment; test an unassigned *same-tenant* account and an outside account |
| Employee vs. IT admin | Diagram implied roles without specifying enforcement | Application roles and FastAPI authorization are the intended split | Validate trusted identity/role claims and protect each API; test forbidden admin calls and cross-user ticket reads |
| Azure SQL access | Password-based SQL application login was possible | Container App **managed identity + Entra SQL authentication + TLS** | Create SQL database principal and least-privilege grants; remove SQL admin password from runtime |
| Registry access | Image pull mechanism was not explicit | Container App uses **managed identity** to pull from ACR | Assign appropriate registry pull permissions and test image deployment |
| Diagnostics | Log Analytics looked like a downstream step of SQL | Container Apps logs and Azure SQL diagnostics feed **separately** into Log Analytics | Configure and verify both destinations; select diagnostic categories and control ingestion |
| App packaging | Single frontend/backend container treated as an inherent weakness | One lightweight FastAPI container is an **intentional simplification** | Put sensible request, memory, health and database timeouts in place |

### Important residual distinctions

- **Easy Auth is not a WAF or private networking.** It can reject unauthenticated requests before FastAPI, but a public HTTPS endpoint still exists.
- **Entra authentication is not ticket authorization.** FastAPI must still check record ownership and administrative privileges.
- **Managed identity is not a SQL firewall rule.** Identity, permission grants, TLS and network reachability are separate controls.
- **Logging shown on a diagram does not enable SQL diagnostic settings.** Each log path requires an actual configuration and verification.

## 3. Updated risk register

**Assessment status legend:** **Target control selected** = design addresses the gap but is not deployed; **Open** = material remaining risk; **Accepted for POC** = proportionate tradeoff, not a claim of zero risk.

| ID | Risk / failure scenario | Priority | Updated assessment | Required control and acceptance evidence |
| --- | --- | --- | --- | --- |
| **SEC-01** | Anonymous or unauthorized user reaches FastAPI | **P0** | **Target control selected** — Easy Auth now explicitly protects the Container App's entry | Require auth via Entra; HTTPS only; deny/redirect anonymous website and API calls. Confirm no ticket data reaches anonymous users. |
| **SEC-07** | A valid account from the same tenant signs in without Cedarbridge approval | **P0** | **Open** — Easy Auth alone does not enforce an employee allowlist | Single-tenant registration; **Enterprise Application: Assignment required = Yes**; assign approved test users/groups. Test an unassigned tenant account and external account. |
| **SEC-02** | Employee changes `/tickets/{id}` to view another user's ticket (**BOLA/IDOR**) | **P0** | **Open** — diagram identifies record-level authorization but does not implement it | Derive requester from verified tenant/object identity, not form input; enforce ticket ownership in queries. Test A cannot read B's ticket. |
| **SEC-03** | Employee invokes administrator API or changes ticket roles/statuses | **P0** | **Open** — target includes employee/admin roles | Define `Tickets.User` and `Tickets.Admin`; authorize **every protected FastAPI endpoint**; test ordinary employee gets 403 for admin operations. |
| **SEC-08** | Application trusts a spoofed or misread identity/role header | **P0** | **Open** — platform-provided claims need careful integration | Use documented Easy Auth principal headers **only behind the platform auth boundary**, validate required claims/roles and fail closed. Do not trust client-submitted identity or role fields; test invalid/missing claims. |
| **SEC-04** | App runs with SQL administrator password or excessive SQL rights | **P0** | **Target control selected** — managed identity to SQL | Create an Entra database user for the app identity with only necessary read/write privileges; separate schema deployment/admin operations; verify denied privileged commands and absence of runtime SQL admin secret. |
| **SEC-05** | SQL public endpoint/firewall admits unexpected connections | **P0** | **Open** — diagram does not enforce network access | Restrict SQL firewall to demonstrably required sources; review *Allow Azure services...* setting; TLS and Entra SQL access. Test allowed/disallowed sources. Reassess **Private Endpoint** for production. |
| **SEC-06** | Credentials, ticket contents or personal data leak through logs/Git | **P0** | **Open** — centralized logs increase visibility *and* privacy exposure | Don't log ticket bodies, tokens or connection strings; secrets outside code; safe user-facing errors; check Git history and log samples. |
| **APP-01** | SQL injection, script execution in ticket descriptions, malformed input | **P0** | **Open** — risk unaffected by hosting changes | Parameterized SQL, validated schemas/length limits, escaped HTML, request limits. Test XSS/injection samples. |
| **APP-02** | Ticket changes have no attributable audit trail | **P1** | **Open** — planned SQL history not implemented | `ticket_history` with actor, timestamp and change details; transactional ticket + history updates. Verify IT actions have consistent history. |
| **APP-03** | Duplicate submissions, lost updates or invalid status transitions | **P1** | **Open** | Unique keys, transactions, defined status transitions, safe retry/idempotency policy. Verify duplicate/invalid requests do not corrupt state. |
| **OPS-01** | Log ingestion grows unexpectedly or logs contain private information | **P1** | **Partially addressed in design** — both sources now shown correctly | Enable only chosen Container Apps and SQL diagnostics; redact; Azure budgets and ingestion alerts; use daily cap only as emergency safeguard. Verify category routing and cost. |
| **OPS-02** | Container scales to zero or SQL pauses, causing delay or failure | **P1** | **Open** — persistence is planned, not operationally verified | Persist in SQL; set sensible timeouts, bounded retry and health probes; test restart and controlled SQL outage; document cold starts/free-offer auto-pause. |
| **CICD-01** | CI/CD identity is overly privileged; Terraform state or workflow is exposed | **P1** | **Open** — not addressed by application diagram | GitHub OIDC, least-privilege Azure roles, private remote state, protected deployment environment and approved plans. Test unauthorized branch cannot deploy. |
| **DATA-01** | Tickets cannot be restored after loss | **P1** | **Open** | Review actual Azure SQL backup/restore capability for selected offer; document recovery limits and test synthetic-data recovery if supported. |
| **DATA-02** | Excessive retention or broad access to personal support information | **P1** | **Open** | Minimize collected data, decide retention and deletion, restrict logs/backups and ticket access. Demonstrate denied access. |
| **PERF-01** | One container is overwhelmed by unusually large requests or slow queries | **P2** | **Accepted for POC** — single frontend/backend container is proportionate for low load | Limit payload size, concurrency, query duration and memory; no large attachment feature in initial scope. Split services only if testing justifies it. |
| **NET-01** | No WAF or private user ingress | **P2** | **Accepted for restricted POC** — Easy Auth reduces app-layer exposure, not network reachability | Require Easy Auth, authorization and HTTPS; revisit WAF/private ingress against real security, compliance and cost requirements. |

## 4. Design decisions (revised)

### D-01 — Platform sign-in and application authorization

**Decision:** Use **Azure Container Apps Easy Auth** with Microsoft Entra ID for *sign-in before FastAPI*, configured to **Require authentication**. Use a **single-tenant** app registration and **Enterprise Application user assignment required** so access is not granted merely because an account belongs to the tenant. Configure `Tickets.User` and `Tickets.Admin` roles where tenant permissions permit. FastAPI will enforce both **role-level** and **ticket-level** authorization using trusted identity data (ideally immutable tenant + object IDs rather than user-entered email). Platform authentication and FastAPI authorization are different layers.

**Reason:** This minimizes custom login code while preventing unapproved users, ordinary employees and cross-user ticket lookups from obtaining inappropriate access. A public ingress URL remains externally reachable; this is not a substitute for a WAF or private access.

**Implementation dependency:** App registration, enterprise app assignment/consent and sufficient Entra tenant permissions must be checked. For the personal student-subscription prototype, use authorized fictional/test identities only.

### D-02 — SQL authentication and networking

**Decision:** Cedarbridge Container App will use a **system-assigned managed identity** with Microsoft Entra authentication for Azure SQL, with a dedicated, least-privilege SQL database principal. Enforce TLS and restrictive firewall access. Private Endpoints/VNet/private DNS are **deferred production hardening** after validating feasibility and pricing.

**Reason:** Passwordless service identity, database permissions and network restrictions protect different layers. SQL public networking is not resolved just because managed identity appears in the architecture diagram.

### D-03 — Container image and registry permissions

**Decision:** Keep one FastAPI container serving HTML and API. Store versioned Docker images in ACR. Grant the Container App's managed identity only the registry **pull** capability needed to retrieve its image; GitHub's eventual CI/CD identity handles image **push** separately.

**Reason:** ACR stores container images, not running application code; Container Apps runs the image. The split reduces credential sharing and makes deployments repeatable.

### D-04 — Monitoring and cost

**Decision:** Send Container Apps console/system logs to Log Analytics and route **selected Azure SQL resource diagnostics** to the same workspace through SQL diagnostic settings. Configure useful retention, cost visibility and log volume warnings. Avoid ticket bodies and secrets in diagnostic output.

**Reason:** The two sources are independent; SQL does not forward the Container App's logs. Daily caps may reduce visibility when hit and are **not hard spending ceilings**.

### D-05 — Deployment automation

**Decision:** Plan GitHub Actions with OIDC authentication for Azure, private Azure Blob-backed Terraform state and a controlled infrastructure plan/apply process; package/push tagged images to ACR and update the Container App image version. This is a **future CI/CD implementation**, not deployed infrastructure.

**Reason:** The application deployment path and infrastructure provisioning path have different jobs and security permissions.

## 5. Access-control matrix — target behaviour

| Operation | Employee | IT administrator | Unassigned/unauthenticated visitor |
| --- | --- | --- | --- |
| Open Cedarbridge | If approved/assigned | If approved/assigned | **Denied at sign-in** |
| Submit own ticket | Allowed | As permitted by business rules | Denied |
| View own tickets | Allowed | Allowed | Denied |
| View another employee's ticket | Denied | Only for authorized support work | Denied |
| Change ticket assignment | Denied | Allowed | Denied |
| Change priority/status | Denied | Allowed | Denied |
| View history | Own tickets | Authorized queue | Denied |
| Manage Azure infrastructure or SQL administration | Denied through app | Denied through app | Denied |

**Boundary:** Even when the frontend hides an admin option, FastAPI must reject forbidden API calls. The user's Entra role does not automatically give Azure subscription or SQL admin privileges.

## 6. Verification plan and launch criteria

### Access and identity

- [ ] Confirm anonymous browser request is redirected to sign-in or denied by Easy Auth.
- [ ] Confirm anonymous calls to ticket API endpoints are rejected **before FastAPI returns data**.
- [ ] Confirm a user in a different tenant/personal Microsoft account is denied.
- [ ] Confirm an **unassigned account in the correct tenant** is denied.
- [ ] Confirm assigned test employee can access only their tickets; other-user ticket ID is denied.
- [ ] Confirm non-admin employee gets 403 on all admin operations; assigned IT admin functions as designed.
- [ ] Confirm requestor identity cannot be forged through a form field, client header or tampered role.

### SQL and application

- [ ] SQL connectivity succeeds using **Container App managed identity**, not a runtime SQL password.
- [ ] The SQL app principal cannot perform database owner or schema-administrator actions.
- [ ] SQL rejects an unapproved network source; allowed connectivity uses TLS.
- [ ] Insert/select use parameterized SQL and output escapes untrusted ticket descriptions.
- [ ] Tickets remain after application restart and controlled database interruption results in a safe error.
- [ ] Status/assignment operations create attributable audit history.

### Monitoring, deployment and cost

- [ ] Container Apps and SQL diagnostics arrive separately in Log Analytics.
- [ ] Test log output contains no tokens, SQL secrets or entire ticket descriptions.
- [ ] GitHub source/history excludes secrets and Terraform state; deployment identity uses OIDC.
- [ ] Azure usage and ingestion alerts are configured; daily cap effects understood.
- [ ] Verify the actual database free-offer configuration and backup/recovery behaviour.

**Launch gate:** No real employee tickets or sensitive company information should enter Cedarbridge until the **P0 acceptance tests pass**. Use synthetic data in a restricted development setup meanwhile.

## 7. Accepted limitations and deferred hardening

- **Public HTTPS ingress:** Accept for a secured proof of concept with Easy Auth and strict API authorization; evaluate private access/WAF for a real organization.
- **SQL private networking:** Postpone Private Endpoint/VNet/private DNS until realistic workload, costs and networking requirements justify them.
- **Single FastAPI container:** Retain for low request volume. Reject large requests and avoid large attachments or expensive reports in the initial release.
- **Attachments:** If introduced later, use private Blob Storage, access validation, short-lived upload permissions and file screening appropriate to the data.
- **Advanced ITSM:** Automated SLA workflows, detailed dashboards and external integrations are beyond the first cloud engineering proof of concept.

## 8. Implementation status — do not confuse with target state

| Deliverable | Status as reported | Evidence still required |
| --- | --- | --- |
| Business discovery and current/target design | Documented | README and architecture diagram |
| Local FastAPI submission and retrieval | Implemented locally, in-memory | Synthetic local tests |
| Terraform Azure resource definitions | Written and validated | Terraform validation output |
| SQL-only Terraform plan | Generated: **3 to add, 0 to change, 0 to destroy** | Plan summary; no apply reported |
| Easy Auth and Entra tenant/user assignment | **Planned** | Azure configuration and access tests |
| Managed identity to Azure SQL/ACR | **Planned** | Permission assignments and successful connections |
| Azure SQL deployment and persistence | **Pending** | Azure resources and application tests |
| Container deployment and central logging | **Pending** | Container revision and Log Analytics queries |
| GitHub Actions infrastructure/application deployment | **Pending** | Successful workflow and secure state backend |

### Reference documentation

- [Microsoft Learn — Azure Container Apps authentication](https://learn.microsoft.com/en-us/azure/container-apps/authentication)
- [Microsoft Learn — Restrict an Entra application to assigned users](https://learn.microsoft.com/en-us/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users)
- [Microsoft Learn — Daily cap for Log Analytics](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/daily-cap)
