#create an ecs cluster
resource "aws_ecs_cluster" "development-cluster" {
  name = "development-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#create fargate specifications for the cluster
resource "aws_ecs_cluster_capacity_providers" "development-cluster" {
  cluster_name = aws_ecs_cluster.development-cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

#create an sts assume role for the ecs role
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

#create an ecs task execution role and attatch the sts assume role(works both as a task execution role and task role)
resource "aws_iam_role" "ecsTaskExecutionRole2" {
  name               = "ecsTaskExecutionRole2"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}


#create policy AmazonECSTaskExecutionRolePolicy and attatch to ecs role
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy_attatchment" {
  role       = aws_iam_role.ecsTaskExecutionRole2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # or AmazonEC2ContainerServiceforEC2Role
}

#create a task definition
resource "aws_ecs_task_definition" "frontend-task" {
  family                   = "frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole2.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole2.arn

  container_definitions = <<DEFINITION
[
  {
    "image": "331879450537.dkr.ecr.us-west-2.amazonaws.com/frontend:latest",
    "cpu": 1024,
    "memory": 2048,
    "name": "frontend",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
DEFINITION
}

#create a load balancer for the ecs service
resource "aws_lb" "frontend-lb" {
  name               = "frontend-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dev_security_group.id]
  subnets            = aws_subnet.dev_public_subnet[*].id

}

#create a target group
resource "aws_lb_target_group" "frontend-TG" {
  name        = "frontend-TG"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"    #for fargate
  vpc_id      = aws_vpc.dev_vpc.id

   health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }
}

#create a listener for the lb
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.frontend-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend-TG.arn
  }
}

#create a service for ecs
resource "aws_ecs_service" "aws-ecs-service" {
  name                 = "frontend-service"
  cluster              = aws_ecs_cluster.development-cluster.id
  task_definition      = aws_ecs_task_definition.frontend-task.id
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 2
  force_new_deployment = true

  network_configuration {
    subnets          = aws_subnet.dev_private_subnet.*.id
    assign_public_ip = false
    security_groups = [
      aws_security_group.dev_security_group.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend-TG.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.listener]
}
