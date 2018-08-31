// cloudwatch log group

// ??? why is this here and not its own module ???
// ??? is this a placeholder ???

resource "aws_cloudwatch_log_group" "openjobs" {
  name = "openjobs"

  tags {
    Environment = "${var.environment}"
    Application = "Openjobs"
  }
}

// ecr repository

// weird naming a reposistory an "_app"

resource "aws_ecr_repository" "openjobs_app" {
  name = "${var.repository_name}"
}


// ecs cluster

// ??? a placeholder ???

resource "aws_ecs_cluster" "cluster" {
  name = "${var.environment}-ecs-cluster"
}


// ecs task definition

// this data will fetched and used somewhere else in the ecs task

data "template_file" "web_task" {
  template = "${file("${path.module}/tasks/web_task_definition.json")}"

  vars {
    image = "${aws_ecr_repository.openjobs_app.repository_url}"
    secret_key_base = "${var.secret_key_base}"
    database_url = "postgres://${var.database_username}:${var.database_password}@${var.database_endpoint}:5432/${var.database_name}?encoding=utf8&pool=40"
    log_group = "${aws_cloudwatch_log_group.openjobs.name}"
  }
}

// task definition for rails

resource "aws_ecs_task_definition" "web" {
  family = "${var.environment}_web"

  // ??? why do this definition need to be fetched ???
  // why can't it be inline?
  // is it similar to a variable?
  container_definitions = "${data.template_file.web_task.rendered}"

  // ??? how would a task going into ec2 work ???
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  execution_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
}


// task definition one off task like db:migrate

data "template_file" "db_migrate_task" {
  template = "${file("${path.module}/tasks/db_migrate_task_definition.json")}"

  vars {
    image = "${aws_ecr_repository.openjobs_app.repository_url}"
    secret_key_base = "${var.secret_key_base}"
    database_url = "postgres://${var.database_username}:${var.database_password}@${var.database_endpoint}:5432/${var.database_name}?encoding=utf8&pool=40"
    log_group = "openjobs" // ??? why is this different than the def for rails ???
  }
}

resource "aws_ecs_task_definition" "db_migrate" {
  family = "${var.environment}_db_migrate"
  container_definitions = "${data.template_file.db_migrate_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  execution_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
}

// app load balancer

// random id to use for the app load balancer ???

resource "random_id" "target_group_suffix" {
  byte_length = 2
}

resource "aws_alb_target_group" "alb_target_group" {
  name = "${var.environment}-alb-target-group-${random_id.target_group_suffix.hex}"
  port = 80
  protocol = "HTTP"
  vpc_id = "${var.vpc_id}"
  target_type = "ip"

  lifecyle {
    create_before_destroy = true
  }
}

// security group for alb

resource "aws_security_group" "web_inbound_sg" {
  name = "${var.environment}-web-inbound-sg"
  description = "Allow HTTP from anywhere into alb"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 80 // ??? why port 80 ???
    to_port = 80
    protocol = "tcp" // ??? why not http ???
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-web-inbound-sg"
  }
}


resource "aws_alb" "alb_openjobs" {
  name = "${var.environment}-alb-openjobs"
  subnets = ["${var.public_subnet_ids}"]

  // the var.security_group_ids is from networking output
  security_groups = ["${var.security_group_ids}", "${aws_security_group.web_inbound_sg.id}"]

  tags {
    Name = "${var.environment}-alb-openjobs"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "openjobs" {
  load_balancer_arn = "${aws_alb.alb_openjobs.arn}"
  port = "80"
  protocol = "HTTP"
  depends_on = ["aws_alb_target_group.alb_target_group"]

  default_action {
    target_group_arn = "${aws_alb_target_group}"
    type = "forward"
  }
}

// iam service role

data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name = "ecs_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}

// ecs service scheduler role

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name = "ecs_service_role_policy"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
  role = "${aws_iam_role.ecs_role.id}"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_task_execution_role"

  // ??? why is this not a data statement ???
  assume_role_policy = "${file("${path.module}/policies/ecs-execution-role-policy.json")}"
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name = "ecs_execution_role_policy"
  policy = "${file("${path.module}/policies/ecs-execution-role-policy.json")}"
  role = "${aws_iam_role.ecs_execution_role.id}"
}

// ??? confuse land. ecs_execution_role already assume a policy but then it still needs
// an iam role policy that has the same policy? What if the policy differs ???

// ecs service

// security group for ecs

resource "aws_security_group" "ecs_service" {
  vpc_id = "${var.vpc_id}"
  name = "${var.environment}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // weird port number. i wonder if this is for ecs strictly
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-ecs-service-sg"
    Environment = "${var.environment}"
  }
}

// specify family to find latest active revision

// ??? Why can't we simply use the previously defined definition ???

data "aws_ecs_task_definition" "web" {
  task_definition = "${aws_ecs_task_definition.web.family}"
}

resource "aws_ecs_service" "web" {
  name = "${var.environment}-web"

  // ??? related to the above. pretty confusing ???
  task_definition = "${aws_ecs_task_definition.web.family}:${max("${aws_ecs_task_definition.web.revision}", "${data.aws_ecs_task_definition.web.revision}")}"

  desired_count = 2
  launch_type = "FARGATE"
  cluster = "${aws_ecs_cluster.cluster.id}"
  depends_on = ["aws_iam_role_policy.ecs_service_role_policy"] // this is the scheduler policy

  network_configuration {
    security_groups = ["${var.security_group_ids}", "${aws_security_group.ecs_service.id}"]
    subnets = ["${var.subnets_id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name = "web"
    container_port = "80"
  }

  depends_on = ["aws_alb_target_group.alb_target_group"]
}


// auto scaling for ecs

resource "aws_iam_role" "ecs_autoscale_role" {
  name = "${var.environment}_ecs_autoscale_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-autoscale-role.json")}"
}

resource "aws_iam_role_policy" "ecs_autoscale_role_policy" {
  name = "ecs_autoscale_role_policy"
  policy = "${file("${path.module}/policies/ecs-autoscale-role-policy.json")}"
  role = "${aws_iam_role.ecs_autoscale_role.id}"
}


// this allows you to set a target value and it autoscales to that

resource "aws_appautoscaling_target" "target" {
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:Service:DesiredCount"
  role_arn = "${aws_iam_role.ecs_autoscale_role.arn}"
  min_capacity = 2
  max_capacity = 4
}

resource "aws_appautoscaling_target" "up" {
  name = "${var.environment}_scale_up"
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:Service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    cooldown = 60
    metric_aggrgation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

resource "aws_appautoscaling_policy" "down" {
  name = "${var.environment}_scale_down"
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:Service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    cooldown = 60
    metric_aggrgation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

// metric used for auto scale

// this has to be compatible with the app autoscaling policy

resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name = "${var.environment}_openjobs_web_cpu_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/ECS"
  period = "60"
  statistic = "Maximum"
  threshold = "85"

  dimensions {
    ClusterName = "${aws_ecs_cluster.cluster.name}"
    ServiceName = "${aws_ecs_service.web.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.up.arn}"]
  ok_actions = ["${aws_appautoscaling_policy.down.arn}"]
}
