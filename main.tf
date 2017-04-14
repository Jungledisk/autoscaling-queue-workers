#

provider "aws" {
    region = "${var.region}"
	profile = "${var.aws_profile}"
}

module "ssh_keys" {
    source = "./public_keys"

    bucket = "${var.ssh_keys_bucket}"
    prefix = "${var.ssh_keys_prefix}"
}

module "ansible" {
    source = "./ansible"

    bucket = "${var.ansible_bucket}"
    prefix = "${var.ansible_prefix}"
}

module "vpc" {
    source = "github.com/terraform-community-modules/tf_aws_vpc"

    name = "${var.environment}-vpc"

    cidr = "${var.cidr}"
    private_subnets = "${var.private_subnets}"
    public_subnets = "${var.public_subnets}"
    azs = "${var.azs}"

    enable_dns_hostnames = "true"
    enable_dns_support = "true"

    map_public_ip_on_launch = "true"

    tags = "${var.tags}"
}

resource "aws_security_group" "worker" {
    name = "${var.environment}-worker"
    tags = "${merge(var.tags, map("Role", "worker"))}"
    vpc_id = "${module.vpc.vpc_id}"

    egress {
        protocol = -1
        from_port = 0
        to_port = 0
        cidr_blocks = [
            "0.0.0.0/0"
        ]
    }

    ingress {
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = [
            "0.0.0.0/0"
        ]
    }
}

data "aws_ami" "fedora" {
    most_recent = true
    filter {
        name = "name"
        values = [
            "Fedora-Cloud-Base-25-*-gp2-0"
        ]
    }

    filter {
        name = "virtualization-type"
        values = [ "hvm" ]
    }
    owners = [ "125523088429" ]  # Fedora Cloud SIG
}

data "template_file" "user_data" {
    template = "${file("${path.module}/user_data.sh")}"

    vars {
        ssh_bucket = "${var.ssh_keys_bucket}"
        ssh_prefix = "${var.ssh_keys_prefix}"
        ssh_user = "fedora"
        ssh_keys_cron = "${var.ssh_keys_update_cron}"
        ansible_bucket = "${var.ansible_bucket}"
        ansible_prefix = "${var.ansible_prefix}"
        ansible_vault_file = "${var.ansible_vault_file}"
    }
}

resource "aws_sqs_queue" "jobs" {
    name = "jobs-queue"
}

resource "aws_launch_configuration" "worker" {
    name_prefix = "${var.environment}-"
    image_id = "${data.aws_ami.fedora.id}"
    instance_type = "${var.worker_instance_type}"

    associate_public_ip_address = "true"

    root_block_device {
        volume_type = "gp2"
    }

    security_groups = [
        "${aws_security_group.worker.id}",
    ]

    iam_instance_profile = "${aws_iam_instance_profile.worker.id}"
    user_data = "${data.template_file.user_data.rendered}"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "seppuku_servers" {
    name = "${var.environment}"
    vpc_zone_identifier = ["${module.vpc.public_subnets}"]

    min_size = 0
    max_size = 20

    health_check_grace_period = "120"
    health_check_type = "EC2"

    force_delete = false
    launch_configuration = "${aws_launch_configuration.worker.name}"

    enabled_metrics = [
        "GroupMinSize",
        "GroupMaxSize",
        "GroupDesiredCapacity",
        "GroupInServiceInstances",
        "GroupPendingInstances",
        "GroupStandbyInstances",
        "GroupTerminatingInstances",
        "GroupTotalInstances"
    ]

    tag {
        key = "SQS-work"
        value = "${aws_sqs_queue.jobs.id}"
        propagate_at_launch = true
    }

    tag {
        key = "Terraform"
        value = "true"
        propagate_at_launch = true
    }

    tag {
        key = "Environment"
        value = "${var.environment}"
        propagate_at_launch = true
    }

    tag {
        key = "Name"
        value = "seppuku-worker"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_policy" "seppuku_servers" {
    name = "${var.environment}"
  	autoscaling_group_name = "${aws_autoscaling_group.seppuku_servers.name}"
  	scaling_adjustment = 1
    cooldown = 300
	adjustment_type = "ChangeInCapacity"
}

resource "aws_cloudwatch_metric_alarm" "add_workers" {
	alarm_name = "${var.environment}-add-workers"
	metric_name = "ApproximateNumberOfMessagesVisible"
	namespace = "AWS/SQS"
	statistic = "Sum"
	period = "300"
	threshold = "1"
	comparison_operator = "GreaterThanOrEqualToThreshold"

	evaluation_periods  = "1"

	dimensions {
		QueueName = "${aws_sqs_queue.jobs.name}"
  	}

    alarm_actions = ["${aws_autoscaling_policy.seppuku_servers.arn}"]
}
