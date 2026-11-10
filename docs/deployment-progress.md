# Deployment report (Run 2)

Run 2 rebuilds the project with the subnet CIDRs and names from the architecture diagram. Run 1 is archived in [run-1/](run-1/deployment-progress.md).

Order: Network, then Database (RDS), then Web servers (EC2), then Load balancer (ALB), then the troubleshooting and deployment report.

> **Build order vs. doc order:** Run 2 was actually built as network → web servers → database → load balancer, with a placeholder `.env` until RDS existed. The guides are arranged as network → database → web servers → load balancer, which is simpler: the endpoint exists before the servers are configured, so `.env` is written once. The results are the same either way.

## Summary

| | |
|---|---|
| **Status** | Deployed and tested, then torn down, on 2026-11-09 |
| **App URL** | `http://TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com` (no longer live: the stack has been torn down) |
| **Region** | us-east-1, across two AZs (1a, 1b) |
| **Web tier** | 2 × t3.micro (Amazon Linux 2023), Node.js app on port 3000 as a systemd service, behind an internet-facing ALB |
| **Data tier** | RDS for MySQL 8.4.11, db.t4g.micro, Single-AZ, private subnets only, no public access |
| **Code** | [masumshamsur/Project-ToDoApp](https://github.com/masumshamsur/Project-ToDoApp), cloned to `~/todo-app` on both servers |
| **Result** | All tests passed: shared database across both servers, add, complete and delete through the ALB, and failover when one server is down |
| **Issues hit** | 6 configuration problems, all fixed, plus 1 known app display bug. See [Issues and fixes](#issues-and-fixes) |

## Checklist

- [x] 0. Tear down Run 1 (ALB, target group, EC2, RDS, DB subnet group, VPC)
- [x] 1. Network: VPC, subnets, IGW, route tables, security groups
- [x] 2. Database: DB subnet group, RDS MySQL
- [x] 3. Web servers: IAM role, 2 EC2 instances, `.env`, connection test, schema, Node.js app as a systemd service
- [x] 4. Load balancer: target group, ALB, `API_BASE_URL`, browser test, failover test
- [x] 5. Troubleshooting and deployment report
- [x] 6. Tear down the Run 2 resources ([teardown.md](teardown.md))

## Target network (from the diagram)

| Subnet | AZ | CIDR | Route table |
|---|---|---|---|
| `TodoApp-Subnet-Public-A` | `us-east-1a` | `10.0.1.0/24` | `TodoApp-Public-Route-Table` |
| `TodoApp-Subnet-Public-B` | `us-east-1b` | `10.0.2.0/24` | `TodoApp-Public-Route-Table` |
| `TodoApp-Subnet-Private-A` | `us-east-1a` | `10.0.3.0/24` | `TodoApp-Private-Route-Table` |
| `TodoApp-Subnet-Private-B` | `us-east-1b` | `10.0.4.0/24` | `TodoApp-Private-Route-Table` |

## Resource IDs

Filled in as each step is completed.

### Network

| Resource | Name | ID | Notes |
|---|---|---|---|
| VPC | `TodoAppVPC` | `vpc-03e97957918aae723` | `10.0.0.0/16`, DNS resolution and hostnames enabled |
| Subnet | `TodoApp-Subnet-Public-A` | `subnet-0eb1b1011dc3ba466` | `10.0.1.0/24`, us-east-1a, auto-assign public IPv4 Yes |
| Subnet | `TodoApp-Subnet-Public-B` | `subnet-0857da153503e6493` | `10.0.2.0/24`, us-east-1b |
| Subnet | `TodoApp-Subnet-Private-A` | `subnet-0683e881914e739fa` | `10.0.3.0/24`, us-east-1a |
| Subnet | `TodoApp-Subnet-Private-B` | `subnet-043b0f43c7cbb394a` | `10.0.4.0/24`, us-east-1b |
| Internet gateway | `TodoApp-IGW` | `igw-00b2e6e5d265f4d15` | Attached to `TodoAppVPC` |
| Route table | `TodoApp-Public-Route-Table` | `rtb-052980ab4b1b17464` | Public-A, Public-B |
| Route table | `TodoApp-Private-Route-Table` | `rtb-024311cc921c3bd0c` | Private-A, Private-B |
| Route table | (main, unused) | `rtb-070a3b9e6b470110e` | Created by AWS |
| Security group | `ToDoApp-ALB-SG` | `sg-0998932174b01d949` | Inbound HTTP 80 from 0.0.0.0/0 only (stray SSH rule removed). Outbound TCP 3000 to Webserver-SG (had 0 outbound rules, fixed in Step 4) |
| Security group | `ToDoApp-Webserver-SG` | `sg-0d06e3270610cb1c5` | TCP 3000 from ALB-SG, SSH 22 from My IP (was 0.0.0.0/0, fixed) |
| Security group | `ToDoApp-Database-SG` | `sg-0c4a575327fbb8c10` | MySQL 3306 from Webserver-SG |

### Database

| Resource | Name | ID / value | Notes |
|---|---|---|---|
| DB subnet group | `todoapp-db-subnet-group` | | Private-A `10.0.3.0/24` and Private-B `10.0.4.0/24` only |
| RDS instance | `todo-db-instance` | `todo-db-instance.cmz0eoi66au7.us-east-1.rds.amazonaws.com:3306` | MySQL Community 8.4.11, db.t4g.micro, Single-AZ in us-east-1a, public access No, internet access gateway Disabled |
| Security group | `ToDoApp-Database-SG` | `sg-0c4a575327fbb8c10` | 3306 from `ToDoApp-Webserver-SG` |
| Schema | `todo_app.Tasks` | | id, task_name, task_description, due_date, completed, created_at |

Both servers connect (`CONNECTED 8.4.11, tls_required 0`). Task 1 was created from web-server-1 and task 2 from web-server-2, and each server lists both.

### Web servers

| Resource | Name | ID | Notes |
|---|---|---|---|
| IAM role | `TodoApp-EC2-Role` | | `AmazonSSMManagedInstanceCore`, kept from Run 1 |
| EC2 instance | `web-server-1` | `i-0ef1c46433f0f1a11` | t3.micro, AL2023, `TodoApp-Subnet-Public-A`, us-east-1a, private IP `10.0.1.75`, key `web-server-1` |
| EC2 instance | `web-server-2` | `i-04939ffcb52cbe2c3` | t3.micro, AL2023, `TodoApp-Subnet-Public-B`, us-east-1b, private IP `10.0.2.181`, key `web-server-2` |
| App | `todo-app.service` | | Cloned from `masumshamsur/Project-ToDoApp` to `~/todo-app`, port 3000. Both servers: active (running), homepage 200, `/config` OK |

AMI: `ami-0c230065b91270bc6` (`al2023-ami-2023.12.20261102.0-kernel-6.18-x86_64`).

### Load balancer

| Resource | Name | ID / value | Notes |
|---|---|---|---|
| Target group | `TodoApp-TG` | `targetgroup/TodoApp-TG/a8f7964a4270e97e` | Instance targets, HTTP, `TodoAppVPC`, both servers registered on port 3000 (the group's default port shows HTTP:80) |
| Load balancer | `TodoApp-ALB` | `app/TodoApp-ALB/d8c19a889571e263` | Internet-facing, IPv4, Public-A `subnet-0eb1b1011dc3ba466` (us-east-1a) and Public-B `subnet-0857da153503e6493` (us-east-1b), created 2026-11-09 |
| Listener | HTTP:80 | | Forward to `TodoApp-TG` (100%), stickiness off |
| DNS name | | `TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com` | App URL: `http://TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com` |

## Test results

| # | Test | How | Result | Evidence |
|---|---|---|---|---|
| 1 | App runs on each server | `curl localhost:3000/` and `/config` | `Homepage HTTP 200` on both | [setup-ec2.md → 3.8](setup-ec2.md#38-test-on-the-instance) |
| 2 | Servers reach RDS | Connection test from each server | `CONNECTED 8.4.11`, `tls_required 0` on both | [setup-ec2.md → 3.5](setup-ec2.md#35-test-the-database-connection-both-instances) |
| 3 | Shared database | Task 1 created on web-server-1, then listed on web-server-2 before creating task 2 | Both servers see both tasks | [setup-ec2.md → 3.8](setup-ec2.md#38-test-on-the-instance) |
| 4 | Frontend points at the ALB | `curl localhost:3000/config` after setting `API_BASE_URL` | Returns the ALB URL on both | [setup-alb.md → 3](setup-alb.md#3-point-the-app-at-the-alb) |
| 5 | Target health | **TodoApp-TG → Targets** | 2 Healthy, one in each AZ | [setup-alb.md → 4](setup-alb.md#4-test-it) |
| 6 | Browser through the ALB | Open the ALB DNS name, then add, complete and delete | All work. Tasks from both servers listed | [setup-alb.md → 4](setup-alb.md#4-test-it) |
| 7 | Failover | `systemctl stop todo-app` on web-server-1, add a task, start it again | web-server-1 went Unhealthy. "Added while server 1 down" saved through web-server-2. Both Healthy again after restart | [setup-alb.md → 5](setup-alb.md#5-test-high-availability) |

## Issues and fixes

Full details, with screenshots, are in [troubleshooting.md](troubleshooting.md#run-2-at-a-glance).

| Step | Issue | Fix |
|---|---|---|
| 1 · Network | SSH rule on `ToDoApp-ALB-SG`. Web server SSH open to `0.0.0.0/0` | Removed the ALB SSH rule. Web server SSH set to My IP |
| 3 · Web servers | SSH `Permission denied (publickey)` | `chmod 400` on the key |
| 2 · Database | RDS endpoint hard to find in the new console | Read it from the connection snippet, or use `aws rds describe-db-instances` |
| 3 · Web servers | `/tasks` failed with `ER_NO_SUCH_TABLE` | Ran the schema script (the schema step had been skipped) |
| 4 · Load balancer | Register targets showed no instances | The list hadn't loaded. A refresh showed both servers |
| 4 · Load balancer | ALB "Reachability may be impacted": `ToDoApp-ALB-SG` had no outbound rule | Added outbound TCP 3000 → `ToDoApp-Webserver-SG` |

**Known issue:** due dates show one day early in the browser, because `public/script.js` shows a UTC date in local time. It's an app display bug, left unfixed. See [troubleshooting.md → Due dates show one day early](troubleshooting.md#due-dates-show-one-day-early).

## Lessons learned

- **Security groups are stateful, and each hop needs a rule pair.** The ALB needs an outbound rule to the targets, as well as the targets' inbound rule from the ALB. Check **both** tabs of every group. See [setup-network.md → How the rules fit together](setup-network.md#how-the-rules-fit-together).
- **Reference security groups, not IPs or `0.0.0.0/0`,** between tiers. Use **My IP** for SSH only.
- **A successful DB connection test doesn't prove the schema exists.** Create the table, then test `/tasks`.
- **The app reads `.env` only at startup.** Restart after every change, and check with `curl localhost:3000/config`.
- **Read the server log for the real error.** The API returns generic messages, and `journalctl -u todo-app` shows the cause.
- **Create the DB subnet group yourself,** with private subnets only, before creating RDS.

## Cost

Approximate us-east-1 on-demand prices. Check the [AWS Pricing Calculator](https://calculator.aws/) for current figures.

| Resource | Approx. cost | Free tier (new accounts, first 12 months) |
|---|---|---|
| Application Load Balancer | ~$16–20/month | Usually not covered |
| 2 × t3.micro | ~$15/month together | 750 hours/month of t2/t3.micro |
| RDS db.t4g.micro + storage | ~$13–15/month | 750 hours/month of a micro DB instance |
| 2 public IPv4 addresses | ~$7/month | 750 hours/month |

## Clean up

**Done on 2026-11-09.** All Run 2 resources were deleted following [teardown.md](teardown.md), so the resource IDs above no longer exist.

To delete everything this lab created, follow [teardown.md](teardown.md), which gives console steps for each resource. In short: ALB → target group → EC2 instances → RDS → DB subnet group → security groups (remove the ALB group's outbound rule first) → VPC, with the IAM role and key pairs optional.
