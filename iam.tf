#

data "aws_iam_policy_document" "assume-role" {
    statement {
        actions = [ "sts:AssumeRole" ]
        principals {
            type = "Service"
            identifiers = ["ec2.amazonaws.com", "lambda.amazonaws.com"]
        }
    }
}

data "aws_iam_policy_document" "allow-worker-sqs-work" {
    statement {
        effect = "Allow"
        actions = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:DeleteMessageBatch",
        ]
        resources = [
            "${aws_sqs_queue.jobs.arn}"
        ]
    }
}

data "aws_iam_policy_document" "allow-s3-ssh-keys" {
	statement {
        effect = "Allow"
        actions = [
            "s3:GetObject",
            "s3:GetObjectVersion"
        ]
        resources = [
            "arn:aws:s3:::${var.ssh_keys_bucket}/${var.ssh_keys_prefix}/*",
        ],
    }

	statement {
        effect = "Allow"
        actions = [
            "s3:ListBucket",
        ]
        resources = [
            "arn:aws:s3:::${var.ssh_keys_bucket}"
        ],
        condition {
            test = "StringLike"
            variable = "s3:prefix"
            values = [
                "${var.ssh_keys_prefix}/*"
            ]
        }
    }

}

data "aws_iam_policy_document" "allow-s3-ansible" {
	statement {
        effect = "Allow"
        actions = [
            "s3:GetObject",
            "s3:GetObjectVersion"
        ]
        resources = [
            "arn:aws:s3:::${var.ansible_bucket}/${var.ansible_prefix}/*",
        ],
    }

	statement {
        effect = "Allow"
        actions = [
            "s3:ListBucket",
        ]
        resources = [
            "arn:aws:s3:::${var.ansible_bucket}"
        ],
        condition {
            test = "StringLike"
            variable = "s3:prefix"
            values = [
                "${var.ansible_prefix}/*"
            ]
        }
    }

}

data "aws_iam_policy_document" "allow-s3-ansible-vault" {
	statement {
        effect = "Allow"
        actions = [
            "s3:GetObject",
            "s3:GetObjectVersion"
        ]
        resources = [
            "arn:aws:s3:::${var.ansible_bucket}/${var.ansible_vault_file}",
        ],
    }
}

data "aws_iam_policy_document" "allow-ec2-describe-tags" {
    statement {
        effect = "Allow"
        actions = [
            "ec2:DescribeTags",
        ]
        resources = [ "*" ]
    }
}

data "aws_iam_policy_document" "allow-autoscaling-terminate" {
    statement {
        effect = "Allow"
        actions = [
            "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        resources = [
            "*"
        ]
    }
}


resource "aws_iam_role" "worker" {
    name = "worker"
    path = "/${var.environment}/"
    assume_role_policy = "${data.aws_iam_policy_document.assume-role.json}"
}

resource "aws_iam_instance_profile" "worker" {
    name = "worker"
    path = "/${var.environment}/"
    roles = ["${aws_iam_role.worker.name}"]
}

resource "aws_iam_role_policy" "allow-worker-sqs-work" {
    name = "allow-worker-sqs-work"
    role = "${aws_iam_role.worker.id}"
    policy = "${data.aws_iam_policy_document.allow-worker-sqs-work.json}"
}

resource "aws_iam_role_policy" "allow-s3-ssh-keys" {
    name = "allow-s3-ssh-keys"
    role = "${aws_iam_role.worker.id}"
    policy = "${data.aws_iam_policy_document.allow-s3-ssh-keys.json}"
}

resource "aws_iam_role_policy" "allow-s3-ansible" {
    name = "allow-s3-ansible"
    role = "${aws_iam_role.worker.id}"
    policy = "${data.aws_iam_policy_document.allow-s3-ansible.json}"
}

resource "aws_iam_role_policy" "allow-s3-ansible-vault" {
    name = "allow-s3-ansible-vault"
    role = "${aws_iam_role.worker.id}"
    policy = "${data.aws_iam_policy_document.allow-s3-ansible-vault.json}"
}

resource "aws_iam_role_policy" "allow-ec2-describe-tags" {
    name = "allow-ec2-describe-tags"
    role = "${aws_iam_role.worker.id}"
    policy = "${data.aws_iam_policy_document.allow-ec2-describe-tags.json}"
}
resource "aws_iam_role_policy" "allow-autoscaling-terminate" {
    name = "allow-autoscaling-terminate"
    role = "${aws_iam_role.worker.id}"
    policy = "${data.aws_iam_policy_document.allow-autoscaling-terminate.json}"
}
