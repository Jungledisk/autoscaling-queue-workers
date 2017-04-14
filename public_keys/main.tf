#

variable "bucket" {}
variable "prefix" {}
variable "public_key_names" {
    default = [
        "jkoelker",
    ]
}


resource "aws_s3_bucket_object" "public_keys" {
    bucket = "${var.bucket}"
    key = "${var.prefix}/${element(var.public_key_names, count.index)}.pub"
    source = "${path.module}/${element(var.public_key_names, count.index)}.pub"
    etag = "${md5(file("${path.module}/${element(var.public_key_names,
                                                 count.index)}.pub"))}"
    count = "${length(var.public_key_names)}"
}
