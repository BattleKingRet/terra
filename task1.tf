provider "aws" {
  region = "ap-south-1"
  profile = "rohan"
}

#create security group

resource "aws_security_group" "allow_tls" {
  name        = "launch-wizard-2"
  description = "Allow http and ssh"
  ingress {
    description = "SSH Port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPD port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "local host"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Custom tcp"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

# launch ec2 instance

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name =  "key1"
  security_groups =  [ "launch-wizard-2" ]
  
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ROHAN/Downloads/key1.pem")
    host     = aws_instance.web.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
      ]
  }

  tags = {
    Name = "taskOS"
  }

}

#create ebs volume

resource "aws_ebs_volume" "ebs_volume1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "task_volume_1"
  }
}

# attach ebs volume

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs_volume1.id
  instance_id = aws_instance.web.id
  force_detach = true
}


# mount harddisk 

resource "null_resource" "harddisk" {
 depends_on = [
    aws_volume_attachment.ebs_att,
  ]

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ROHAN/Downloads/key1.pem")
    host     = aws_instance.web.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh  /var/www/html",
      "sudo rm -rf  /var/www/html/*",
      "sudo git clone https://github.com/BattleKingRet/gitt.git  /var/www/html/"
    ]
  }

}

#create a s3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "taskbucketrohan"
  acl    = "private"
    tags = {
    Name        = "web_bucket"
  }
  force_destroy = true

  
  provisioner "local-exec" {

        command = "aws s3 sync C:/Users/ROHAN/Pictures/task s3://taskbucketrohan --acl public-read --profile rohan "
  
}

}


#creating CloudFront

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

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

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
  target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# give the ip of your os

output "myos_ip" {
  value = aws_instance.web.public_ip
}

#save the public ip in a file publicip.txt

resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
              	}
}
