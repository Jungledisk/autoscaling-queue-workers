#

variable "bucket" {}
variable "prefix" {}
variable "files" {
    default = [
        "master.yml",
        "templates/worker.service.j2",
        "templates/queue-manager.sh.j2",
        "templates/wrapper.sh.j2",
        "templates/seppuku.service.j2",
        "templates/seppuku.sh.j2",
    ]
}

resource "aws_s3_bucket_object" "ansible" {
    bucket = "${var.bucket}"
    key = "${var.prefix}/${element(var.files, count.index)}"
    source = "${path.module}/${element(var.files, count.index)}"
    etag = "${md5(file("${path.module}/${element(var.files, count.index)}"))}"
    count = "${length(var.files)}"
}
