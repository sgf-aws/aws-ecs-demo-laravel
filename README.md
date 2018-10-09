# Laravel on AWS Elastic Container Service (ECS)

These instructions demonstrate how to setup a new install of Laravel 5.6 on
[AWS ECS](https://aws.amazon.com/ecs/). My local build environment is running 
Docker 18.03 ([docker.com](https://docs.docker.com/docker-for-mac/install/)) 
and PHP 7.1 ([brew package](https://brew.sh/)) on macOS 10.13. 

Originally presented to the Amazon Web Services Group in Springfield Missouri 
([SGF AWS](https://github.com/sgf-aws)) by [Jason Klein](https://github.com/jason-klein/) on 08/08/2018. 
Watch the [video recording](https://www.youtube.com/watch?v=DD8q56-jN8E) or 
subscribe to the [SGF AWS YouTube Channel](http://bit.ly/sgf-aws-youtube).

## Create Laravel database on RDS MySQL

### CloudFormation

This script will create a single MySQL 5.7 RDS instance type "t2.small" named 
"laravel-demo". We will configure Laravel to use this database. See stack 
output for MySQL endpoint hostname.

```
aws/laravel-rds.yml
```

_Note: This stack creates a DB Security Group to allow MySQL (3306/tcp) from 
ANY IP (0.0.0.0/0) so that you can configure and test the Laravel MySQL 
connection from anywhere. You should update the CloudFormation template to 
restrict access to appropriate IPs._

_Note: If you do not already have a naming convention for your CloudFormation 
stacks, consider naming each stack using the template filename 
(e.g. "laravel-rds" for this template)._

_Note: If you are unfamiliar with CloudFormation, be aware that you can update 
the stack and upload an updated template file. This can be much faster than 
deleting a stack and creating a new stack if you change the stack template._


## Laravel Installation and Configuration

We are going to create a new Laravel project, configure the Laravel database, 
enable Laravel user authentication (requires database), and enable Laravel 
health checks (for AWS ECS).

### Create Laravel project

This is an extremely simplified version of the 
[Laravel Installation Instructions](https://laravel.com/docs/5.6/installation). 
Refer to their official website if you run into any problems.

Download the Laravel installer package
```
composer global require "laravel/installer"
```

Create a new Laravel project named "laravel"

```
laravel new laravel

# macOS: If file not found error, you may need to specify full path
~/.composer/vendor/laravel/installer/laravel new laravel
```

Resolve any Laravel installation warnings/errors.

I received the following warnings on macOS:

```
You made a reference to a non-existent script @php -r "file_exists('.env') || copy('.env.example', '.env');"
You made a reference to a non-existent script @php artisan key:generate
You made a reference to a non-existent script @php artisan package:discover
```

I ran the following commands to resolve these warnings:

```
cd laravel
cp .env.example .env
php artisan key:generate
php artisan package:discover
```

### Configure Laravel Database

Edit the Laravel environment file (```.env```) and update the DB related 
settings to match your RDS CloudFormation settings. See CloudFormation output 
for RDS endpoint hostname.
```
DB_HOST=laravel-demo.a1b2c3d4e5f6.us-east-1.rds.amazonaws.com
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=password
```

### Enable Laravel User Authentication

These commands will setup the Laravel project to display Login and Register 
features and populate the database with the necessary tables.

```
php artisan make:auth
php artisan migrate
```

### Test local Laravel installation

Serve Laravel using a local PHP web server, then browse to 
[http://localhost:8000/](http://localhost:8000/). You should see a Laravel 
welcome page with Login and Register menu choices.
```
php artisan serve
```

![Laravel Welcome Page](reference/laravel-welcome-localhost.png?raw=true "Laravel Welcome Page")

### Configure Laravel Health Checks

Install and enable 
[Laravel Health Checks](https://github.com/phpsafari/health-checks). 
ECS can rely on this to monitor health of your Laravel application.

```
composer require phpsafari/health-checks
php artisan vendor:publish --tag=health
```

For this demo, I edited the Laravel Health Check file ```config/health.php``` 
and disabled the following lines. After you successfully launch Laravel on ECS, 
you should adjust the Health Check configuration to meet your needs.

```
//        new DebugModeOff(),
//        new LogLevel('error'),
//        new CorrectEnvironment('production'),
//        new QueueIsProcessing(),
```

Run a health check at the command line to verify all checks show "passed". 
If not, resolve any failing checks before you proceed. Visit 
[Laravel Health Checks](https://github.com/phpsafari/health-checks) 
for more information about individual checks.

```
php artisan health:check

+------------------------+--------+----------------------------------------------------------------+-------+
| check                  | status | log                                                            | error |
+------------------------+--------+----------------------------------------------------------------+-------+
| DatabaseOnline         | passed | Trying to connect to database using driver: mysql              |       |
| DatabaseUpToDate       | passed | Checking if any migrations are not yet applied!                |       |
| PathIsWritable         | passed | Checking if laravel/storage is writeable...                    |       |
| PathIsWritable         | passed | Checking if laravel/storage/logs is writeable...               |       |
| PathIsWritable         | passed | Checking if laravel/storage/framework/sessions is writeable... |       |
| PathIsWritable         | passed | Checking if laravel/storage/framework/cache is writeable...    |       |
| MaxRatioOf500Responses | passed | Checking 0%(actual) < 1%(max ratio) = true                     |       |
| MaxResponseTimeAvg     | passed | Checking 0ms(actual) < 300ms(max ratio) = true                 |       |
+------------------------+--------+----------------------------------------------------------------+-------+
```

Serve Laravel using a local PHP web server, then browse to 
[http://localhost:8000/_health](http://localhost:8000/_health) 
to view health information.

```
php artisan serve
```

You could run the following command to view health information from the 
command line. Make sure you receive a 200 OK response and the Health Check 
data showing "health" is "ok".

```
curl -i http://localhost:8000/_health
HTTP/1.1 200 OK
{"health":"ok"}
```

## Laravel Docker Configuration

Now that we have a working local Laravel application, we are going to build 
a Docker container and test our Laravel application in the container.

### Build Image and Start Containers

Run the following command to build a Docker image for Laravel based on 
```Dockerfile``` and start Docker containers "app" and "cron" based on the 
Docker Compose file ```docker-compose.yml```.

```
./docker/up.sh
```

_Note: See ```docker-compose.yml``` for example of two worker containers 
"worker1" and "worker2" that would read Laravel Jobs from queues hosted by SQS._

_Note: This Docker image will serve Laravel as a web service by default. 
Notice that you can configure your Docker container to run other commands 
using the ```SUPER_CMD``` variable._

Confirm Laravel is running in Docker by browsing to 
[http://localhost:8080/](http://localhost:8080/). 
Then confirm Laravel Health Checks are passing by browsing to 
[http://localhost:8080/_health](http://localhost:8080/_health).

_Note: You can also run the following command to view health information from 
the command line. Make sure you receive a 200 OK response and the Health Check 
data showing "health" is "ok"._

```
curl -i http://localhost:8080/_health
HTTP/1.1 200 OK
{"health":"ok"}
```

### Watch Docker logs

If you are having trouble running Laravel on Docker, run the following command 
to view the logs for all running Docker containers.

```
./docker/logs.sh
```

### Shutdown Docker containers

After you confirm Laravel is running on Docker, shutdown the local Docker 
containers. They are no longer needed.

```
./docker/down.sh
```

## ECS Docker Image Repository 

Now that we have a working Laravel application in Docker, we are going to 
create a Docker image repo on AWS ECR and push the container to the repo.

### CloudFormation

Run the following CloudFormation Stack to create a Docker Image Repository 
(laravel-demo) hosted on ECR.

```aws/laravel-ecr.yml```

_Note: This gives all IAM users in your AWS account access to your 
Docker Image Repository._

### Publish Docker Image

Use the provided script to upload your local Docker image containing your 
Laravel application to your Docker Image Repository hosted on ECR.

Edit the push script (```./docker/push.sh```) and update the URI of your 
Docker Image Repository. See output from CloudFormation stack 
_(e.g. "123456789012.dkr.ecr.us-east-1.amazonaws.com/laravel-demo")_ 
or browse to your Repository in AWS Console (ECS > ECR).

Run the following command to upload your local image:

```
./docker/push.sh
```

_NOTE: If error "no basic auth credentials", you must run "aws configure" to 
setup local security credentials for a valid IAM user in your AWS account. 
If you are unfamiliar with IAM, you will "Add User" with "Programmatic access"
to generate the "access key ID" and "secret access key" you need._


## Elastic Container Services

We have a working Laravel app and we've pushed the working Docker image to
our Docker repo on ECR. A few more steps and Laravel will be running on ECS!

### Prerequisites

These IAM Service Roles MUST be created manually before you can build the 
CloudFormation stack. I could not find a way to create them in CloudFormation.

#### Service Role: ecsServiceRole

You must configure this service role to allow ECS to interact with EC2.

1. AWS Web Console > IAM > Roles
1. Create Role
1. AWS Service > Elastic Container Service > Elastic Container Service
1. Next: Permissions
1. Attached Permission Policy: AmazonEC2ContainerServiceRole
1. Next: Review
1. Role Name: ecsServiceRole
1. Create Role

### Service Role: AWSServiceRoleForECS

You must configure this service role to allow ECS to interact with FARGATE.

If you would like to launch an ECS container on FARGATE, go ahead and build 
the ECS stack, then come back and follow these instructions after the stack
is up and running:

1. Manually create an ECS Service that uses FARGATE. _The first time you create
a service that uses FARGATE through the Web Console, the Service Role we need
is automatically created. We cannot create the Service Role through the IAM 
Console._
    1. AWS Console > ECS > Clusters > laravel-demo > Services
    1. Create
    1. Launch Type: FARGATE
    1. Task Definition: CronTaskFargate
    1. Service Name: fargate-test
    1. Number of Tasks: 0
    1. Next
    1. Cluster VPC: Choose any VPC
    1. Cluster Subnets: Choose any Subnet
    1. Load Balancer: None
    1. Enable Service Discovery Integration: NO
    1. Next Step, Next Step, Create Service
1. Remove the service you just created.
1. Edit the ECS CloudFormation file and uncomment the resource 
"CronFargateServiceECS"
1. Update the existing stack with the edited CloudFormation file.

### CloudFormation

Run the following CloudFormation Stack to create 
ECS Task Definitions (app, cron, cron-fargate, worker1), 
Cluster (laravel-demo), 
Services (app, cron, cron-fargate), and 
Application Load Balancer (laravel-demo).

I recommend setting Service Task Counts to zero (0) when you first build
this stack. After the stack successfully builds, update the stack and set
Service Task Counts to two (0) for each service.

```aws/laravel-ecs.yml```

### CloudFormation Parameters

 * Count Service (name): How many tasks should each service launch? (0)

 * ECS Cluster Size: How many EC2 instances should ECS deploy to run your 
 containers? (2)
  
 * ECS Instance Type: What type of EC2 instances should ECS deploy? (t2.small)
 
 * Environment Name: What prefix should be used for stack resources? 
 (laravel-demo)
 
 * Key Name: Which Key Pair will you use to access your EC2 instances? 
 If no Key Pairs are listed, you MUST manually Create Key Pair in EC2 web 
 console (EC2 > Network & Security > Key Pairs).

 * Repository Name: What is the name of your Docker Image repo on ECR? 
 (laravel-demo)
 
 * VPC: Which VPC should your EC2 instances and containers run in?
 
 * VPC Subnets: Which Subnets should your EC2 instances and container run in? 
Select at least two. If you have multiple VPCs, make sure the Subnets are in 
the VPC selected above.

### Definitions

This stack has many moving parts. Here is a brief overview of how each piece 
fits together:

* ECS Task Definitions: Similar to a Docker Compose file. 
Define Docker image, CPU required, Memory required, and port mappings here. 
If you need to persist data in volumes, you would configure them here as well.

* ECS Cluster: If your ECS app runs containers on EC2 instances, 
the cluster manages the EC2 instances. If your app contains many micro 
services, all of them would usually be organized under a single cluster.

* ECS Service: Instruct the Cluster to run a Task Definition in your ECS
Cluster (on an EC2 instance) or in FARGATE (an AWS managed instance).
If the Task serves web traffic, The ECS Service also links the Tasks to 
Load Balancing Target Groups, so that healthy Tasks are automatically 
added to the Target Group and receive traffic from the 
Application Load Balancer.

* ALB: Application Load Balancer accepts public web traffic requests,
finds a matching Target Group, and forwards the request to Healthy 
hosts associated with the Target Group.

_Note: This demo only uses HTTP. You should configure your ALB to use HTTPS. 
AWS provides free SSL certificates for use with ALB. Pro Tip: If your domain 
name uses Route 53 for DNS hosting, approving your SSL request is very easy._

## Cleanup

You must delete the following items before you can delete your CloudFormation
Stacks:

* ECR Images in "laravel-demo" repository

When you delete your CloudFormation stacks, most items will be automatically 
deleted. The following items must be deleted manually:

* Final RDS Snapshot for "laravel-demo" DB Instance

* Any items you created manually must be deleted manually.
