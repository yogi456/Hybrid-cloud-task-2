
provider "aws" {

	region = "ap-south-1"
	profile = "yogi"
}














variable ssh_key_name {

        default = "efskeytf"
}



resource "tls_private_key" "key-pair" {

	algorithm = "RSA"
	rsa_bits = 4096
}

resource "local_file" "private-key" {

    content = tls_private_key.key-pair.private_key_pem
    filename = 	"${var.ssh_key_name}.pem"
    file_permission = "0400"
}

resource "aws_key_pair" "deployer" {

  key_name   = var.ssh_key_name
  public_key = tls_private_key.key-pair.public_key_openssh
}

resource "aws_security_group" "webserver" {

	name = "webserver22"
	description = "Allow HTTP and SSH inbound traffic"
	
	ingress	{
		
		from_port = 80
      		to_port = 80
      		protocol = "tcp"
      		cidr_blocks = ["0.0.0.0/0"]
      		ipv6_cidr_blocks = ["::/0"]
      	}
      	
      	ingress {
      		
      		from_port = 22
      		to_port = 22
      		protocol = "tcp"
      		cidr_blocks = ["0.0.0.0/0"]
      		ipv6_cidr_blocks = ["::/0"]
      	}
      	
      	ingress {
      		
      		from_port = -1
      		to_port = -1
      		protocol = "icmp"
      		cidr_blocks = ["0.0.0.0/0"]
      		ipv6_cidr_blocks = ["::/0"]
      	}
      	
      	egress {
      	
      		from_port = 0
      		to_port = 0
      		protocol = "-1"
      		cidr_blocks = ["0.0.0.0/0"]
      	}
}


resource "aws_efs_file_system" "myefs" {
  creation_token = "my-efs"

  tags = {
    Name = "myefs"
  }
}
resource "aws_efs_mount_target" "alpha-1" {
  file_system_id = "${aws_efs_file_system.myefs.id}"
  subnet_id      = "subnet-f90e3391"
  security_groups=["sg-039c277a1ba67bd3c"]
}
resource "aws_efs_mount_target" "alpha-2" {
  file_system_id = "${aws_efs_file_system.myefs.id}"
  subnet_id      = "subnet-c8016384"
  security_groups = ["sg-039c277a1ba67bd3c"]
}
resource "aws_efs_mount_target" "alpha-3" {
  file_system_id = "${aws_efs_file_system.myefs.id}"
  subnet_id      = "subnet-3715a04c"
  security_groups = ["sg-039c277a1ba67bd3c"]
}
output "efs-id" {
          value = aws_efs_file_system.myefs.id
        }

resource "aws_instance" "web" {
     
         depends_on = [
             aws_efs_mount_target.alpha-3,
          ]

  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name = "${var.ssh_key_name}"
  security_groups =  [ aws_security_group.webserver.name ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("${var.ssh_key_name}.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {

    inline = [
      "sudo yum install httpd  php git -y",
      "sudo yum -y install amazon-nfs-utils",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport efs-id.value.efs.ap-south-1.amazonaws.com:/   /var/www/html",
       "sudo git clone https://github.com/yogi456/hybrid-cloud-task1.git /var/www/html/"
    ]
  }

  tags = {
    Name = "myserver"
  }

}








	output "myos_ip" {
	  value = aws_instance.web.public_ip
	}




	resource "aws_s3_bucket" "b" {
	  bucket = "bucketfortask222"
	  acl    = "private"

	  tags = {
	    Name        = "mynewbuckett"
	    Environment = "Dev"
	  }

		provisioner "local-exec" {
		
			command = "git clone https://github.com/yogi456/imagefortask1.git image-web"
		}
		
		provisioner "local-exec" {
		
			when = destroy
			command = "rm -rf image-web"
		}
	}
	resource "aws_s3_bucket_object" "object" {
	  bucket = aws_s3_bucket.b.bucket
	  key    = "yogesh.jpeg"
	  source = "image-web/yogesh.jpeg"
	  acl    = "public-read"

	}
	locals {
	  s3_origin_id = "myS3Origin"
	}




resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.b.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

   
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "my picture"
  default_root_object = "yogesh.jpeg"

  logging_config {
    include_cookies = false
    bucket          = "yogilookbook.s3.amazonaws.com"
    prefix          = "myprefix"
  }


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

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

 

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

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
      locations        = ["US", "CA", "GB", "IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  





  }


resource "null_resource" "nullremote4"  {

depends_on = [
    aws_cloudfront_distribution.s3_distribution
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("${var.ssh_key_name}.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      
  			"sudo su << EOF",
            		"echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object.key}' width='300' height='380'>\" >> /var/www/html/index.html",
            		"EOF",	
    ]
  }
  
	provisioner "local-exec" {
	    command = "firefox  ${aws_instance.web.public_ip}"
  	}
}  
  

  
  
