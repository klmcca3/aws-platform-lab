# Runbook: app 5xx errors or unhealthy hosts

**Alarms covered:** `lab-no-healthy-hosts` (critical), `lab-unhealthy-hosts`, `lab-app-5xx-errors`, `lab-alb-5xx-errors`
**Goal:** restore service first, then find the root cause.

## 1. Assess impact (2 minutes)

1. Is the site up?
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" http://<alb-dns-name>
   ```
   `200` = up. `502` or `503` = the load balancer has no healthy servers to send traffic to.
2. Open the **lab-platform** CloudWatch dashboard and note when healthy hosts dropped and when errors started.

| Alarm | Meaning |
| --- | --- |
| `lab-no-healthy-hosts` | Site down: zero servers passing health checks |
| `lab-unhealthy-hosts` | At least one server failing; the site may still be up |
| `lab-alb-5xx-errors` | The load balancer itself is returning errors, usually no healthy targets |
| `lab-app-5xx-errors` | Servers are up but the app is returning errors |

## 2. Check target health

```bash
TG_ARN=$(aws elbv2 describe-target-groups --names lab-app-tg \
  --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --query "TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]" --output table
```

| Reason | Likely cause |
| --- | --- |
| `Target.FailedHealthChecks` | The app stopped or `/health` is failing |
| `Target.Timeout` | The server is still starting, or the app is hanging |
| `Elb.InitialHealthChecking` | A new server is starting; wait |

## 3. Check what Auto Scaling is doing

```bash
aws autoscaling describe-scaling-activities --auto-scaling-group-name lab-app-asg \
  --max-items 6 --query "Activities[].[StartTime,StatusCode,Description]" --output table
```

- **One termination and one launch per failed server:** normal self-healing. Wait about 5 minutes for the replacement.
- **Replacements terminated before they become healthy, again and again:** a replacement loop. Startup is taking longer than `health_check_grace_period`. Check startup time (step 4) and raise the grace period in `infra/app_tier.tf` through a pull request.

## 4. Look at a server

```bash
aws ssm start-session --target <instance-id>
```

Then, on the server:

```bash
sudo systemctl status labapp                          # is the app running?
sudo journalctl -u labapp --no-pager | tail -50       # app errors
sudo tail -50 /var/log/cloud-init-output.log           # startup script errors
curl -s localhost:8080/health                          # health check from inside
curl -s localhost:8080/db-health                       # database connectivity
sudo cloud-init analyze show | tail -5                 # how long startup took
```

## 5. Common causes

| Symptom | Cause | Fix |
| --- | --- | --- |
| `/health` OK, `/db-health` error | Database unreachable or credentials failing | Check RDS status, the `lab-db-sg` rules, and the Secrets Manager endpoint |
| Startup log shows a failed download | S3 gateway endpoint or IAM permission problem | Check the private route table's S3 route and the instance role's S3 policy |
| App service not running | Crash or a bad deploy | Roll back by reverting the pull request; the pipeline redeploys the previous version |
| All servers failing after a deploy | Bad app version | Revert the merge in GitHub; the instance refresh rolls back |

## 6. Recover and record

1. Confirm both targets are `healthy` and the alarms are back to OK (you'll receive OK emails).
2. Write a short incident summary: timeline, impact, root cause, fix, and follow-up actions.

## Worked example from this lab

Stopping the app on one server was detected and the server replaced in under 2 minutes, with no user impact. The test also revealed that replacements were being killed before finishing startup, because startup took about 4 minutes against a 3-minute grace period. Raising the grace period to 10 minutes fixed it, cutting recovery from about 15 minutes to about 5. See the incident report for the full timeline.
