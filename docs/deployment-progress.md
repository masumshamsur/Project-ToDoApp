# Deployment progress (Run 2)

Run 2 rebuilds the project with the subnet CIDRs and names from the architecture diagram. Run 1 is archived in [run-1/](run-1/deployment-progress.md).

Order: Network, then Web servers (EC2), then Database (RDS), then Load balancer (ALB), then the troubleshooting and deployment report.

## Checklist

- [x] 0. Tear down Run 1 (ALB, target group, EC2, RDS, DB subnet group, VPC)
- [x] 1. Network: VPC, subnets, IGW, route tables, security groups
- [ ] 2. Web servers: IAM role, 2 EC2 instances, Node.js app as a systemd service
- [ ] 3. Database: DB subnet group, RDS MySQL, `.env`, schema, connection from both servers
- [ ] 4. Load balancer: target group, ALB, `API_BASE_URL`, browser test, failover test
- [ ] 5. Troubleshooting and deployment report

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
| Internet gateway | `TodoApp-IGW` | | Attached to `TodoAppVPC` |
| Route table | `TodoApp-Public-Route-Table` | `rtb-052980ab4b1b17464` | Public-A, Public-B |
| Route table | `TodoApp-Private-Route-Table` | `rtb-024311cc921c3bd0c` | Private-A, Private-B |
| Route table | (main, unused) | `rtb-070a3b9e6b470110e` | Created by AWS |
| Security group | `ToDoApp-ALB-SG` | `sg-0998932174b01d949` | HTTP 80 from 0.0.0.0/0 only (stray SSH rule removed) |
| Security group | `ToDoApp-Webserver-SG` | `sg-0d06e3270610cb1c5` | TCP 3000 from ALB-SG, SSH 22 from My IP (was 0.0.0.0/0, fixed) |
| Security group | `ToDoApp-Database-SG` | `sg-0c4a575327fbb8c10` | MySQL 3306 from Webserver-SG |
