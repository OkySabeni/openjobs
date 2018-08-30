// rds

// db subnet group
// typically, you launch a rds db instance into a db subnet groups and select at least two az.
// when the primary one fail, rds can promote the db instance in the secondary subnet in another az

// ??? this may be done by default but terraform needs a representation of it ???

resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "${var.environment}-rds-subnet-group"
  description = "RDS subnet group"
  subnet_ids = ["${var.subnet_ids}"]

  tags {
    // ??? how come this resource does not have a name ???
    Environment = "${var.environment}"
  }
}

// security group for resources who wants to access the rds instance

// ?? not sure if this is db sg or vpc sg or ec2 sg

resource "aws_security_group" "db_access_sg" {
  vpc_id = "${var.vpc_id}" // i am wondering if this is from networking output
  name = "${var.environment}-db-access-sg"
  description = "allow access to RDS"

  tags {
    Name = "${var.environment}-db-access-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "rds_sg" {
  name = "${var.environment}-rds-sg"
  description = "${var.environment} Security Group"
  vpc_id = "${var.vpc_id}"

  // allow traffic from the SG itself according to tutorial; not sure what that means exactly
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }

  // allow traffic for 5432
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = ["${aws_security_group.db_access_sg.id}"]
  }

  // outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]

    // ??? why is there no "self = true" for this ???
  }

  tags {
    Name = "${var.environment}-rds-sg"
    Environment = "${var.environment}"
  }
}


resource "aws_db_instance" "rds" {
  identifier = "${var.environment}-database"
  allocated_storage = "${var.allocated_storage}"
  engine = "postgres"
  engine_version = "9.6.6"
  instance_class = "${var.instance_class}"
  multi_az = "${var.multi_az}"
  name = "${var.database_name}"
  username = "${var.database_username}"
  password = "${var.database_password}"
  db_subnet_group_name = "${aws_db_subnet_group.rds_subnet_group.id}" // ??? name is id ???
  vpc_security_group_ids = ["${aws_security_group.rds_sg.id}"]
  skip_final_snapshot = true
  snapshot_identifier = "rds-${var.environment}-snapshot"

  tags {
    Environment = "${var.environment}"
  }
}
