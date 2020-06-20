provider "aws" {
   region="ap-south-1"
   profile="pratishtha"
}





resource "aws_key_pair" "task-key" {
  key_name   = "task-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHoK9+QVhS4vq5nSk9CXdQ92r+SmZ17wYzKDxRudsD0CChty9HmrbSSTLfa3iNLwwR5D62TFjawEB7mvOh9JgnfWe8C+imVJpjs7lxOwvpVxSK1AdzKj5cLxjTiCF5J8g6SscWGC06nG59SfALb/hc5QYNN6QkUJoZ9HRwz4ByjPNtLpVnzclqQGNek7gv18TRO1cEQMSOq+Xr7RIWTejFc+c2llnJrFmpEyEuwGFg0xS8V8BtPT8mjnhMMxv1m1ikuE0EN/wFAdCV9OaYgqOVNYbvQeHkqeeJpuI/QQV0TfBT6FPEXFqJgi9lwfj4zCmSKyr/czBmm0aCIvzBY7qn hp@DESKTOP-04E4UHM"
}



resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "allow traffic"

  ingress {
    description = "TCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks =["0.0.0.0/0"]

  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks =["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}






resource "aws_instance" "myins" {
  ami ="ami-09235b147e540d7e6"
  instance_type="t2.micro"
  key_name="task-key"
  availability_zone="ap-south-1a"
  security_groups=["allow_ssh"]
  tags = {
     Name ="taskos"
  }

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/HP/Desktop/pp/today.pem")
    host     = aws_instance.myins.public_ip
   }

   provisioner "remote-exec" {
     inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
     ]
   }
}

output "instanceIP" {
    value = aws_instance.myins.public_ip
}

resource "aws_ebs_volume" "ebs2" {
  availability_zone = "ap-south-1a"
  size              = 1

  tags = {
    Name = "myebs1"
  }
}



resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.ebs2.id
  instance_id = aws_instance.myins.id
  force_detach= true
}






resource "aws_s3_bucket" "cloud-s3-bucket" {
   bucket="cloud-s3-bucket"
   acl   ="private"
   region="ap-south-1"
   tags= {
       Name="s3_bucket"
   }
}
locals {
    s3_origin_id = "s3-origin"
}

resource "aws_s3_bucket_public_access_block" "s3_public" {
    bucket = "cloud-s3-bucket"

    block_public_acls   =false
    block_public_policy =false
}





resource "aws_cloudfront_distribution" "cf_distribution" {
  origin {
    domain_name = aws_s3_bucket.cloud-s3-bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
     
    custom_origin_config {
        http_port =80
        https_port =80
        origin_protocol_policy ="match-viewer"
        origin_ssl_protocols=["TLSv1", "TLSv1.1", "TLSv1.2"]
     }
  }
  enabled = true
  default_cache_behavior {
     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
     cached_methods   = ["GET", "HEAD"]
     target_origin_id = local.s3_origin_id
   
     forwarded_values {
        query_string = false

        cookies {
           forward = "none"
        }
      }

      viewer_protocol_policy = "allow-all"
      min_ttl                = 0
      default_ttl            = 3600
      max_ttl                = 86400
  }
 
  restrictions {
     geo_restriction {
       restriction_type = "none"
     }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}




resource "null_resource" "mounting" {
    depends_on=[
       aws_volume_attachment.ebs_att,
    ]
    connection {
       type     = "ssh"
       user     = "ec2-user"
       private_key = file("C:/Users/HP/Desktop/pp/today.pem")
       host     = aws_instance.myins.public_ip
    }

     provisioner "remote-exec" {
        inline= [
            "sudo mkfs.ext4 /dev/xvdd",
            "sudo mount /dev/xvdd /var/www/html",
            "sudo rm -rf /var/www/html",
            "sudo git clone https://github.com/P-pa/cloudtask.git /var/www/html",
         ]
      }
}


