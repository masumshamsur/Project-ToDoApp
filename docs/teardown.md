# Clean up: delete the lab resources

Do this when you're finished with the lab. The ALB, the EC2 instances, RDS and the public IPv4 addresses are billed by the hour, about **$50–60 a month** together (see the [deployment report → Cost](deployment-progress.md#cost)).

Delete in the order below. Each resource depends on the ones after it, so going out of order gives "dependency" errors. The whole teardown takes about **15–20 minutes**, most of it waiting for RDS.

| # | Resource | Name in this lab | Console |
|---|---|---|---|
| 1 | Load balancer | `TodoApp-ALB` | EC2 |
| 2 | Target group | `TodoApp-TG` | EC2 |
| 3 | EC2 instances | `web-server-1`, `web-server-2` | EC2 |
| 4 | RDS database | `todo-db-instance` | RDS |
| 5 | DB subnet group | `todoapp-db-subnet-group` | RDS |
| 6 | Security groups | `ToDoApp-ALB-SG`, `ToDoApp-Webserver-SG`, `ToDoApp-Database-SG` | EC2 or VPC |
| 7 | VPC, with its subnets, route tables and internet gateway | `TodoAppVPC`, `TodoApp-IGW` | VPC |
| 8 | Optional: IAM role and key pairs | `TodoApp-EC2-Role`, `web-server-1`, `web-server-2` | IAM, EC2 |

Make sure the Region at the top right is **US East (N. Virginia)** `us-east-1` throughout.

## 1. Delete the load balancer

1. Go to **EC2 → Load Balancing → Load Balancers**.
2. Select `TodoApp-ALB`, then choose **Actions → Delete load balancer**.
3. Type `confirm` and choose **Delete**.

The ALB disappears from the list within a minute. Billing for it stops right away, and the app URL stops working.

## 2. Delete the target group

A target group can't be deleted while a load balancer uses it, so do this after step 1.

1. Go to **EC2 → Load Balancing → Target Groups**.
2. Select `TodoApp-TG`, then choose **Actions → Delete**.
3. Choose **Yes, delete**.

## 3. Terminate the EC2 instances

1. Go to **EC2 → Instances → Instances**.
2. Select **both** `web-server-1` and `web-server-2`.
3. Choose **Instance state → Terminate (delete) instance**, then **Terminate (delete)**.

The state changes to **Shutting-down**, then **Terminated** after a minute or two. Their 8 GiB root volumes are deleted with them, and their public IPv4 addresses are released.

Terminated instances stay in the list, greyed out, for about an hour. That's normal, and they're no longer billed.

> **Terminate, not Stop.** A stopped instance still costs money for its EBS volume, and keeps the VPC from being deleted.

## 4. Delete the RDS database

1. Go to **RDS → Databases** and select `todo-db-instance`.
2. Choose **Actions → Delete**.
3. In the dialog:
   - **Create final snapshot:** clear it, unless you want to keep the tasks. A snapshot is billed for its storage until you delete it.
   - **Retain automated backups:** clear it.
   - Tick the acknowledgement that the backups and data will be lost.
   - Type `delete me` and choose **Delete**.

The status changes to **Deleting**. It takes **5–10 minutes**, and the database then disappears from the list.

If **Delete** is greyed out or fails with a "deletion protection" error, choose **Modify**, clear **Enable deletion protection**, choose **Continue → Apply immediately → Modify DB instance**, then delete again.

## 5. Delete the DB subnet group

Wait until the database is gone from the **Databases** list. A subnet group in use can't be deleted.

1. Go to **RDS → Subnet groups**.
2. Select `todoapp-db-subnet-group` and choose **Delete**, then **Delete** again.

## 6. Delete the security groups

`ToDoApp-ALB-SG` and `ToDoApp-Webserver-SG` reference each other:

- the ALB group's **outbound** rule sends `3000` to the web server group
- the web server group's **inbound** rule accepts `3000` from the ALB group

A security group can't be deleted while another group's rule references it, so neither one can go first. Break the loop by removing the ALB group's outbound rule:

1. Go to **EC2 → Network & Security → Security Groups**. Filter by VPC `TodoAppVPC` if the list is long.
2. Select `ToDoApp-ALB-SG` → **Outbound rules** tab → **Edit outbound rules**. Choose **Delete** on the TCP `3000` rule, then **Save rules**.

Then delete the three groups, **one at a time, in this order** (select the group → **Actions → Delete security groups** → type `delete` → **Delete**):

| Order | Group | Why this order |
|---|---|---|
| 1 | `ToDoApp-Database-SG` | Nothing references it |
| 2 | `ToDoApp-Webserver-SG` | It was referenced only by the database group (deleted) and the ALB group's outbound rule (removed) |
| 3 | `ToDoApp-ALB-SG` | It was referenced only by the web server group (deleted) |

If you get **"has a dependent object"** or **"resource sg-… has a dependent object"**, a network interface is still using the group. The ALB, the instances and RDS release their network interfaces a few minutes after they're deleted. Wait 2–5 minutes and try again. To check, go to **EC2 → Network & Security → Network Interfaces** and filter by VPC `TodoAppVPC`. The list should be empty.

Don't try to delete the VPC's `default` security group. It's deleted with the VPC.

## 7. Delete the VPC

Deleting the VPC also deletes its subnets, its route tables and any security groups left in it, and detaches the internet gateway.

1. Go to **VPC → Your VPCs**.
2. Select `TodoAppVPC` (`10.0.0.0/16`) and choose **Actions → Delete VPC**.
3. The dialog lists what will be deleted: 4 subnets, 3 route tables, the internet gateway `TodoApp-IGW` and the `default` security group. Check that the internet gateway is included. If it isn't, tick it.
4. Type `delete` and choose **Delete**.

If the console says the VPC still has dependencies, it lists them, usually network interfaces that are still being released. Wait a few minutes and try again.

Afterwards, check **VPC → Internet gateways**. `TodoApp-IGW` should be gone. If it's still there as **Detached**, select it and choose **Actions → Delete internet gateway**.

Don't delete your account's **default VPC**, the one with **Default VPC: Yes**. Other services use it.

## 8. Optional: the IAM role and key pairs

These are free, so you can keep them for the next build. To remove them:

- **IAM role:** **IAM → Roles** → select `TodoApp-EC2-Role` → **Delete**. Type the role name to confirm. Its instance profile is deleted with it.
- **Key pairs:** **EC2 → Network & Security → Key Pairs** → select `web-server-1` and `web-server-2` → **Actions → Delete**. Type `Delete` to confirm. Then delete the `.pem` files on your computer:

  ```bash
  rm -f ~/.ssh/web-server-1.pem ~/.ssh/web-server-2.pem
  ```

The GitHub repo [masumshamsur/Project-ToDoApp](https://github.com/masumshamsur/Project-ToDoApp) is free, so keep it.

## 9. Check nothing is left

| Where | Expect |
|---|---|
| **EC2 → Load Balancers** | No `TodoApp-ALB` |
| **EC2 → Target Groups** | No `TodoApp-TG` |
| **EC2 → Instances** | Both servers **Terminated** (or gone) |
| **EC2 → Volumes** | No volumes left from the instances |
| **EC2 → Elastic IPs** | Empty. This lab doesn't create any |
| **RDS → Databases** | No `todo-db-instance` |
| **RDS → Snapshots** | No manual snapshot, unless you chose to keep one. Delete it if you don't need it, because it's billed |
| **VPC → Your VPCs** | Only the default VPC |

Or check from the AWS CLI. Each command should print nothing, or `[]`:

```bash
aws elbv2 describe-load-balancers --names TodoApp-ALB --region us-east-1 2>&1 | grep -c LoadBalancerArn
aws ec2 describe-instances --region us-east-1 \
  --filters Name=tag:Name,Values=web-server-1,web-server-2 Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId'
aws rds describe-db-instances --region us-east-1 --query "DBInstances[?DBInstanceIdentifier=='todo-db-instance'].DBInstanceIdentifier"
aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=TodoAppVPC --query 'Vpcs[].VpcId'
```

The first command prints `0` when the ALB is gone.

Finally, check **Billing and Cost Management → Bills** the next day. Charges stop when each resource is deleted, but they can take up to 24 hours to show up.
