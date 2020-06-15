resource "tls_private_key" "vijay" {
  algorithm = "RSA"
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "deployer-one"
  public_key = tls_private_key.vijay.public_key_openssh
}
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  

    ingress {
    description = "allowed ssh and http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "allow_ssh"
  }
}

resource "aws_instance" "instance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "deployer-one"
  security_groups = ["${aws_security_group.allow_ssh.name}"]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.vijay.private_key_pem
    host     = aws_instance.instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "tysm"
  }

}


resource "aws_ebs_volume" "volume" {
 depends_on=[aws_instance.instance]
  availability_zone = aws_instance.instance.availability_zone
  size              = 1
  tags = {
    Name = "ebsvolm"
  }
}

resource "aws_volume_attachment" "attachment" {
depends_on=[aws_ebs_volume.volume]

  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.volume.id
  instance_id = aws_instance.instance.id
  force_detach = true
}


resource "null_resource" "mount"  {

depends_on = [
    aws_volume_attachment.attachment,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.vijay.private_key_pem
    host     = aws_instance.instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/vijay-yada/task1.git/var/www/html"
    ]
  }
}

resource "aws_s3_bucket" "my-test-bkuc91" {
  bucket = "my-test-bkuc91"
  acl    = "private"

  tags = {
    Name        = "My bucket"
    //Environment = "Dev"
  }
}
locals {

s3_origin_id = "mys3origintcv"
}
resource "aws_s3_bucket_object" "my-test-bkuc91" {
  bucket = "my-test-bkuc91"
  key    = "tdm.jpg"
  source = "C:/Users/vijay/Downloads/tdm.jpg"
 }



resource "aws_cloudfront_distribution" "cloudf_dist" {
  origin {
    domain_name = aws_s3_bucket.my-test-bkuc91.bucket_regional_domain_name
    origin_id   = local.s3_origin_id


    custom_origin_config {
    http_port = 80
    https_port = 80
    origin_protocol_policy = "match-viewer"
    origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
    }
  }

  enabled             = true

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


