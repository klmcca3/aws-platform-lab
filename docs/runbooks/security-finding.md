# Runbook: responding to a GuardDuty or Security Hub finding

**Use when:** GuardDuty reports a finding, or Security Hub shows a new failed control or high-severity finding.
**Goal:** contain any real threat first, then investigate, fix, and record what happened.

## 1. Triage (5 minutes)

1. Open the finding in **GuardDuty > Findings** or **Security Hub CSPM > Findings** in the workloads account (us-east-2).
2. Rule out test data. Sample findings start with `[SAMPLE]`, use placeholder IDs ending in `EXAMPLE`, or reference account `111122223333`. To list only real GuardDuty findings:
   ```bash
   aws guardduty list-findings --detector-id <detector-id> \
     --finding-criteria '{"Criterion":{"service.additionalInfo.sample":{"Eq":["false"]}}}'
   ```
3. Note the **severity**, the **resource** (instance, role, bucket, access key), and the **first and last seen** times.

| Severity | Response |
| --- | --- |
| Critical or High (7.0+) | Start containment now |
| Medium (4.0 to 6.9) | Investigate the same day |
| Low | Review and either fix or suppress with a documented reason |

## 2. Contain (for a likely compromise)

Pick the steps that match the resource:

- **IAM role or user credentials:** revoke active sessions (IAM console: Role > Revoke active sessions), deactivate any access keys, and attach an explicit deny-all policy while you investigate.
- **EC2 instance:** detach it from the Auto Scaling group (`aws autoscaling detach-instances --should-decrement-desired-capacity false`) so a clean replacement launches, then move the instance to a security group with no rules to isolate it. Keep it running for investigation; don't terminate evidence.
- **S3 bucket:** confirm account-level Block Public Access is on (`aws s3control get-public-access-block --account-id <id>`), and remove any bucket policy that grants public access.

## 3. Investigate

1. Find what the identity did, with CloudTrail:
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=Username,AttributeValue=<role-session-or-user> \
     --query "Events[].[EventTime,EventName,EventSource]" --output table
   ```
2. Look for **persistence**: new IAM users, roles, access keys, or policy attachments (`CreateUser`, `CreateAccessKey`, `AttachRolePolicy`).
3. Look for **defense evasion**: attempts to stop CloudTrail, Config, GuardDuty, or Security Hub. The `protect-security-services` SCP should have denied these; a denied attempt is itself strong evidence of compromise.
4. For a resource misconfiguration (a failed Config rule or Security Hub control), CloudTrail shows who changed it and when. Search by resource name.

## 4. Remediate

- Undo any changes the attacker or the mistake made.
- Fix the root cause in **Terraform**, not just in the console, so the fix survives the next rebuild. Changes to `infra/` go through a pull request and the pipeline.
- For a failed control that doesn't apply, disable it in Security Hub with a written reason rather than leaving it failing.

## 5. Verify and close

1. Re-run the check. For a Config rule:
   ```bash
   aws configservice start-config-rules-evaluation --config-rule-names <rule-name>
   ```
2. Confirm the finding is resolved or archived in GuardDuty or Security Hub.
3. Record a short summary: what was found, impact, root cause, fix, and any follow-up actions.

## Worked example from this lab

Removing a test bucket's public access block was flagged NON_COMPLIANT by the `s3-bucket-level-public-access-prohibited` Config rule within minutes. CloudTrail (`DeleteBucketPublicAccessBlock`) identified the session and time. Restoring the block returned the bucket to COMPLIANT. Account-level S3 Block Public Access was then enabled so the same mistake can't expose a bucket again.
