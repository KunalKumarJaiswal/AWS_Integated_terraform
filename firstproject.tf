provider "aws" {
  region     = "ap-south-1"
  profile    = "kunal1"
}

resource "aws_key_pair" "mykey" {
  key_name   = "ak123"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAr7V0Xl4v/X4sedWvL6IcosvhRfUtDboAS1HV3RtWmp0HKhzE1LxLrxqxXOg1SexrH03bDKDg4yCGR+C75yHvx8N7t7mJ+82Dq8Ldp+znuRvRtHT4LpzeIsnigR1dTeMlW0pgqS673DHfrWK6+4PoY7HkGmHjtbYll9TVeE+VrJvshQ3h54oeeZ5l4kVPiuHDnPl5HcHr3pfS6fFIaxrvAjKtnOOezOZvft4+jn42rpLphb61Q/uPgU0ziUAPw/IPnMaRK/g9oguHZ0cV8c+X4EXyIvruhLsTC9wv+lon7yr4/b9V6mO8k7P2vgptp/qKJrB4qxvQ8LVhkDKMfuda0Q== rsa-key-20200614"
}

resource "aws_security_group" "kunal_sg" {
  name        = "kunal_sg"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "kunal_sg"
  }
}

resource "aws_instance" "my_in" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "ak123"
  security_groups = [ "kunal_sg" ]

  tags = {
    Name = "kunal_in"
  }
}

resource "aws_ebs_volume" "vol" {
  availability_zone = aws_instance.my_in.availability_zone
  size              = 1
}

resource "aws_volume_attachment" "my_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.vol.id
  instance_id = aws_instance.my_in.id
  force_detach = true
}

resource "null_resource" "myremote"  {

depends_on = [
    aws_volume_attachment.my_att
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/KUNAL JAISWAL/Downloads/ak123.pem")
    host     = aws_instance.my_in.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/KunalKumarJaiswal/myfirstproject.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "kunal_buc" {
  bucket = "kunal-01"
  acl    = "public-read"
  force_destroy = true

  tags = {
    Name        = "kunal-01"
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.kunal_buc.bucket_regional_domain_name}"
    origin_id   = "s3-kunal01"

    custom_origin_config {
        http_port = 80
        https_port = 80
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols = ["TLSv1","TLSv1.1","TLSv1.2"]
    }
}

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

enabled = true

default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-kunal01"

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


  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

